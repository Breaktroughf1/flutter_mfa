import 'dart:typed_data';

import 'package:flutter_mfa/src/web/web_store.dart';
import 'package:flutter_mfa/src/web/web_vault.dart';
import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:flutter_mfa_platform_interface/flutter_mfa_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

/// Simulates authenticated encryption exactly: [open] succeeds only for the
/// (key generation, nonce, ciphertext, aad) that [seal] produced.
final class _FakeStore implements WebStore {
  @override
  bool isSecureContext = true;

  final records = <String, Uint8List>{};
  final _sealed = <(int, String, String, String), Uint8List>{};
  int? keyGeneration;
  var _generations = 0;
  var _nonces = 0;
  var persistCalls = 0;
  bool persistResult = true;
  bool persistThrows = false;
  bool failStorage = false;
  String? clipboard;
  bool clipboardReadable = true;
  bool failClipboard = false;
  final clipboardWrites = <String>[];

  void _maybeFail() {
    if (failStorage) throw const WebStoreFailure();
  }

  static String _hex(Uint8List b) => b.map((x) => '$x,').join();

  @override
  Future<bool> requestPersistence() async {
    persistCalls++;
    if (persistThrows) throw const WebStoreFailure();
    return persistResult;
  }

  @override
  Future<Uint8List> seal(
    Uint8List nonce,
    Uint8List plaintext,
    Uint8List aad,
  ) async {
    _maybeFail();
    final generation = keyGeneration ??= ++_generations;
    final ciphertext = Uint8List.fromList([
      for (final b in plaintext) b ^ 0x5a,
      ...List.filled(16, generation),
    ]);
    _sealed[(generation, _hex(nonce), _hex(ciphertext), _hex(aad))] =
        Uint8List.fromList(plaintext);
    return ciphertext;
  }

  @override
  Future<Uint8List?> open(
    Uint8List nonce,
    Uint8List ciphertext,
    Uint8List aad,
  ) async {
    _maybeFail();
    final generation = keyGeneration;
    if (generation == null) return null;
    return _sealed[(generation, _hex(nonce), _hex(ciphertext), _hex(aad))];
  }

  @override
  Uint8List randomBytes(int length) =>
      Uint8List(length)..fillRange(0, length, ++_nonces);

  @override
  Future<Uint8List?> get(String key) async {
    _maybeFail();
    return records[key];
  }

  @override
  Future<void> put(String key, Uint8List record) async {
    _maybeFail();
    records[key] = record;
  }

  @override
  Future<void> delete(String key) async {
    _maybeFail();
    records.remove(key);
  }

  @override
  Future<List<String>> keys() async {
    _maybeFail();
    return records.keys.toList().reversed.toList();
  }

  @override
  Future<void> clear() async {
    _maybeFail();
    records.clear();
    keyGeneration = null;
  }

  @override
  Future<void> writeClipboard(String text) async {
    if (failClipboard) throw const WebStoreFailure();
    clipboardWrites.add(text);
    clipboard = text;
  }

  @override
  Future<String?> readClipboardIfPermitted() async =>
      clipboardReadable ? clipboard : null;
}

void main() {
  late _FakeStore store;
  late WebVault vault;
  final secret = Uint8List.fromList(List.generate(20, (i) => i));

  setUp(() {
    store = _FakeStore();
    vault = WebVault(store);
  });

  group('records (FR-VLT-04)', () {
    test('round-trips, overwrites and deletes values', () async {
      await vault.write('acct_1', secret, ProtectionLevel.standard);
      expect(await vault.read('acct_1'), secret);
      await vault.write(
        'acct_1',
        Uint8List.fromList([9]),
        ProtectionLevel.standard,
      );
      expect(await vault.read('acct_1'), [9]);
      await vault.delete('acct_1');
      expect(await vault.read('acct_1'), isNull);
      await vault.delete('acct_1');
    });

    test(
      'stores version, level and nonce in clear and never the value',
      () async {
        await vault.write('k', secret, ProtectionLevel.standard);
        final record = store.records['k']!;
        expect(record.sublist(0, 2), [1, 0]);
        expect(
          record.sublist(2, 14),
          List.filled(12, 1),
          reason: 'CSPRNG nonce',
        );
        expect(record.length, 2 + 12 + secret.length + 16);
        expect(record.sublist(14, 34), isNot(secret));
      },
    );

    test('a fresh nonce is drawn for every write', () async {
      await vault.write('k', secret, ProtectionLevel.standard);
      final first = store.records['k']!.sublist(2, 14);
      await vault.write('k', secret, ProtectionLevel.standard);
      expect(store.records['k']!.sublist(2, 14), isNot(first));
    });

    test(
      'a record moved to another key is VaultCorrupted (AAD binds the key)',
      () async {
        await vault.write('a', secret, ProtectionLevel.standard);
        store.records['b'] = store.records['a']!;
        await expectLater(vault.read('b'), throwsA(const VaultCorrupted()));
      },
    );

    test(
      'relabelled, truncated, unknown-version and tampered records are VaultCorrupted',
      () async {
        await vault.write('k', secret, ProtectionLevel.standard);
        final good = store.records['k']!;
        for (final bad in [
          Uint8List.fromList([...good]..[1] = 1),
          Uint8List.fromList([...good]..[0] = 2),
          Uint8List.fromList([...good]..[20] ^= 1),
          Uint8List.fromList([...good]..[5] ^= 1),
          good.sublist(0, 29),
          Uint8List(0),
        ]) {
          store.records['k'] = bad;
          await expectLater(
            vault.read('k'),
            throwsA(const VaultCorrupted()),
            reason: '${bad.length} bytes',
          );
        }
      },
    );

    test('a record whose key is gone is VaultCorrupted', () async {
      await vault.write('k', secret, ProtectionLevel.standard);
      store.keyGeneration = null;
      await expectLater(vault.read('k'), throwsA(const VaultCorrupted()));
    });

    test('keys are sorted and wipe removes records and the key', () async {
      await vault.write('b', secret, ProtectionLevel.standard);
      await vault.write('__index_v1__', secret, ProtectionLevel.standard);
      expect(await vault.keys(), ['__index_v1__', 'b']);
      await vault.wipe();
      expect(await vault.keys(), isEmpty);
      expect(store.keyGeneration, isNull);
    });
  });

  group('fail closed', () {
    test(
      'biometric and hardware-bound levels are refused, not downgraded',
      () async {
        for (final level in [
          ProtectionLevel.biometric,
          ProtectionLevel.hardwareBound,
        ]) {
          await expectLater(
            vault.write('k', secret, level),
            throwsA(
              const VaultHardwareUnavailable(
                HardwareUnavailableReason.unsupportedOnPlatform,
              ),
            ),
          );
        }
        expect(store.records, isEmpty);
      },
    );

    test(
      'outside a secure context every storage call is VaultUnavailable(insecureContext)',
      () async {
        store.isSecureContext = false;
        const insecure = VaultUnavailable(
          VaultUnavailableReason.insecureContext,
        );
        await expectLater(
          vault.write('k', secret, ProtectionLevel.standard),
          throwsA(insecure),
        );
        await expectLater(vault.read('k'), throwsA(insecure));
        await expectLater(vault.delete('k'), throwsA(insecure));
        await expectLater(vault.keys(), throwsA(insecure));
        await expectLater(vault.wipe(), throwsA(insecure));
        expect(store.records, isEmpty);
      },
    );

    test(
      'browser storage failures are VaultUnavailable(storageUnavailable)',
      () async {
        store.failStorage = true;
        const unavailable = VaultUnavailable(
          VaultUnavailableReason.storageUnavailable,
        );
        await expectLater(
          vault.write('k', secret, ProtectionLevel.standard),
          throwsA(unavailable),
        );
        await expectLater(vault.read('k'), throwsA(unavailable));
        await expectLater(vault.keys(), throwsA(unavailable));
      },
    );
  });

  group('capabilities', () {
    test(
      'report a standard-only software vault and request persistence once',
      () async {
        await vault.write('k', secret, ProtectionLevel.standard);
        final caps = await vault.capabilities();
        expect(
          caps,
          const VaultCapabilities(
            hardwareBacked: false,
            strongBox: false,
            secureEnclave: false,
            biometricsEnrolled: false,
            secureContext: true,
            persistentStorage: true,
            screenCaptureProtection: false,
            supportedLevels: {ProtectionLevel.standard},
          ),
        );
        await vault.capabilities();
        expect(store.persistCalls, 1);
      },
    );

    test(
      'a refused or failed persistence request reports eviction risk',
      () async {
        store.persistResult = false;
        expect((await vault.capabilities()).persistentStorage, isFalse);
        final other = _FakeStore()..persistThrows = true;
        expect(
          (await WebVault(other).capabilities()).persistentStorage,
          isFalse,
        );
      },
    );

    test(
      'an insecure context reports no levels and never asks to persist',
      () async {
        store.isSecureContext = false;
        final caps = await vault.capabilities();
        expect(caps.secureContext, isFalse);
        expect(caps.supportedLevels, isEmpty);
        expect(caps.persistentStorage, isFalse);
        expect(store.persistCalls, 0);
      },
    );

    test('screen-capture protection is a no-op', () async {
      await vault.setScreenCaptureProtection(true);
    });
  });

  group('sensitive clipboard (FR-FAC-05)', () {
    test(
      'clears the code after expiry if it is still on the clipboard',
      () async {
        await vault.copySensitive('123456', expiry: Duration.zero);
        expect(store.clipboard, '123456');
        await Future<void>.delayed(const Duration(milliseconds: 1));
        expect(store.clipboard, '');
      },
    );

    test('never wipes newer content or content it cannot verify', () async {
      await vault.copySensitive('123456', expiry: Duration.zero);
      store.clipboard = 'user text';
      await Future<void>.delayed(const Duration(milliseconds: 1));
      expect(store.clipboard, 'user text');

      store.clipboardReadable = false;
      await vault.copySensitive('654321', expiry: Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 1));
      expect(store.clipboard, '654321');
    });

    test(
      'a failed copy is VaultUnavailable; a failed clear is ignored',
      () async {
        store.failClipboard = true;
        await expectLater(
          vault.copySensitive('123456'),
          throwsA(
            const VaultUnavailable(VaultUnavailableReason.storageUnavailable),
          ),
        );
        store
          ..failClipboard = false
          ..clipboard = null;
        await vault.copySensitive('123456', expiry: Duration.zero);
        store.failClipboard = true;
        await Future<void>.delayed(const Duration(milliseconds: 1));
        expect(store.clipboardWrites, ['123456']);
      },
    );
  });

  test('store failures carry no detail', () {
    expect(const WebStoreFailure().toString(), 'WebStoreFailure');
  });
}
