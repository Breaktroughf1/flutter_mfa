import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:flutter_mfa_platform_interface/flutter_mfa_platform_interface.dart';
import 'package:meta/meta.dart';

import '../integrity/device_integrity.dart';
import '../logging/mfa_logger.dart';

/// Configuration of an `MfaClient`.
@immutable
final class MfaClientOptions {
  /// Creates options; every field has a safe default.
  const MfaClientOptions({
    this.clock = const SystemClock(),
    this.logger = const SilentMfaLogger(),
    this.clipboardExpiry = const Duration(seconds: 30),
    this.defaultPrompt = const BiometricPrompt(title: 'Unlock code'),
    this.integrityCheck = const NoopIntegrityCheck(),
    this.integrityPolicy = allowAllIntegrity,
  });

  /// Time source for TOTP codes and enrolment timestamps.
  final Clock clock;

  /// Receives diagnostics; never given secrets or codes.
  final MfaLogger logger;

  /// How long a copied code stays on the clipboard (FR-FAC-05).
  final Duration clipboardExpiry;

  /// Biometric prompt text used when a call passes none. Localise it.
  final BiometricPrompt defaultPrompt;

  /// Device integrity check run by `MfaClient.create` and
  /// `MfaClient.checkIntegrity` (FR-FAC-03). Default: [NoopIntegrityCheck].
  final DeviceIntegrityCheck integrityCheck;

  /// Decides what a report means for the app: return to continue, throw to
  /// block. Default: [allowAllIntegrity].
  final IntegrityPolicy integrityPolicy;
}
