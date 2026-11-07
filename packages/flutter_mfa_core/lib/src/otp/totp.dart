import 'package:meta/meta.dart';

import '../errors/mfa_exception.dart';
import 'clock.dart';
import 'hotp.dart';
import 'otp_algorithm.dart';
import 'otp_secret.dart';

/// Parameters of a TOTP generator (RFC 6238).
///
/// Values are validated when used; invalid values throw
/// [OtpConfigException].
@immutable
final class TotpConfig {
  /// Creates a configuration; defaults are SHA-1, 6 digits, 30 s, T0 = 0.
  const TotpConfig({
    this.algorithm = OtpAlgorithm.sha1,
    this.digits = 6,
    this.period = const Duration(seconds: 30),
    this.t0 = 0,
  });

  /// HMAC algorithm.
  final OtpAlgorithm algorithm;

  /// Code length: 6, 7 or 8.
  final int digits;

  /// Time-step length; a positive whole number of seconds.
  final Duration period;

  /// Unix time in seconds at which step 0 starts.
  final int t0;

  /// The HOTP parameters each time step is computed with.
  HotpConfig get hotp => HotpConfig(algorithm: algorithm, digits: digits);

  @override
  bool operator ==(Object other) =>
      other is TotpConfig &&
      other.algorithm == algorithm &&
      other.digits == digits &&
      other.period == period &&
      other.t0 == t0;

  @override
  int get hashCode => Object.hash(algorithm, digits, period, t0);

  @override
  String toString() =>
      'TotpConfig(${algorithm.name}, $digits digits, ${period.inSeconds}s, t0 $t0)';
}

/// Time-based one-time password generator (RFC 6238, FR-OTP-02).
final class Totp {
  /// Creates a generator for [secret] using [clock] for the current time.
  const Totp(
    this.secret, {
    this.config = const TotpConfig(),
    this.clock = const SystemClock(),
  });

  /// The shared secret.
  final OtpSecret secret;

  /// Algorithm, digits, period and T0.
  final TotpConfig config;

  /// Time source used when no explicit time is passed.
  final Clock clock;

  /// The time step containing [t].
  ///
  /// Throws [OtpConfigException] for an invalid period or a time before T0.
  int stepAt(DateTime t) => _elapsedMs(t) ~/ _periodMs;

  /// The code for [at], or for now according to [clock].
  String generate([DateTime? at]) => generateForStep(stepAt(at ?? clock.now()));

  /// The code for time step [step].
  String generateForStep(int step) =>
      Hotp(secret, config: config.hotp).generate(step);

  /// Time left in the step containing [at] (or now): the full period at a
  /// step boundary, down to 1 ms just before the next one (FR-OTP-06).
  Duration remaining([DateTime? at]) => Duration(
    milliseconds: _periodMs - _elapsedMs(at ?? clock.now()) % _periodMs,
  );

  /// Fraction of the step containing [at] (or now) that has elapsed:
  /// 0.0 at the start, always below 1.0 (FR-OTP-06).
  double progress([DateTime? at]) =>
      (_elapsedMs(at ?? clock.now()) % _periodMs) / _periodMs;

  int get _periodMs {
    final ms = config.period.inMilliseconds;
    if (ms <= 0 || ms % 1000 != 0) {
      throw const OtpConfigException(
        field: 'period',
        reason: 'must be a positive whole number of seconds',
      );
    }
    return ms;
  }

  int _elapsedMs(DateTime t) {
    final elapsed = t.millisecondsSinceEpoch - config.t0 * 1000;
    if (elapsed < 0) {
      throw const OtpConfigException(field: 'time', reason: 'is before T0');
    }
    return elapsed;
  }
}
