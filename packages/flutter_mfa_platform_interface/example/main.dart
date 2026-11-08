// Example for flutter_mfa_platform_interface. App developers should use
// package:flutter_mfa instead; this package is for vault implementers and
// tests using InMemoryMfaPlatform.
import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:flutter_mfa_platform_interface/flutter_mfa_platform_interface.dart';
import 'package:flutter_mfa_platform_interface/testing.dart';

/// Demonstrates installing [InMemoryMfaPlatform] for tests.
Future<void> main() async {
  final vault = InMemoryMfaPlatform();
  MfaPlatform.instance = vault;

  final secret = OtpSecret.generate();
  await vault.write('acct_demo', secret.bytes, ProtectionLevel.biometric);
  final stored = await vault.read(
    'acct_demo',
    prompt: const BiometricPrompt(title: 'Unlock demo secret'),
  );
  assert(stored != null && stored.length == secret.length);
  await vault.wipe();
}
