/// HMAC hash function used to compute one-time passwords (FR-OTP-03).
///
/// SHA-1 is the default because most authenticator apps only support it;
/// HMAC-SHA1 remains secure for OTP use (RFC 4226 §6, RFC 6238 §1.2).
enum OtpAlgorithm {
  /// HMAC-SHA1 (default, widest compatibility).
  sha1,

  /// HMAC-SHA256.
  sha256,

  /// HMAC-SHA512.
  sha512,
}

/// Kind of one-time password.
enum OtpType {
  /// Time-based (RFC 6238).
  totp,

  /// Counter-based (RFC 4226).
  hotp,
}
