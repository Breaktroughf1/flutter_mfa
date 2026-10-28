import 'package:meta/meta.dart';

import 'otp_algorithm.dart';
import 'otp_core.dart';
import 'otp_secret.dart';

/// Parameters of an HOTP generator (RFC 4226).
///
/// Values are validated when a code is generated or a verifier is built;
/// invalid values throw `OtpConfigException`.
@immutable
final class HotpConfig {
  /// Creates a configuration; defaults are SHA-1 and 6 digits.
  const HotpConfig({this.algorithm = OtpAlgorithm.sha1, this.digits = 6});

  /// HMAC algorithm.
  final OtpAlgorithm algorithm;

  /// Code length: 6, 7 or 8.
  final int digits;

  @override
  bool operator ==(Object other) =>
      other is HotpConfig &&
      other.algorithm == algorithm &&
      other.digits == digits;

  @override
  int get hashCode => Object.hash(algorithm, digits);

  @override
  String toString() => 'HotpConfig(${algorithm.name}, $digits digits)';
}

/// Counter-based one-time password generator (RFC 4226, FR-OTP-01).
final class Hotp {
  /// Creates a generator for [secret].
  const Hotp(this.secret, {this.config = const HotpConfig()});

  /// Largest counter accepted on every platform (2^53 − 1, the exact-integer
  /// limit of JavaScript numbers; FR-OTP-01 AC3).
  static const maxCounter = maxMovingFactor;

  /// The shared secret.
  final OtpSecret secret;

  /// Algorithm and digits.
  final HotpConfig config;

  /// The code for [counter] (0..[maxCounter]).
  ///
  /// Throws `OtpConfigException` for an invalid counter or digits.
  String generate(int counter) {
    final key = secret.bytes;
    try {
      return computeOtp(key, counter, config.algorithm, config.digits);
    } finally {
      key.fillRange(0, key.length, 0);
    }
  }
}
