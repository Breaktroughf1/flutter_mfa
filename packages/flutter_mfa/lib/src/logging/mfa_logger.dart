/// Severity of a [MfaLogger] message.
enum MfaLogLevel {
  /// Diagnostic detail.
  debug,

  /// Normal operation.
  info,

  /// Something unexpected that was handled.
  warning,

  /// An operation failed.
  error,
}

/// Receives flutter_mfa's diagnostic messages (FR-FAC-04).
///
/// The library only ever passes event names, account ids and error type
/// names: never secrets, codes, `otpauth://` URIs, issuer or account names,
/// or passphrases. Route messages to your own logging; the default discards
/// them.
abstract interface class MfaLogger {
  /// Handles one message.
  void log(MfaLogLevel level, String message);
}

/// [MfaLogger] that discards everything (the default).
final class SilentMfaLogger implements MfaLogger {
  /// Creates the logger.
  const SilentMfaLogger();

  @override
  void log(MfaLogLevel level, String message) {}
}
