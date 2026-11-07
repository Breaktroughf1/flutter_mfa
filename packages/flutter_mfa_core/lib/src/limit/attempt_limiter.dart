import 'dart:async';

import 'package:meta/meta.dart';

import '../errors/mfa_exception.dart';
import '../otp/clock.dart';
import '../util/async_mutex.dart';

/// Throttling parameters for an [AttemptLimiter] (RFC 4226 §7.3).
///
/// Three independent rules apply; the longest wait wins:
/// * **window**: at most [maxAttempts] failures per [window];
/// * **back-off**: after the n-th consecutive failure the next attempt
///   waits `min(backoffBase × 2^(n−1), backoffMax)`;
/// * **lockout**: after [lockoutAfter] consecutive failures the subject is
///   locked until a success or an administrative reset.
@immutable
final class LimiterPolicy {
  /// Creates a policy; defaults suit 6-digit codes on a server.
  const LimiterPolicy({
    this.maxAttempts = 5,
    this.window = const Duration(minutes: 5),
    this.backoffBase = const Duration(seconds: 1),
    this.backoffMax = const Duration(minutes: 15),
    this.lockoutAfter = 20,
  });

  /// Failures allowed within one [window].
  final int maxAttempts;

  /// Length of the counting window, starting at its first failure.
  final Duration window;

  /// Back-off after the first consecutive failure; zero disables back-off.
  final Duration backoffBase;

  /// Upper bound of the back-off.
  final Duration backoffMax;

  /// Consecutive failures that trigger the hard lockout; at least
  /// [maxAttempts].
  final int lockoutAfter;

  void _validate() {
    String? bad;
    if (maxAttempts < 1) {
      bad = 'maxAttempts';
    } else if (window <= Duration.zero) {
      bad = 'window';
    } else if (backoffBase < Duration.zero) {
      bad = 'backoffBase';
    } else if (backoffMax < backoffBase) {
      bad = 'backoffMax';
    } else if (lockoutAfter < maxAttempts) {
      bad = 'lockoutAfter';
    }
    if (bad != null) {
      throw OtpConfigException(field: 'policy.$bad', reason: 'is out of range');
    }
  }
}

/// Persisted throttling state of one subject.
@immutable
final class AttemptState {
  /// Creates a state value.
  const AttemptState({
    required this.consecutiveFailures,
    required this.windowFailures,
    required this.windowStart,
    required this.lastFailureAt,
  });

  /// Rebuilds a state from [toJson] output. Throws [FormatException] on
  /// malformed or unknown-version data.
  factory AttemptState.fromJson(Map<String, Object?> json) {
    final v = json['v'];
    final c = json['consecutiveFailures'];
    final w = json['windowFailures'];
    final ws = json['windowStartMs'];
    final lf = json['lastFailureMs'];
    if (v != 1 ||
        c is! int ||
        w is! int ||
        ws is! int ||
        lf is! int ||
        c < 0 ||
        w < 0) {
      throw const FormatException('invalid AttemptState');
    }
    return AttemptState(
      consecutiveFailures: c,
      windowFailures: w,
      windowStart: DateTime.fromMillisecondsSinceEpoch(ws, isUtc: true),
      lastFailureAt: DateTime.fromMillisecondsSinceEpoch(lf, isUtc: true),
    );
  }

  /// Failures since the last success.
  final int consecutiveFailures;

  /// Failures in the current window.
  final int windowFailures;

  /// Start of the current window.
  final DateTime windowStart;

  /// Time of the most recent failure.
  final DateTime lastFailureAt;

  /// JSON-compatible form for server-side stores (versioned).
  Map<String, Object?> toJson() => {
    'v': 1,
    'consecutiveFailures': consecutiveFailures,
    'windowFailures': windowFailures,
    'windowStartMs': windowStart.millisecondsSinceEpoch,
    'lastFailureMs': lastFailureAt.millisecondsSinceEpoch,
  };

  @override
  bool operator ==(Object other) =>
      other is AttemptState &&
      other.consecutiveFailures == consecutiveFailures &&
      other.windowFailures == windowFailures &&
      other.windowStart.isAtSameMomentAs(windowStart) &&
      other.lastFailureAt.isAtSameMomentAs(lastFailureAt);

  @override
  int get hashCode => Object.hash(
    consecutiveFailures,
    windowFailures,
    windowStart.millisecondsSinceEpoch,
    lastFailureAt.millisecondsSinceEpoch,
  );

  @override
  String toString() =>
      'AttemptState(consecutive: $consecutiveFailures, inWindow: $windowFailures)';
}

/// Storage for [AttemptState], keyed by subject (user or account id).
///
/// Servers should back this with shared storage (Redis, SQL) so limits hold
/// across instances and restarts; client-side limits are advisory because a
/// device holder can reset them (ADR-0002). Stores used by several processes
/// should make read-then-write atomic per subject, or accept that parallel
/// requests to different processes may slightly exceed the limits.
abstract interface class AttemptStore {
  /// The state of [subject], or `null` if it has no recorded failures.
  Future<AttemptState?> read(String subject);

  /// Replaces the state of [subject].
  Future<void> write(String subject, AttemptState state);

  /// Removes the state of [subject] (also the administrative reset).
  Future<void> clear(String subject);
}

/// Process-local [AttemptStore] kept in memory.
///
/// Suitable for tests, single-instance servers and local step-up; state is
/// lost on restart and grows with the number of subjects that failed.
final class InMemoryAttemptStore implements AttemptStore {
  final _states = <String, AttemptState>{};

  @override
  Future<AttemptState?> read(String subject) async => _states[subject];

  @override
  Future<void> write(String subject, AttemptState state) async =>
      _states[subject] = state;

  @override
  Future<void> clear(String subject) async => _states.remove(subject);
}

/// Throttles verification attempts per subject (FR-VER-05, S1).
///
/// Verifiers consult it before computing any code, so a limited subject costs
/// no HMAC work. Operations for one subject are serialised within this
/// process, so concurrent failures are never lost and a burst of parallel
/// guesses is counted one by one.
final class AttemptLimiter {
  /// Creates a limiter. Throws [OtpConfigException] for an invalid [policy].
  AttemptLimiter({
    required this.store,
    this.policy = const LimiterPolicy(),
    this.clock = const SystemClock(),
  }) {
    policy._validate();
  }

  /// Where state is kept.
  final AttemptStore store;

  /// Throttling rules.
  final LimiterPolicy policy;

  /// Time source.
  final Clock clock;

  final _locks = <String, AsyncMutex>{};

  /// Throws [VerificationRateLimited] if [subject] may not attempt now.
  Future<void> ensureAllowed(String subject) =>
      _locked(subject, () => _ensureAllowed(subject));

  /// Records a failed (or malformed) attempt for [subject].
  Future<void> recordFailure(String subject) =>
      _locked(subject, () => _recordFailure(subject));

  /// Records a successful attempt, clearing all state for [subject].
  Future<void> recordSuccess(String subject) =>
      _locked(subject, () => store.clear(subject));

  Future<T> _locked<T>(String subject, Future<T> Function() action) {
    final lock = _locks.putIfAbsent(subject, AsyncMutex.new);
    return lock.protect(action).whenComplete(() {
      if (!lock.isLocked) _locks.remove(subject);
    });
  }

  Future<void> _ensureAllowed(String subject) async {
    final state = await store.read(subject);
    if (state == null) return;
    if (state.consecutiveFailures >= policy.lockoutAfter) {
      throw VerificationRateLimited(
        retryAfter: policy.backoffMax,
        lockedOut: true,
      );
    }
    final now = clock.now();
    var wait = state.lastFailureAt
        .add(_backoff(state.consecutiveFailures))
        .difference(now);
    final windowEnd = state.windowStart.add(policy.window);
    if (state.windowFailures >= policy.maxAttempts && now.isBefore(windowEnd)) {
      final untilWindowEnd = windowEnd.difference(now);
      if (untilWindowEnd > wait) wait = untilWindowEnd;
    }
    if (wait > Duration.zero) {
      throw VerificationRateLimited(retryAfter: wait);
    }
  }

  Future<void> _recordFailure(String subject) async {
    final now = clock.now();
    final state = await store.read(subject);
    final windowOpen =
        state != null && now.isBefore(state.windowStart.add(policy.window));
    await store.write(
      subject,
      AttemptState(
        consecutiveFailures: (state?.consecutiveFailures ?? 0) + 1,
        windowFailures: windowOpen ? state.windowFailures + 1 : 1,
        windowStart: windowOpen ? state.windowStart : now,
        lastFailureAt: now,
      ),
    );
  }

  Duration _backoff(int failures) {
    final doublings = failures < 1 ? 0 : (failures - 1).clamp(0, 30);
    final delay = policy.backoffBase * (1 << doublings);
    return delay > policy.backoffMax ? policy.backoffMax : delay;
  }
}

/// Runs one verification [attempt] under [limiter], atomically per subject:
/// checks the limits, runs [attempt] only if allowed, then records success
/// or failure according to [succeeded]. An attempt that throws counts as a
/// failure. Used by the verifiers; not exported.
Future<R> limitedAttempt<R>(
  AttemptLimiter limiter,
  String subject,
  R Function() attempt,
  bool Function(R result) succeeded,
) => limiter._locked(subject, () async {
  await limiter._ensureAllowed(subject);
  final R result;
  try {
    result = attempt();
  } on Object {
    await limiter._recordFailure(subject);
    rethrow;
  }
  if (succeeded(result)) {
    await limiter.store.clear(subject);
  } else {
    await limiter._recordFailure(subject);
  }
  return result;
});
