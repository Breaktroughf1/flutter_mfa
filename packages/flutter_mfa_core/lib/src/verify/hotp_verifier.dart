import '../errors/mfa_exception.dart';
import '../limit/attempt_limiter.dart';
import '../otp/hotp.dart';
import '../util/constant_time.dart';
import 'code_input.dart';
import 'verification_result.dart';

/// Verifies HOTP codes with look-ahead, resynchronisation and optional
/// attempt limiting (FR-VER-03/05/06).
///
/// Codes behind the expected counter are rejected, which prevents replay as
/// long as the caller persists [Accepted.nextState]. Every candidate counter
/// in the window is computed and compared (no early exit).
final class HotpVerifier {
  /// Creates a verifier. [lookAhead] is how many counters past the expected
  /// one are accepted (0..100).
  ///
  /// Throws [OtpConfigException] for an out-of-range look-ahead or an
  /// invalid [hotp] configuration.
  HotpVerifier({required this.hotp, this.lookAhead = 10, this.limiter}) {
    if (lookAhead < 0 || lookAhead > 100) {
      throw const OtpConfigException(
        field: 'lookAhead',
        reason: 'must be 0 to 100',
      );
    }
    hotp.generate(0);
  }

  /// The generator holding the shared secret.
  final Hotp hotp;

  /// Counters accepted after the expected one.
  final int lookAhead;

  /// Optional throttling, consulted before any code is computed.
  final AttemptLimiter? limiter;

  /// Checks [code] against [counter]..[counter]+[lookAhead].
  ///
  /// Persist [Accepted.nextState] as the next expected counter. Throws
  /// [VerificationRateLimited] when limited and [OtpConfigException] for a
  /// negative counter.
  Future<VerificationResult> verify(
    String code, {
    required String subject,
    required int counter,
  }) => _run(subject, counter, () {
    final normalized = normalizeCode(code, hotp.config.digits);
    if (normalized == null) return const Rejected(RejectReason.malformed);
    return _match(normalized, counter) ?? const Rejected(RejectReason.invalid);
  });

  /// Resynchronises a counter that drifted beyond the look-ahead
  /// (RFC 4226 §7.4): accepts two consecutive codes [code1], [code2] found
  /// within [counter]..[counter]+[resyncWindow] (at most 1000).
  ///
  /// On success, persist [Accepted.nextState] (the counter after [code2]).
  Future<VerificationResult> resync(
    String code1,
    String code2, {
    required String subject,
    required int counter,
    int resyncWindow = 100,
  }) {
    if (resyncWindow < 1 || resyncWindow > 1000) {
      throw const OtpConfigException(
        field: 'resyncWindow',
        reason: 'must be 1 to 1000',
      );
    }
    return _run(subject, counter, () {
      final first = normalizeCode(code1, hotp.config.digits);
      final second = normalizeCode(code2, hotp.config.digits);
      if (first == null || second == null) {
        return const Rejected(RejectReason.malformed);
      }
      Accepted? found;
      for (
        var c = counter;
        c <= counter + resyncWindow && c < Hotp.maxCounter;
        c++
      ) {
        final a = constantTimeStringEquals(first, hotp.generate(c));
        final b = constantTimeStringEquals(second, hotp.generate(c + 1));
        if (a && b && found == null) {
          found = Accepted(
            step: c + 1,
            nextState: c + 2,
            offset: c + 1 - counter,
          );
        }
      }
      return found ?? const Rejected(RejectReason.invalid);
    });
  }

  Future<VerificationResult> _run(
    String subject,
    int counter,
    VerificationResult Function() attempt,
  ) async {
    if (counter < 0 || counter > Hotp.maxCounter) {
      throw const OtpConfigException(
        field: 'counter',
        reason: 'must be between 0 and 2^53-1',
      );
    }
    final limiter = this.limiter;
    if (limiter == null) return attempt();
    return limitedAttempt(limiter, subject, attempt, (r) => r is Accepted);
  }

  Accepted? _match(String code, int counter) {
    Accepted? found;
    for (
      var c = counter;
      c <= counter + lookAhead && c <= Hotp.maxCounter;
      c++
    ) {
      if (constantTimeStringEquals(code, hotp.generate(c)) && found == null) {
        found = Accepted(step: c, nextState: c + 1, offset: c - counter);
      }
    }
    return found;
  }
}
