import 'package:meta/meta.dart';

import '../backup/passphrase_check.dart';

/// Root of every exception thrown by the flutter_mfa packages.
///
/// The hierarchy is sealed, so a `switch` over it is exhaustive and every
/// package maps errors once (02_ARCHITECTURE §6). No exception ever carries
/// secret material: `toString` exposes only field names, reasons and codes,
/// never seeds, codes, URIs or passphrases (S8).
@immutable
sealed class MfaException implements Exception {
  const MfaException();

  String get _name;

  /// Non-secret details, rendered by [toString] and used for equality.
  Map<String, Object?> get _details => const {};

  @override
  bool operator ==(Object other) =>
      other is MfaException &&
      other._name == _name &&
      _mapEquals(other._details, _details);

  @override
  int get hashCode => Object.hash(
    _name,
    Object.hashAllUnordered(
      _details.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );

  @override
  String toString() =>
      '$_name(${_details.entries.map((e) => '${e.key}: ${_fmt(e.value)}').join(', ')})';
}

/// An OTP parameter is invalid: digits, period, algorithm, counter, window or
/// secret length.
final class OtpConfigException extends MfaException {
  /// Creates an exception for [field] with a human-readable [reason].
  ///
  /// [reason] must describe the rule, never the rejected value.
  const OtpConfigException({required this.field, required this.reason});

  /// Name of the offending parameter, for example `digits`.
  final String field;

  /// Why the value was rejected, for example `must be 6, 7 or 8`.
  final String reason;

  @override
  String get _name => 'OtpConfigException';

  @override
  Map<String, Object?> get _details => {'field': field, 'reason': reason};
}

/// An `otpauth://` URI could not be parsed.
///
/// Also a [FormatException], so parsers and fuzzers only ever observe
/// `FormatException` (FR-URI-01 AC5). [source] is always `null` because the
/// URI contains the secret.
final class OtpAuthUriException extends MfaException
    implements FormatException {
  /// Creates an exception for URI component [field] with a [reason].
  const OtpAuthUriException({required this.field, required this.reason});

  /// The URI component that failed, for example `secret` or `counter`.
  final String field;

  /// Why it failed, for example `missing` or `not base32`.
  final String reason;

  @override
  String get message => '$field: $reason';

  /// Always `null`: the input URI contains the secret and is never retained.
  @override
  Object? get source => null;

  /// Always `null`; see [source].
  @override
  int? get offset => null;

  @override
  String get _name => 'OtpAuthUriException';

  @override
  Map<String, Object?> get _details => {'field': field, 'reason': reason};
}

/// Verification was refused by the attempt limiter before any code was
/// computed (FR-VER-05, S1).
final class VerificationRateLimited extends MfaException {
  /// Creates an exception telling the caller to wait [retryAfter].
  const VerificationRateLimited({
    required this.retryAfter,
    this.lockedOut = false,
  });

  /// How long the subject must wait before the next attempt is allowed.
  /// When [lockedOut] is true this is only a hint for user messaging.
  final Duration retryAfter;

  /// Whether the subject hit the hard lockout threshold. Waiting does not
  /// lift it: only a successful verification by another path or an
  /// administrative reset (clearing the subject in the store) does.
  final bool lockedOut;

  @override
  String get _name => 'VerificationRateLimited';

  @override
  Map<String, Object?> get _details => {
    'retryAfter': retryAfter,
    if (lockedOut) 'lockedOut': true,
  };
}

/// A secure-vault operation failed (FR-VLT-07).
///
/// Unknown platform states are reported as one of these, never as a silent
/// fallback to weaker protection (fail closed).
sealed class VaultException extends MfaException {
  const VaultException();
}

/// No entry exists for the requested key.
final class VaultNotFound extends VaultException {
  /// Creates the exception.
  const VaultNotFound();

  @override
  String get _name => 'VaultNotFound';
}

/// The user dismissed the biometric or device-credential prompt.
final class VaultUserCancelled extends VaultException {
  /// Creates the exception.
  const VaultUserCancelled();

  @override
  String get _name => 'VaultUserCancelled';
}

/// The protecting key was permanently invalidated, typically because the
/// biometric enrolment changed (FR-VLT-06 AC3).
///
/// The protected secret is unrecoverable on this device: the app must ask
/// the user to re-enrol the account or restore it from an encrypted backup.
final class VaultKeyInvalidated extends VaultException {
  /// Creates the exception.
  const VaultKeyInvalidated();

  @override
  String get _name => 'VaultKeyInvalidated';

  @override
  Map<String, Object?> get _details => const {
    'recovery': 're-enrol or restore from backup',
  };
}

/// Why a requested hardware-backed protection is not available.
enum HardwareUnavailableReason {
  /// No Secure Enclave (for example the iOS simulator).
  secureEnclaveUnavailable,

  /// No StrongBox or TEE-backed Keystore could provide the requested key.
  strongBoxUnavailable,

  /// The device supports biometrics but none are enrolled.
  biometricsNotEnrolled,

  /// The device has no usable strong biometric hardware.
  biometricsUnavailable,

  /// The platform does not offer this protection at all (for example web).
  unsupportedOnPlatform,
}

/// The requested protection level cannot be provided on this device.
///
/// Thrown instead of silently storing the secret with weaker protection.
final class VaultHardwareUnavailable extends VaultException {
  /// Creates the exception with its [reason].
  const VaultHardwareUnavailable(this.reason);

  /// What is missing.
  final HardwareUnavailableReason reason;

  @override
  String get _name => 'VaultHardwareUnavailable';

  @override
  Map<String, Object?> get _details => {'reason': reason};
}

/// Why the vault as a whole cannot be used.
enum VaultUnavailableReason {
  /// Web page not served from a secure context (HTTPS or localhost).
  insecureContext,

  /// Android host activity is not a `FlutterFragmentActivity`, so biometric
  /// prompts cannot be shown.
  hostActivityNotFragmentActivity,

  /// Platform storage (Keystore, Keychain, IndexedDB) refused access.
  storageUnavailable,

  /// The device is locked and the data is only available when unlocked.
  deviceLocked,
}

/// The vault cannot be used in the current environment.
final class VaultUnavailable extends VaultException {
  /// Creates the exception with its [reason].
  const VaultUnavailable(this.reason);

  /// Why the vault is unavailable.
  final VaultUnavailableReason reason;

  @override
  String get _name => 'VaultUnavailable';

  @override
  Map<String, Object?> get _details => {'reason': reason};
}

/// Stored data failed authentication or could not be decoded (tampering,
/// truncation or a format bug). See S17.
final class VaultCorrupted extends VaultException {
  /// Creates the exception.
  const VaultCorrupted();

  @override
  String get _name => 'VaultCorrupted';
}

/// A platform error with no specific mapping.
final class VaultUnknown extends VaultException {
  /// Creates the exception with the platform's error [code].
  const VaultUnknown(this.code);

  /// Platform error code (never contains secret data).
  final String code;

  @override
  String get _name => 'VaultUnknown';

  @override
  Map<String, Object?> get _details => {'code': code};
}

/// Encrypted backup export or import failed.
sealed class BackupException extends MfaException {
  const BackupException();
}

/// Wrong passphrase, or the backup was modified or truncated. The two cases
/// are deliberately indistinguishable (FR-BAK-03).
final class BackupDecryptFailed extends BackupException {
  /// Creates the exception.
  const BackupDecryptFailed();

  @override
  String get _name => 'BackupDecryptFailed';
}

/// The backup uses a format version (or KDF parameters) this reader does
/// not accept.
final class BackupUnsupportedVersion extends BackupException {
  /// Creates the exception for format [version].
  const BackupUnsupportedVersion(this.version);

  /// The version byte found in the backup header.
  final int version;

  @override
  String get _name => 'BackupUnsupportedVersion';

  @override
  Map<String, Object?> get _details => {'version': version};
}

/// The export passphrase does not satisfy the policy (FR-BAK-02).
final class BackupWeakPassphrase extends BackupException {
  /// Creates the exception with the failed [check].
  const BackupWeakPassphrase(this.check);

  /// Which rule the passphrase failed; never [PassphraseCheck.ok].
  final PassphraseCheck check;

  @override
  String get _name => 'BackupWeakPassphrase';

  @override
  Map<String, Object?> get _details => {'check': check};
}

bool _mapEquals(Map<String, Object?> a, Map<String, Object?> b) =>
    a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

String _fmt(Object? value) => switch (value) {
  final Enum e => e.name,
  final Duration d when d.inMilliseconds % 1000 == 0 => '${d.inSeconds}s',
  final Duration d => '${d.inMilliseconds}ms',
  _ => '$value',
};
