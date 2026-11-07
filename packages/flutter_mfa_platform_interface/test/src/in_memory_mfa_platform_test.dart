import 'dart:typed_data';

import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:flutter_mfa_platform_interface/flutter_mfa_platform_interface.dart';
import 'package:flutter_mfa_platform_interface/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryMfaPlatform vault;
  setUp(() => vault = InMemoryMfaPlatform());

  test('can be installed as MfaPlatform.instance', () {
    final previous = MfaPlatform.instance;
    MfaPlatform.instance = vault;
    expect(MfaPlatform.instance, same(vault));
    MfaPlatform.instance = previous;
  });

  test('write, read, keys, delete, wipe', () async {
    await vault.write('a', Uint8List.fromList([1]), ProtectionLevel.standard);
    await vault.write('b', Uint8List.fromList([2]), ProtectionLevel.standard);
    expect(await vault.read('a'), [1]);
    expect(await vault.read('missing'), isNull);
    expect(await vault.keys(), unorderedEquals(['a', 'b']));
    await vault.delete('a');
    await vault.delete('a'); // absent keys are ignored
    expect(await vault.keys(), ['b']);
    await vault.wipe();
    expect(await vault.keys(), isEmpty);
  });

  test('keeps defensive copies of stored and returned bytes', () async {
    final input = Uint8List.fromList([1, 2]);
    await vault.write('a', input, ProtectionLevel.standard);
    input[0] = 9;
    final out = (await vault.read('a'))!;
    out[1] = 9;
    expect(await vault.read('a'), [1, 2]);
  });

  test(
    'rejects unsupported levels instead of downgrading (fail closed)',
    () async {
      vault.currentCapabilities = const VaultCapabilities(
        hardwareBacked: true,
        strongBox: false,
        secureEnclave: false,
        biometricsEnrolled: false,
        secureContext: true,
        persistentStorage: true,
        screenCaptureProtection: false,
        supportedLevels: {ProtectionLevel.standard},
      );
      await expectLater(
        vault.write('a', Uint8List(1), ProtectionLevel.biometric),
        throwsA(isA<VaultHardwareUnavailable>()),
      );
      expect(await vault.keys(), isEmpty);
      expect((await vault.capabilities()).supportedLevels, {
        ProtectionLevel.standard,
      });
    },
  );

  test('protected entries go through the simulated biometric prompt', () async {
    await vault.write(
      'bio',
      Uint8List.fromList([7]),
      ProtectionLevel.biometric,
    );
    await vault.write(
      'plain',
      Uint8List.fromList([8]),
      ProtectionLevel.standard,
    );
    expect(vault.levelOf('bio'), ProtectionLevel.biometric);
    expect(vault.levelOf('nope'), isNull);
    expect(await vault.read('plain'), [8]);
    expect(vault.prompts, isEmpty);
    const prompt = BiometricPrompt(title: 'Unlock');
    expect(await vault.read('bio', prompt: prompt), [7]);
    expect(vault.prompts, [prompt]);
    vault.onBiometricPrompt = (_) => false;
    await expectLater(
      vault.read('bio', prompt: prompt),
      throwsA(const VaultUserCancelled()),
    );
  });

  test('failNext makes exactly one call of an operation fail', () async {
    for (final (op, call) in <(VaultOperation, Future<Object?> Function())>[
      (VaultOperation.capabilities, vault.capabilities),
      (
        VaultOperation.write,
        () => vault.write('a', Uint8List(1), ProtectionLevel.standard),
      ),
      (VaultOperation.read, () => vault.read('a')),
      (VaultOperation.delete, () => vault.delete('a')),
      (VaultOperation.keys, vault.keys),
      (VaultOperation.wipe, vault.wipe),
    ]) {
      vault.failNext(op, const VaultCorrupted());
      await expectLater(
        call(),
        throwsA(const VaultCorrupted()),
        reason: op.name,
      );
      await call(); // the next call succeeds
    }
  });

  test('failNext with a key only fails calls for that key', () async {
    vault.failNext(VaultOperation.write, const VaultCorrupted(), key: 'b');
    await vault.write('a', Uint8List(1), ProtectionLevel.standard);
    await expectLater(
      vault.write('b', Uint8List(1), ProtectionLevel.standard),
      throwsA(const VaultCorrupted()),
    );
    await vault.write('b', Uint8List(1), ProtectionLevel.standard);
    expect(await vault.keys(), unorderedEquals(['a', 'b']));
  });

  test(
    'records sensitive clipboard copies and screen-capture protection',
    () async {
      await vault.copySensitive('123456');
      expect(vault.clipboard, ('123456', const Duration(seconds: 30)));
      await vault.copySensitive('1', expiry: const Duration(seconds: 5));
      expect(vault.clipboard, ('1', const Duration(seconds: 5)));
      await vault.setScreenCaptureProtection(true);
      expect(vault.screenCaptureProtected, isTrue);
    },
  );
}
