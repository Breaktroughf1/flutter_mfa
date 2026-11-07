import 'package:flutter_mfa/flutter_mfa.dart';

/// A user-facing message for [error]. Messages never include secrets, codes
/// or account names (exceptions from flutter_mfa carry none).
String errorText(Object error) => switch (error) {
  OtpAuthUriException() => 'That is not a valid otpauth:// link.',
  OtpConfigException(:final field, :final reason) => 'Invalid $field: $reason.',
  VaultUnavailable(reason: VaultUnavailableReason.insecureContext) =>
    'Secure storage needs HTTPS (or localhost) on the web.',
  VaultUnavailable() => 'Secure storage is unavailable on this device.',
  VaultHardwareUnavailable() =>
    'This device cannot provide the requested protection.',
  VaultUserCancelled() => 'Authentication was cancelled.',
  VaultKeyInvalidated() =>
    'Biometrics changed; re-add this account from its backup.',
  VaultCorrupted() =>
    'Stored data is damaged. Remove the account or wipe the vault.',
  VaultNotFound() => 'That account no longer exists.',
  MfaException() => 'Something went wrong ($error).',
  _ => 'Unexpected error.',
};
