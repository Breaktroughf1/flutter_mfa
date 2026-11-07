import 'dart:typed_data';

import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:test/test.dart';

final class _Clock implements Clock {
  _Clock(this.value);
  DateTime value;
  @override
  DateTime now() => value;
}

/// Counts writes so a test can prove a limited attempt did no work.
final class _CountingStore implements AttemptStore {
  final inner = InMemoryAttemptStore();
  int writes = 0;
  @override
  Future<AttemptState?> read(String s) => inner.read(s);
  @override
  Future<void> write(String s, AttemptState st) {
    writes++;
    return inner.write(s, st);
  }

  @override
  Future<void> clear(String s) => inner.clear(s);
}

DateTime _at(int seconds) =>
    DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);

void main() {
  final secret = OtpSecret.fromBytes(
    Uint8List.fromList('12345678901234567890'.codeUnits),
  );
  final totp = Totp(secret);
  const now = 1111111111; // step 37037037
  final step = totp.stepAt(_at(now));
  String codeAt(int s) => totp.generateForStep(s);

  group('VerificationResult', () {
    test('value types with readable toString', () {
      expect(
        const Accepted(step: 5, nextState: 5, offset: 0),
        const Accepted(step: 5, nextState: 5, offset: 0),
      );
      expect(
        const Accepted(step: 5, nextState: 5, offset: 0).hashCode,
        const Accepted(step: 5, nextState: 5, offset: 0).hashCode,
      );
      expect(
        const Accepted(step: 5, nextState: 5, offset: 0),
        isNot(const Accepted(step: 5, nextState: 6, offset: 0)),
      );
      expect(
        const Rejected(RejectReason.replayed),
        const Rejected(RejectReason.replayed),
      );
      expect(
        const Rejected(RejectReason.replayed).hashCode,
        const Rejected(RejectReason.replayed).hashCode,
      );
      expect(
        const Rejected(RejectReason.invalid),
        isNot(const Rejected(RejectReason.malformed)),
      );
      expect(
        const Accepted(step: 5, nextState: 6, offset: -1).toString(),
        'Accepted(step: 5, nextState: 6, offset: -1)',
      );
      expect(
        const Rejected(RejectReason.invalid).toString(),
        'Rejected(invalid)',
      );
    });
  });

  group('TotpVerifier (FR-VER-01, FR-VER-02)', () {
    TotpVerifier verifier({int window = 1, AttemptLimiter? limiter}) =>
        TotpVerifier(totp: totp, window: window, limiter: limiter);

    test(
      'accepts the current code with offset 0 and returns the step to persist',
      () async {
        final r = await verifier().verify(
          codeAt(step),
          subject: 'u',
          at: _at(now),
        );
        expect(r, Accepted(step: step, nextState: step, offset: 0));
      },
    );

    test('default window is ±1: drift −1/+1 accepted, ±2 rejected', () async {
      final v = verifier();
      expect(v.window, 1);
      expect(
        await v.verify(codeAt(step - 1), subject: 'u', at: _at(now)),
        Accepted(step: step - 1, nextState: step - 1, offset: -1),
      );
      expect(
        await v.verify(codeAt(step + 1), subject: 'u', at: _at(now)),
        Accepted(step: step + 1, nextState: step + 1, offset: 1),
      );
      expect(
        await v.verify(codeAt(step - 2), subject: 'u', at: _at(now)),
        const Rejected(RejectReason.invalid),
      );
      expect(
        await v.verify(codeAt(step + 2), subject: 'u', at: _at(now)),
        const Rejected(RejectReason.invalid),
      );
    });

    test(
      'window 0 accepts only the current step; window 2 accepts ±2',
      () async {
        expect(
          await verifier(
            window: 0,
          ).verify(codeAt(step - 1), subject: 'u', at: _at(now)),
          const Rejected(RejectReason.invalid),
        );
        expect(
          (await verifier(
                window: 2,
              ).verify(codeAt(step + 2), subject: 'u', at: _at(now)))
              as Accepted,
          isA<Accepted>().having((a) => a.offset, 'offset', 2),
        );
      },
    );

    test('rejects windows outside 0..10 (FR-VER-01 AC3)', () {
      expect(
        () => verifier(window: 11),
        throwsA(
          isA<OtpConfigException>().having((e) => e.field, 'field', 'window'),
        ),
      );
      expect(() => verifier(window: -1), throwsA(isA<OtpConfigException>()));
      expect(verifier(window: 10).window, 10);
    });

    test('rejects an invalid TOTP configuration at construction', () {
      expect(
        () => TotpVerifier(
          totp: Totp(secret, config: const TotpConfig(digits: 9)),
        ),
        throwsA(
          isA<OtpConfigException>().having((e) => e.field, 'field', 'digits'),
        ),
      );
      expect(
        () => TotpVerifier(
          totp: Totp(secret, config: const TotpConfig(period: Duration.zero)),
        ),
        throwsA(
          isA<OtpConfigException>().having((e) => e.field, 'field', 'period'),
        ),
      );
    });

    test('replay of the same step is rejected (RFC 6238 §5.2)', () async {
      final v = verifier();
      final first =
          await v.verify(codeAt(step), subject: 'u', at: _at(now)) as Accepted;
      final again = await v.verify(
        codeAt(step),
        subject: 'u',
        lastUsedStep: first.nextState,
        at: _at(now),
      );
      expect(again, const Rejected(RejectReason.replayed));
    });

    test(
      'a code for an earlier step than the last used one is rejected as replayed',
      () async {
        final r = await verifier().verify(
          codeAt(step - 1),
          subject: 'u',
          lastUsedStep: step,
          at: _at(now),
        );
        expect(r, const Rejected(RejectReason.replayed));
      },
    );

    test('nextState is strictly increasing across successive logins', () async {
      final v = verifier();
      var last = -1;
      for (var s = 0; s < 3; s++) {
        final at = _at(now + 30 * s);
        final r =
            await v.verify(
                  totp.generate(at),
                  subject: 'u',
                  lastUsedStep: last < 0 ? null : last,
                  at: at,
                )
                as Accepted;
        expect(r.nextState, greaterThan(last));
        last = r.nextState;
      }
    });

    test('uses the TOTP clock when no time is given', () async {
      final clocked = Totp(secret, clock: _Clock(_at(now)));
      final r = await TotpVerifier(
        totp: clocked,
      ).verify(codeAt(step), subject: 'u');
      expect(r, isA<Accepted>());
    });

    test('steps before 0 are skipped near T0', () async {
      final r = await verifier().verify(codeAt(0), subject: 'u', at: _at(0));
      expect(r, const Accepted(step: 0, nextState: 0, offset: 0));
    });

    test(
      'normalises spaces; malformed input is rejected as malformed (FR-VER-06)',
      () async {
        final v = verifier();
        final code = codeAt(step);
        expect(
          await v.verify(
            '${code.substring(0, 3)} ${code.substring(3)}',
            subject: 'u',
            at: _at(now),
          ),
          isA<Accepted>(),
        );
        for (final bad in [
          '',
          '12345',
          '1234567',
          '12345a',
          '12-456',
          '١٢٣٤٥٦',
          '٣٣٣٣٣٣',
          '+12345',
          '      ',
          '123\n456',
        ]) {
          expect(
            await v.verify(bad, subject: 'u', at: _at(now)),
            const Rejected(RejectReason.malformed),
            reason: bad,
          );
        }
      },
    );
  });

  group('TotpVerifier with a limiter (FR-VER-05)', () {
    late _Clock clock;
    late _CountingStore store;
    late AttemptLimiter limiter;

    setUp(() {
      clock = _Clock(_at(now));
      store = _CountingStore();
      limiter = AttemptLimiter(store: store, clock: clock);
    });

    test(
      'a failure is recorded and the next attempt waits for the back-off',
      () async {
        final v = TotpVerifier(totp: totp, limiter: limiter);
        expect(
          await v.verify('000000', subject: 'u', at: _at(now)),
          const Rejected(RejectReason.invalid),
        );
        await expectLater(
          v.verify(codeAt(step), subject: 'u', at: _at(now)),
          throwsA(isA<VerificationRateLimited>()),
        );
      },
    );

    test('malformed input still counts as an attempt', () async {
      final v = TotpVerifier(totp: totp, limiter: limiter);
      await v.verify('abc', subject: 'u', at: _at(now));
      expect((await store.read('u'))!.consecutiveFailures, 1);
    });

    test('a replayed code counts as a failure', () async {
      final v = TotpVerifier(totp: totp, limiter: limiter);
      await v.verify(
        codeAt(step),
        subject: 'u',
        lastUsedStep: step,
        at: _at(now),
      );
      expect((await store.read('u'))!.consecutiveFailures, 1);
    });

    test('success clears the failure history', () async {
      final v = TotpVerifier(totp: totp, limiter: limiter);
      await v.verify('000000', subject: 'u', at: _at(now));
      clock.value = clock.value.add(const Duration(seconds: 1));
      expect(
        await v.verify(codeAt(step), subject: 'u', at: _at(now)),
        isA<Accepted>(),
      );
      expect(await store.read('u'), isNull);
    });

    test(
      'a limited subject is refused before any code is computed or recorded',
      () async {
        final v = TotpVerifier(totp: totp, limiter: limiter);
        await limiter.recordFailure('u');
        final writesBefore = store.writes;
        await expectLater(
          v.verify(codeAt(step), subject: 'u', at: _at(now)),
          throwsA(isA<VerificationRateLimited>()),
        );
        expect(
          store.writes,
          writesBefore,
          reason: 'nothing ran, nothing recorded',
        );
      },
    );
  });

  group('HotpVerifier (FR-VER-03)', () {
    final hotp = Hotp(secret);

    test('accepts the expected counter and returns the next one', () async {
      final r = await HotpVerifier(
        hotp: hotp,
      ).verify(hotp.generate(5), subject: 'u', counter: 5);
      expect(r, const Accepted(step: 5, nextState: 6, offset: 0));
    });

    test('looks ahead up to 10 counters by default', () async {
      final v = HotpVerifier(hotp: hotp);
      expect(v.lookAhead, 10);
      expect(
        await v.verify(hotp.generate(15), subject: 'u', counter: 5),
        const Accepted(step: 15, nextState: 16, offset: 10),
      );
      expect(
        await v.verify(hotp.generate(16), subject: 'u', counter: 5),
        const Rejected(RejectReason.invalid),
      );
    });

    test('codes for counters behind the expected one are rejected', () async {
      expect(
        await HotpVerifier(
          hotp: hotp,
        ).verify(hotp.generate(4), subject: 'u', counter: 5),
        const Rejected(RejectReason.invalid),
      );
    });

    test('look-ahead stops at the counter ceiling', () async {
      final r = await HotpVerifier(hotp: hotp).verify(
        hotp.generate(Hotp.maxCounter),
        subject: 'u',
        counter: Hotp.maxCounter - 1,
      );
      expect(
        r,
        const Accepted(
          step: Hotp.maxCounter,
          nextState: Hotp.maxCounter + 1,
          offset: 1,
        ),
      );
    });

    test('rejects invalid look-ahead, counter or configuration', () async {
      expect(
        () => HotpVerifier(hotp: hotp, lookAhead: -1),
        throwsA(
          isA<OtpConfigException>().having(
            (e) => e.field,
            'field',
            'lookAhead',
          ),
        ),
      );
      expect(
        () => HotpVerifier(hotp: hotp, lookAhead: 101),
        throwsA(isA<OtpConfigException>()),
      );
      expect(
        () => HotpVerifier(
          hotp: Hotp(secret, config: const HotpConfig(digits: 5)),
        ),
        throwsA(isA<OtpConfigException>()),
      );
      await expectLater(
        HotpVerifier(hotp: hotp).verify('755224', subject: 'u', counter: -1),
        throwsA(isA<OtpConfigException>()),
      );
    });

    test('malformed input is rejected', () async {
      expect(
        await HotpVerifier(
          hotp: hotp,
        ).verify('75522x', subject: 'u', counter: 0),
        const Rejected(RejectReason.malformed),
      );
    });

    test(
      'resync accepts two consecutive codes within the window (RFC 4226 §7.4)',
      () async {
        final v = HotpVerifier(hotp: hotp);
        final r = await v.resync(
          hotp.generate(60),
          hotp.generate(61),
          subject: 'u',
          counter: 5,
        );
        expect(r, const Accepted(step: 61, nextState: 62, offset: 56));
      },
    );

    test(
      'resync rejects non-consecutive codes, codes beyond the window and malformed input',
      () async {
        final v = HotpVerifier(hotp: hotp);
        expect(
          await v.resync(
            hotp.generate(60),
            hotp.generate(62),
            subject: 'u',
            counter: 5,
          ),
          const Rejected(RejectReason.invalid),
        );
        expect(
          await v.resync(
            hotp.generate(61),
            hotp.generate(60),
            subject: 'u',
            counter: 5,
          ),
          const Rejected(RejectReason.invalid),
        );
        expect(
          await v.resync(
            hotp.generate(200),
            hotp.generate(201),
            subject: 'u',
            counter: 5,
            resyncWindow: 100,
          ),
          const Rejected(RejectReason.invalid),
        );
        expect(
          await v.resync('x', hotp.generate(61), subject: 'u', counter: 5),
          const Rejected(RejectReason.malformed),
        );
        expect(
          await v.resync(hotp.generate(60), '', subject: 'u', counter: 5),
          const Rejected(RejectReason.malformed),
        );
        expect(
          () =>
              v.resync('1', '2', subject: 'u', counter: 0, resyncWindow: 1001),
          throwsA(isA<OtpConfigException>()),
        );
      },
    );

    test('verify and resync go through the limiter', () async {
      final clock = _Clock(_at(0));
      final limiter = AttemptLimiter(
        store: InMemoryAttemptStore(),
        clock: clock,
      );
      final v = HotpVerifier(hotp: hotp, limiter: limiter);
      await v.verify('000000', subject: 'u', counter: 0);
      await expectLater(
        v.verify(hotp.generate(0), subject: 'u', counter: 0),
        throwsA(isA<VerificationRateLimited>()),
      );
      await expectLater(
        v.resync(hotp.generate(0), hotp.generate(1), subject: 'u', counter: 0),
        throwsA(isA<VerificationRateLimited>()),
      );
      clock.value = clock.value.add(const Duration(seconds: 1));
      expect(
        await v.resync(
          hotp.generate(3),
          hotp.generate(4),
          subject: 'u',
          counter: 0,
        ),
        isA<Accepted>(),
      );
    });
  });
}
