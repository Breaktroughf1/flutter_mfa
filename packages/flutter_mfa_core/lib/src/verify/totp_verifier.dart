import '../errors/mfa_exception.dart';
import '../limit/attempt_limiter.dart';
import '../otp/totp.dart';
import '../util/constant_time.dart';
import 'code_input.dart';
import 'verification_result.dart';

/// Verifies TOTP codes with a drift window, replay protection and optional
/// attempt limiting (FR-VER-01/02/05/06).
///
/// Run it on the server: a verifier on the same device as the secret is not
/// a second factor, and client-side limits can be reset by the device holder
/// (ADR-0002). Every candidate step in the window is computed and compared,
/// so timing does not reveal which offset matched. It does not protect a
/// caller that fails to persist [Accepted.nextState].
final class TotpVerifier {
  /// Creates a verifier. [window] is the accepted drift in steps (0..10).
  ///
  /// Throws [OtpConfigException] for a window outside 0..10 or an invalid
  /// [totp] configuration.
  TotpVerifier({required this.totp, this.window = 1, this.limiter}) {
    if (window < 0 || window > 10) {
      throw const OtpConfigException(
        field: 'window',
        reason: 'must be 0 to 10',
      );
    }
    totp.stepAt(
      DateTime.fromMillisecondsSinceEpoch(totp.config.t0 * 1000, isUtc: true),
    );
    totp.generateForStep(0);
  }

  /// The generator holding the shared secret.
  final Totp totp;

  /// Accepted drift in steps on each side of the current step.
  final int window;

  /// Optional throttling, consulted before any code is computed.
  final AttemptLimiter? limiter;

  /// Checks [code] for [subject] at [at] (default: the TOTP clock).
  ///
  /// [subject] keys the limiter. Pass the persisted [lastUsedStep] to reject
  /// replays; persist [Accepted.nextState] on success. Throws
  /// [VerificationRateLimited] before computing anything when limited.
  Future<VerificationResult> verify(
    String code, {
    required String subject,
    int? lastUsedStep,
    DateTime? at,
  }) async {
    final time = at ?? totp.clock.now();
    VerificationResult attempt() => _check(code, lastUsedStep, time);
    final limiter = this.limiter;
    if (limiter == null) return attempt();
    return limitedAttempt(limiter, subject, attempt, (r) => r is Accepted);
  }

  VerificationResult _check(String input, int? lastUsedStep, DateTime at) {
    final code = normalizeCode(input, totp.config.digits);
    if (code == null) return const Rejected(RejectReason.malformed);
    final current = totp.stepAt(at);

    Accepted? best;
    var replayed = false;
    // Nearest offsets first (0, −1, +1, −2, …); every candidate is still
    // computed and compared, so there is no early exit.
    for (var i = 0; i <= 2 * window; i++) {
      final offset = i.isOdd ? -(i + 1) ~/ 2 : i ~/ 2;
      final step = current + offset;
      if (step < 0) continue;
      if (!constantTimeStringEquals(code, totp.generateForStep(step))) continue;
      if (lastUsedStep != null && step <= lastUsedStep) {
        replayed = true;
      } else {
        best ??= Accepted(step: step, nextState: step, offset: offset);
      }
    }
    return best ??
        (replayed
            ? const Rejected(RejectReason.replayed)
            : const Rejected(RejectReason.invalid));
  }
}
