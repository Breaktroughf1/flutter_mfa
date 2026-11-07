import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:flutter_mfa_platform_interface/flutter_mfa_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const caps = VaultCapabilities(
    hardwareBacked: true,
    strongBox: true,
    secureEnclave: false,
    biometricsEnrolled: true,
    secureContext: true,
    persistentStorage: false,
    screenCaptureProtection: true,
    supportedLevels: {ProtectionLevel.standard, ProtectionLevel.biometric},
  );

  group('VaultCapabilities', () {
    test('value equality ignores set order', () {
      const same = VaultCapabilities(
        hardwareBacked: true,
        strongBox: true,
        secureEnclave: false,
        biometricsEnrolled: true,
        secureContext: true,
        persistentStorage: false,
        screenCaptureProtection: true,
        supportedLevels: {ProtectionLevel.biometric, ProtectionLevel.standard},
      );
      expect(caps, same);
      expect(caps.hashCode, same.hashCode);
    });

    test('any differing field breaks equality', () {
      const other = VaultCapabilities(
        hardwareBacked: true,
        strongBox: true,
        secureEnclave: false,
        biometricsEnrolled: true,
        secureContext: true,
        persistentStorage: false,
        screenCaptureProtection: true,
        supportedLevels: {ProtectionLevel.standard},
      );
      expect(caps, isNot(other));
    });

    test('toString lists flags and levels', () {
      expect(caps.toString(), contains('levels: standard/biometric'));
      expect(caps.toString(), contains('strongBox: true'));
    });
  });

  group('BiometricPrompt', () {
    test('defaults the cancel label; value equality; short toString', () {
      const p = BiometricPrompt(title: 'Unlock code');
      expect(p.cancelLabel, 'Cancel');
      expect(p, const BiometricPrompt(title: 'Unlock code'));
      expect(p.hashCode, const BiometricPrompt(title: 'Unlock code').hashCode);
      expect(
        p,
        isNot(const BiometricPrompt(title: 'Unlock code', subtitle: 'x')),
      );
      expect(p.toString(), 'BiometricPrompt(Unlock code)');
    });
  });
}
