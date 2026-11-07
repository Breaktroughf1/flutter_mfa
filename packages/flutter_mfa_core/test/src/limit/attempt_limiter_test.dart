import 'dart:async';

import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:flutter_mfa_core/src/limit/attempt_limiter.dart'
    show limitedAttempt;
import 'package:test/test.dart';

final class _Clock implements Clock {
  DateTime value = DateTime.utc(2026, 10, 28, 12);
  @override
  DateTime now() => value;
  void advance(Duration d) => value = value.add(d);
}

/// A store whose reads and writes yield, so interleaving bugs show up.
final class _SlowStore implements AttemptStore {
  final _inner = InMemoryAttemptStore();
  @override
  Future<AttemptState?> read(String subject) async {
    await Future<void>.delayed(Duration.zero);
    return _inner.read(subject);
  }

  @override
  Future<void> write(String subject, AttemptState state) async {
    await Future<void>.delayed(Duration.zero);
    await _inner.write(subject, state);
  }

  @override
  Future<void> clear(String subject) => _inner.clear(subject);
}

Matcher _limited([Duration? retryAfter, bool lockedOut = false]) => throwsA(
  isA<VerificationRateLimited>()
      .having((e) => e.lockedOut, 'lockedOut', lockedOut)
      .having((e) => e.retryAfter, 'retryAfter', retryAfter ?? anything),
);

void main() {
  late _Clock clock;
  late InMemoryAttemptStore store;

  setUp(() {
    clock = _Clock();
    store = InMemoryAttemptStore();
  });

  AttemptLimiter limiter([LimiterPolicy policy = const LimiterPolicy()]) =>
      AttemptLimiter(store: store, policy: policy, clock: clock);

  group('LimiterPolicy', () {
    test('defaults: 5 per 5 min, back-off 1 s to 15 min, lockout after 20', () {
      const p = LimiterPolicy();
      expect(p.maxAttempts, 5);
      expect(p.window, const Duration(minutes: 5));
      expect(p.backoffBase, const Duration(seconds: 1));
      expect(p.backoffMax, const Duration(minutes: 15));
      expect(p.lockoutAfter, 20);
    });

    test('invalid policies are rejected when the limiter is built', () {
      for (final (field, policy) in [
        ('maxAttempts', const LimiterPolicy(maxAttempts: 0)),
        ('window', const LimiterPolicy(window: Duration.zero)),
        (
          'backoffBase',
          const LimiterPolicy(backoffBase: Duration(seconds: -1)),
        ),
        (
          'backoffMax',
          const LimiterPolicy(
            backoffBase: Duration(seconds: 2),
            backoffMax: Duration(seconds: 1),
          ),
        ),
        ('lockoutAfter', const LimiterPolicy(maxAttempts: 5, lockoutAfter: 4)),
      ]) {
        expect(
          () => limiter(policy),
          throwsA(
            isA<OtpConfigException>().having(
              (e) => e.field,
              'field',
              'policy.$field',
            ),
          ),
          reason: field,
        );
      }
    });
  });

  group('AttemptLimiter (FR-VER-05)', () {
    test('a fresh subject is allowed', () async {
      await limiter().ensureAllowed('alice');
    });

    test('back-off after each failure grows exponentially and caps', () async {
      final l = limiter(
        const LimiterPolicy(
          maxAttempts: 100,
          lockoutAfter: 100,
          backoffMax: Duration(seconds: 10),
        ),
      );
      final waits = <Duration>[];
      for (var i = 0; i < 6; i++) {
        await l.recordFailure('alice');
        try {
          await l.ensureAllowed('alice');
          fail('should be limited');
        } on VerificationRateLimited catch (e) {
          waits.add(e.retryAfter);
        }
        clock.advance(waits.last);
        await l.ensureAllowed('alice'); // allowed once the wait has passed
      }
      expect(waits.map((d) => d.inSeconds), [1, 2, 4, 8, 10, 10]);
    });

    test(
      'maxAttempts failures within the window block until it ends',
      () async {
        final l = limiter(
          const LimiterPolicy(
            backoffBase: Duration.zero,
            backoffMax: Duration.zero,
          ),
        );
        for (var i = 0; i < 4; i++) {
          await l.recordFailure('alice');
          await l.ensureAllowed('alice');
          clock.advance(const Duration(seconds: 10));
        }
        await l.recordFailure('alice'); // 5th failure at t = 40 s
        await expectLater(
          l.ensureAllowed('alice'),
          _limited(const Duration(seconds: 260)),
        );
        clock.advance(const Duration(seconds: 259));
        await expectLater(
          l.ensureAllowed('alice'),
          _limited(const Duration(seconds: 1)),
        );
        clock.advance(const Duration(seconds: 1));
        await l.ensureAllowed('alice');
      },
    );

    test('the window restarts after it expires', () async {
      final l = limiter(
        const LimiterPolicy(
          backoffBase: Duration.zero,
          backoffMax: Duration.zero,
        ),
      );
      for (var i = 0; i < 4; i++) {
        await l.recordFailure('alice');
      }
      clock.advance(const Duration(minutes: 5));
      for (var i = 0; i < 4; i++) {
        await l.recordFailure('alice');
      }
      await l.ensureAllowed('alice');
      final state = (await store.read('alice'))!;
      expect(state.windowFailures, 4);
      expect(state.consecutiveFailures, 8);
    });

    test('success resets everything', () async {
      final l = limiter();
      for (var i = 0; i < 3; i++) {
        await l.recordFailure('alice');
      }
      await l.recordSuccess('alice');
      expect(await store.read('alice'), isNull);
      await l.ensureAllowed('alice');
    });

    test(
      'hard lockout after lockoutAfter consecutive failures; waiting does not lift it',
      () async {
        final l = limiter(
          const LimiterPolicy(
            maxAttempts: 3,
            lockoutAfter: 6,
            backoffBase: Duration.zero,
            backoffMax: Duration.zero,
          ),
        );
        for (var i = 0; i < 6; i++) {
          await l.recordFailure('alice');
          clock.advance(
            const Duration(minutes: 6),
          ); // always outside the window
        }
        await expectLater(
          l.ensureAllowed('alice'),
          _limited(Duration.zero, true),
        );
        clock.advance(const Duration(days: 365));
        await expectLater(l.ensureAllowed('alice'), _limited(null, true));
        await store.clear('alice'); // administrative reset
        await l.ensureAllowed('alice');
      },
    );

    test('subjects are independent', () async {
      final l = limiter();
      await l.recordFailure('alice');
      await expectLater(l.ensureAllowed('alice'), _limited());
      await l.ensureAllowed('bob');
    });

    test('concurrent failures do not lose counts (in-process lock)', () async {
      final slow = _SlowStore();
      final l = AttemptLimiter(
        store: slow,
        clock: clock,
        policy: const LimiterPolicy(maxAttempts: 100, lockoutAfter: 100),
      );
      await Future.wait([
        for (var i = 0; i < 50; i++) l.recordFailure('alice'),
      ]);
      expect((await slow.read('alice'))!.consecutiveFailures, 50);
    });

    test(
      'limitedAttempt checks, runs and records atomically per subject',
      () async {
        final slow = _SlowStore();
        final l = AttemptLimiter(
          store: slow,
          clock: clock,
          policy: const LimiterPolicy(
            maxAttempts: 3,
            backoffBase: Duration.zero,
            backoffMax: Duration.zero,
          ),
        );
        var ran = 0;
        final results = await Future.wait([
          for (var i = 0; i < 10; i++)
            limitedAttempt<bool>(l, 'alice', () {
              ran++;
              return false;
            }, (ok) => ok).then(
              (_) => 'ran',
              onError: (Object e) =>
                  e is VerificationRateLimited ? 'limited' : 'other',
            ),
        ]);
        expect(ran, 3, reason: 'a burst cannot exceed maxAttempts');
        expect(results.where((r) => r == 'limited'), hasLength(7));
      },
    );

    test('limitedAttempt records success and returns the result', () async {
      final l = limiter();
      await l.recordFailure('alice');
      clock.advance(const Duration(seconds: 1));
      expect(await limitedAttempt<int>(l, 'alice', () => 7, (v) => v == 7), 7);
      expect(await store.read('alice'), isNull);
    });

    test(
      'limitedAttempt never runs the attempt when limited (FR-VER-05 AC4)',
      () async {
        final l = limiter();
        await l.recordFailure('alice');
        var ran = false;
        await expectLater(
          limitedAttempt<bool>(l, 'alice', () => ran = true, (ok) => ok),
          throwsA(isA<VerificationRateLimited>()),
        );
        expect(ran, isFalse);
      },
    );

    test(
      'an attempt that throws is recorded as a failure and rethrown',
      () async {
        final l = limiter();
        await expectLater(
          limitedAttempt<bool>(
            l,
            'alice',
            () => throw StateError('x'),
            (ok) => ok,
          ),
          throwsStateError,
        );
        expect((await store.read('alice'))!.consecutiveFailures, 1);
      },
    );
  });

  group('AttemptState', () {
    test('round-trips through JSON for server-side stores', () {
      final s = AttemptState(
        consecutiveFailures: 3,
        windowFailures: 2,
        windowStart: DateTime.utc(2026, 1, 1),
        lastFailureAt: DateTime.utc(2026, 1, 1, 0, 1),
      );
      expect(AttemptState.fromJson(s.toJson()), s);
      expect(s.hashCode, AttemptState.fromJson(s.toJson()).hashCode);
      expect(s.toJson(), {
        'v': 1,
        'consecutiveFailures': 3,
        'windowFailures': 2,
        'windowStartMs': 1767225600000,
        'lastFailureMs': 1767225660000,
      });
    });

    test('fromJson rejects malformed data with FormatException', () {
      for (final bad in <Map<String, Object?>>[
        {},
        {
          'v': 2,
          'consecutiveFailures': 1,
          'windowFailures': 1,
          'windowStartMs': 0,
          'lastFailureMs': 0,
        },
        {
          'v': 1,
          'consecutiveFailures': -1,
          'windowFailures': 1,
          'windowStartMs': 0,
          'lastFailureMs': 0,
        },
        {
          'v': 1,
          'consecutiveFailures': 1,
          'windowFailures': 'x',
          'windowStartMs': 0,
          'lastFailureMs': 0,
        },
      ]) {
        expect(
          () => AttemptState.fromJson(bad),
          throwsFormatException,
          reason: '$bad',
        );
      }
    });

    test('toString shows counts only', () {
      final s = AttemptState(
        consecutiveFailures: 1,
        windowFailures: 1,
        windowStart: DateTime.utc(2026),
        lastFailureAt: DateTime.utc(2026),
      );
      expect(s.toString(), 'AttemptState(consecutive: 1, inWindow: 1)');
      expect(s == AttemptState.fromJson(s.toJson()), isTrue);
      expect(
        s,
        isNot(
          AttemptState(
            consecutiveFailures: 2,
            windowFailures: 1,
            windowStart: DateTime.utc(2026),
            lastFailureAt: DateTime.utc(2026),
          ),
        ),
      );
    });
  });

  group('InMemoryAttemptStore', () {
    test('read, write, clear', () async {
      final s = InMemoryAttemptStore();
      expect(await s.read('a'), isNull);
      final state = AttemptState(
        consecutiveFailures: 1,
        windowFailures: 1,
        windowStart: DateTime.utc(2026),
        lastFailureAt: DateTime.utc(2026),
      );
      await s.write('a', state);
      expect(await s.read('a'), state);
      await s.clear('a');
      expect(await s.read('a'), isNull);
    });
  });
}
