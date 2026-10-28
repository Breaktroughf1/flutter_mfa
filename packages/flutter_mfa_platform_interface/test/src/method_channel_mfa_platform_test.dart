import 'package:flutter/services.dart';
import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:flutter_mfa_platform_interface/flutter_mfa_platform_interface.dart';
import 'package:flutter_mfa_platform_interface/src/messages.g.dart';
import 'package:flutter_mfa_platform_interface/src/method_channel_mfa_platform.dart'
    show vaultExceptionFor;
import 'package:flutter_test/flutter_test.dart';

/// Fake host side of the Pigeon channel (Pigeon recommends faking the
/// generated Dart API instead of the deprecated test handlers).
final class _FakeHost extends MfaHostApi {
  final calls = <String>[];
  PlatformException? error;
  Uint8List? readResult;
  PromptMessage? lastPrompt;

  Future<T> _call<T>(String name, T value) async {
    calls.add(name);
    final e = error;
    if (e != null) throw e;
    return value;
  }

  @override
  Future<CapabilitiesMessage> capabilities() => _call(
    'capabilities',
    CapabilitiesMessage(
      hardwareBacked: true,
      strongBox: false,
      secureEnclave: false,
      biometricsEnrolled: true,
      persistentStorage: true,
      screenCaptureProtection: true,
      supportedLevels: [
        ProtectionLevelMessage.standard,
        ProtectionLevelMessage.biometric,
      ],
    ),
  );

  @override
  Future<void> write(
    String key,
    Uint8List value,
    ProtectionLevelMessage level,
  ) => _call('write $key ${value.length} ${level.name}', null);

  @override
  Future<Uint8List?> read(String key, PromptMessage? prompt) {
    lastPrompt = prompt;
    return _call('read $key', readResult);
  }

  @override
  Future<void> delete(String key) => _call('delete $key', null);

  @override
  Future<List<String>> keys() => _call('keys', ['a', 'b']);

  @override
  Future<void> wipe() => _call('wipe', null);

  @override
  Future<void> copySensitive(String text, int expiryMillis) =>
      _call('copy $text $expiryMillis', null);

  @override
  Future<void> setScreenCaptureProtection(bool enabled) =>
      _call('capture $enabled', null);
}

void main() {
  late _FakeHost host;
  late MethodChannelMfaPlatform platform;

  setUp(() {
    host = _FakeHost();
    platform = MethodChannelMfaPlatform(api: host);
  });

  test('is the default MfaPlatform instance on mobile', () {
    expect(MfaPlatform.instance, isA<MethodChannelMfaPlatform>());
  });

  test(
    'capabilities are converted; mobile is always a secure context',
    () async {
      expect(
        await platform.capabilities(),
        const VaultCapabilities(
          hardwareBacked: true,
          strongBox: false,
          secureEnclave: false,
          biometricsEnrolled: true,
          secureContext: true,
          persistentStorage: true,
          screenCaptureProtection: true,
          supportedLevels: {
            ProtectionLevel.standard,
            ProtectionLevel.biometric,
          },
        ),
      );
    },
  );

  test('read returns a buffer the caller can wipe', () async {
    host.readResult = Uint8List.fromList([1, 2, 3]).asUnmodifiableView();
    final bytes = (await platform.read('k'))!;
    bytes.fillRange(0, bytes.length, 0);
    expect(bytes, [0, 0, 0]);
  });

  test('forwards every operation with its arguments', () async {
    host.readResult = Uint8List.fromList([1, 2, 3]);
    await platform.write('k', Uint8List(4), ProtectionLevel.hardwareBound);
    expect(await platform.read('k'), [1, 2, 3]);
    expect(host.lastPrompt, isNull);
    await platform.delete('k');
    expect(await platform.keys(), ['a', 'b']);
    await platform.wipe();
    await platform.copySensitive('123456', expiry: const Duration(seconds: 15));
    await platform.copySensitive('654321');
    await platform.setScreenCaptureProtection(true);
    expect(host.calls, [
      'write k 4 hardwareBound',
      'read k',
      'delete k',
      'keys',
      'wipe',
      'copy 123456 15000',
      'copy 654321 30000',
      'capture true',
    ]);
  });

  test('passes the biometric prompt text through', () async {
    await platform.read(
      'k',
      prompt: const BiometricPrompt(
        title: 'Unlock',
        subtitle: 'Example',
        cancelLabel: 'No',
      ),
    );
    expect(
      (
        host.lastPrompt!.title,
        host.lastPrompt!.subtitle,
        host.lastPrompt!.cancelLabel,
      ),
      ('Unlock', 'Example', 'No'),
    );
  });

  test(
    'platform errors become typed VaultExceptions, details discarded',
    () async {
      host.error = PlatformException(
        code: 'keyInvalidated',
        message: 'raw native message',
        details: 'stack',
      );
      await expectLater(
        platform.read('k'),
        throwsA(const VaultKeyInvalidated()),
      );
      for (final op in <Future<Object?> Function()>[
        platform.capabilities,
        () => platform.write('k', Uint8List(1), ProtectionLevel.standard),
        () => platform.delete('k'),
        platform.keys,
        platform.wipe,
        () => platform.copySensitive('x'),
        () => platform.setScreenCaptureProtection(false),
      ]) {
        await expectLater(op(), throwsA(isA<VaultKeyInvalidated>()));
      }
    },
  );

  group('vaultExceptionFor (single error mapping, 02 §6)', () {
    test('maps every schema error code', () {
      final expected = <VaultErrorCode, VaultException>{
        VaultErrorCode.notFound: const VaultNotFound(),
        VaultErrorCode.userCancelled: const VaultUserCancelled(),
        VaultErrorCode.keyInvalidated: const VaultKeyInvalidated(),
        VaultErrorCode.secureEnclaveUnavailable: const VaultHardwareUnavailable(
          HardwareUnavailableReason.secureEnclaveUnavailable,
        ),
        VaultErrorCode.strongBoxUnavailable: const VaultHardwareUnavailable(
          HardwareUnavailableReason.strongBoxUnavailable,
        ),
        VaultErrorCode.biometricsNotEnrolled: const VaultHardwareUnavailable(
          HardwareUnavailableReason.biometricsNotEnrolled,
        ),
        VaultErrorCode.biometricsUnavailable: const VaultHardwareUnavailable(
          HardwareUnavailableReason.biometricsUnavailable,
        ),
        VaultErrorCode.unsupportedOnPlatform: const VaultHardwareUnavailable(
          HardwareUnavailableReason.unsupportedOnPlatform,
        ),
        VaultErrorCode.hostActivityNotFragmentActivity: const VaultUnavailable(
          VaultUnavailableReason.hostActivityNotFragmentActivity,
        ),
        VaultErrorCode.storageUnavailable: const VaultUnavailable(
          VaultUnavailableReason.storageUnavailable,
        ),
        VaultErrorCode.deviceLocked: const VaultUnavailable(
          VaultUnavailableReason.deviceLocked,
        ),
        VaultErrorCode.corrupted: const VaultCorrupted(),
      };
      expect(
        expected.keys,
        unorderedEquals(VaultErrorCode.values),
        reason: 'every code is mapped',
      );
      expected.forEach(
        (code, error) =>
            expect(vaultExceptionFor(code.name), error, reason: code.name),
      );
    });

    test(
      'unknown codes (including channel errors) fail closed as VaultUnknown',
      () {
        expect(
          vaultExceptionFor('channel-error'),
          const VaultUnknown('channel-error'),
        );
        expect(vaultExceptionFor(''), const VaultUnknown(''));
      },
    );
  });
}
