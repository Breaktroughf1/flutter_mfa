/// Multi-factor authentication for Flutter.
///
/// [MfaClient] is the single entry point for apps. This library also
/// re-exports the public API of `flutter_mfa_core` (OTP, verifiers, URIs,
/// models, errors), so apps need one import.
library;

export 'package:flutter_mfa_core/flutter_mfa_core.dart';
export 'package:flutter_mfa_platform_interface/flutter_mfa_platform_interface.dart'
    show BiometricPrompt, VaultCapabilities;

export 'src/client/mfa_client.dart';
export 'src/client/mfa_client_options.dart';
export 'src/client/relying_party_enrollment.dart';
export 'src/logging/mfa_logger.dart';
