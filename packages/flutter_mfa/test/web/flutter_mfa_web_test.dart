@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter_mfa/flutter_mfa.dart';
import 'package:flutter_mfa/src/web/browser_web_store.dart';
import 'package:flutter_mfa/src/web/flutter_mfa_web.dart';
import 'package:flutter_mfa/src/web/web_vault.dart';
import 'package:flutter_mfa_platform_interface/flutter_mfa_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

/// Reads the stored master key straight from IndexedDB.
Future<web.CryptoKey?> _storedMasterKey() async {
  final open = web.window.indexedDB.open('flutter_mfa_v1', 1);
  final opened = Completer<web.IDBDatabase>();
  open.onsuccess = ((web.Event _) {
    opened.complete(open.result! as web.IDBDatabase);
  }).toJS;
  final db = await opened.future;
  final request = db
      .transaction('keys'.toJS, 'readonly')
      .objectStore('keys')
      .get('master'.toJS);
  final done = Completer<JSAny?>();
  request.onsuccess = ((web.Event _) => done.complete(request.result)).toJS;
  final value = await done.future;
  db.close();
  return value as web.CryptoKey?;
}

extension type _Algorithm._(JSObject _) implements JSObject {
  external String get name;
}

void main() {
  final secret = Uint8List.fromList(List.generate(20, (i) => i));
  late WebVault vault;

  setUp(() async {
    vault = WebVault(BrowserWebStore());
    await vault.wipe();
  });

  test('registration installs the web vault', () {
    FlutterMfaWeb.registerWith(webPluginRegistrar);
    expect(MfaPlatform.instance, isA<WebVault>());
  });

  test('round-trips through IndexedDB and WebCrypto (FR-VLT-04 AC3)', () async {
    await vault.write('acct_1', secret, ProtectionLevel.standard);
    expect(await vault.read('acct_1'), secret);
    final fresh = WebVault(BrowserWebStore());
    expect(await fresh.read('acct_1'), secret, reason: 'persisted');
    expect(await fresh.keys(), ['acct_1']);
    await fresh.delete('acct_1');
    expect(await vault.read('acct_1'), isNull);
  });

  test(
    'the master key is a non-extractable AES-GCM key (FR-VLT-04 AC1)',
    () async {
      await vault.write('k', secret, ProtectionLevel.standard);
      final key = (await _storedMasterKey())!;
      expect(key.extractable, isFalse);
      expect(key.type, 'secret');
      expect((key.algorithm as _Algorithm).name, 'AES-GCM');
    },
  );

  test('concurrent first writes converge on one key', () async {
    await Future.wait([
      for (var i = 0; i < 5; i++)
        WebVault(
          BrowserWebStore(),
        ).write('k$i', secret, ProtectionLevel.standard),
    ]);
    for (var i = 0; i < 5; i++) {
      expect(await vault.read('k$i'), secret);
    }
  });

  test(
    'a tampered record and a foreign key binding are VaultCorrupted',
    () async {
      final store = BrowserWebStore();
      await vault.write('a', secret, ProtectionLevel.standard);
      final record = (await store.get('a'))!;
      await store.put('b', record);
      await expectLater(vault.read('b'), throwsA(const VaultCorrupted()));
      await store.put('a', Uint8List.fromList([...record]..[20] ^= 1));
      await expectLater(vault.read('a'), throwsA(const VaultCorrupted()));
    },
  );

  test('wipe removes records and the key', () async {
    await vault.write('k', secret, ProtectionLevel.standard);
    await vault.wipe();
    expect(await vault.keys(), isEmpty);
    expect(await _storedMasterKey(), isNull);
  });

  test('MfaClient works end to end on the web vault', () async {
    MfaPlatform.instance = vault;
    final mfa = await MfaClient.create();
    expect((await mfa.capabilities).secureContext, isTrue);
    final account = await mfa.enrollManual(
      secretBase32: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
      accountName: 'alice',
    );
    expect((await mfa.currentCode(account.id)).value, hasLength(6));
    await mfa.wipeAll();
    await mfa.dispose();
  });
}
