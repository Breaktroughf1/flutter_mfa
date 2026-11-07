/// Platform interface for the flutter_mfa secure vault.
///
/// App developers should depend on `package:flutter_mfa`. This package is for
/// vault implementers: extend [MfaPlatform] and set [MfaPlatform.instance].
library;

export 'src/biometric_prompt.dart';
export 'src/method_channel_mfa_platform.dart' show MethodChannelMfaPlatform;
export 'src/mfa_platform.dart';
export 'src/vault_capabilities.dart';
