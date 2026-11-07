import 'package:meta/meta.dart';

/// Outcome of verifying a submitted code. Rejections are values, not
/// exceptions; only rate limiting throws (02_ARCHITECTURE §6).
@immutable
sealed class VerificationResult {
  const VerificationResult();
}

/// The code matched.
final class Accepted extends VerificationResult {
  /// Creates an accepted result.
  const Accepted({
    required this.step,
    required this.nextState,
    required this.offset,
  });

  /// TOTP: the matched time step. HOTP: the matched counter.
  final int step;

  /// Value the caller must persist before reporting success, or replay
  /// protection is lost. TOTP: the new `lastUsedStep`. HOTP: the next
  /// counter to expect.
  final int nextState;

  /// TOTP: drift in steps (−window..+window). HOTP: look-ahead distance.
  final int offset;

  @override
  bool operator ==(Object other) =>
      other is Accepted &&
      other.step == step &&
      other.nextState == nextState &&
      other.offset == offset;

  @override
  int get hashCode => Object.hash(step, nextState, offset);

  @override
  String toString() =>
      'Accepted(step: $step, nextState: $nextState, offset: $offset)';
}

/// Why a code was rejected.
enum RejectReason {
  /// Well-formed but wrong.
  invalid,

  /// Correct for a step or counter that was already used (replay).
  replayed,

  /// Not a code at all: wrong length or non-digit characters.
  malformed,
}

/// The code was not accepted.
final class Rejected extends VerificationResult {
  /// Creates a rejection for [reason].
  const Rejected(this.reason);

  /// Why it was rejected.
  final RejectReason reason;

  @override
  bool operator ==(Object other) => other is Rejected && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'Rejected(${reason.name})';
}
