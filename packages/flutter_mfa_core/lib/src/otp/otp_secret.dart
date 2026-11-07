import 'dart:math';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../codec/base32.dart';
import '../errors/mfa_exception.dart';
import '../util/constant_time.dart';
import 'otp_algorithm.dart';

/// An OTP shared secret (seed), held as bytes.
///
/// Protects against accidental disclosure: it keeps a private copy, [bytes]
/// returns a fresh copy, [toString] is redacted, `==` is constant-time and
/// [hashCode] depends only on the length. It cannot protect the bytes in
/// memory from a debugger or a rooted device, and Dart's garbage collector
/// may leave copies that cannot be wiped.
@immutable
final class OtpSecret {
  OtpSecret._(this._bytes);

  /// Smallest secret accepted when importing: 10 bytes (80 bits), the size
  /// many issuers still use. Generated secrets are at least [rfcMinLength].
  static const minLength = 10;

  /// RFC 4226 R6 minimum shared-secret length: 16 bytes (128 bits).
  static const rfcMinLength = 16;

  /// Largest secret accepted (bounds memory use from untrusted input).
  static const maxLength = 256;

  /// Creates a secret from a copy of [bytes].
  ///
  /// Accepts [minLength]..[maxLength] bytes so existing accounts from real
  /// issuers can be imported; check [meetsRfcMinimum] to flag weak ones.
  /// Throws [OtpConfigException] otherwise.
  factory OtpSecret.fromBytes(Uint8List bytes) {
    if (bytes.length < minLength || bytes.length > maxLength) {
      throw const OtpConfigException(
        field: 'secret',
        reason: 'must be 10 to 256 bytes',
      );
    }
    return OtpSecret._(Uint8List.fromList(bytes));
  }

  /// Decodes a Base32 secret, leniently (case, spaces, hyphens, padding).
  ///
  /// Throws [OtpConfigException] (never echoing [input]) when it is not
  /// valid Base32 or has the wrong length.
  factory OtpSecret.fromBase32(String input) {
    final Uint8List decoded;
    try {
      decoded = Base32.decode(input);
    } on FormatException {
      throw const OtpConfigException(
        field: 'secret',
        reason: 'not valid base32',
      );
    }
    try {
      return OtpSecret.fromBytes(decoded);
    } finally {
      decoded.fillRange(0, decoded.length, 0);
    }
  }

  /// Generates a new random secret of [length] bytes (default 20,
  /// FR-OTP-05).
  ///
  /// Uses `Random.secure()` unless [random] is supplied, which only tests
  /// should do. Throws [OtpConfigException] for lengths below
  /// [rfcMinLength] or above [maxLength].
  factory OtpSecret.generate({int length = 20, Random? random}) {
    if (length < rfcMinLength || length > maxLength) {
      throw const OtpConfigException(
        field: 'length',
        reason: 'must be 16 to 256 bytes',
      );
    }
    final rng = random ?? Random.secure();
    return OtpSecret._(
      Uint8List.fromList(List<int>.generate(length, (_) => rng.nextInt(256))),
    );
  }

  /// Recommended secret length for [algorithm]: the hash output size
  /// (20, 32 or 64 bytes; FR-OTP-05 AC3).
  static int recommendedLength(OtpAlgorithm algorithm) => switch (algorithm) {
    OtpAlgorithm.sha1 => 20,
    OtpAlgorithm.sha256 => 32,
    OtpAlgorithm.sha512 => 64,
  };

  final Uint8List _bytes;

  /// A copy of the secret bytes. Callers own the copy and should wipe it
  /// (`fillRange(0, length, 0)`) when done.
  Uint8List get bytes => Uint8List.fromList(_bytes);

  /// Number of bytes in the secret.
  int get length => _bytes.length;

  /// Whether the secret is at least 128 bits, as RFC 4226 R6 requires.
  bool get meetsRfcMinimum => _bytes.length >= rfcMinLength;

  /// The secret as upper-case Base32 without padding. Only for enrolment
  /// display and backup; do not retain the string.
  String toBase32() => Base32.encode(_bytes);

  @override
  bool operator ==(Object other) =>
      other is OtpSecret && constantTimeEquals(_bytes, other._bytes);

  @override
  int get hashCode => _bytes.length;

  @override
  String toString() => 'OtpSecret(<redacted ${_bytes.length}B>)';
}
