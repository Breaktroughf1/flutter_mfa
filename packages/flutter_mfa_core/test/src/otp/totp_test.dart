import 'dart:typed_data';

import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:test/test.dart';

DateTime _at(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

final class _FixedClock implements Clock {
  _FixedClock(this.value);
  DateTime value;
  @override
  DateTime now() => value;
}

void main() {
  final secret = OtpSecret.fromBytes(
    Uint8List.fromList('12345678901234567890'.codeUnits),
  );

  group('TotpConfig', () {
    test('defaults: SHA-1, 6 digits, 30 s, T0 = 0 (FR-OTP-02 AC2)', () {
      const c = TotpConfig();
      expect(c.algorithm, OtpAlgorithm.sha1);
      expect(c.digits, 6);
      expect(c.period, const Duration(seconds: 30));
      expect(c.t0, 0);
    });

    test('value equality and toString', () {
      expect(const TotpConfig(digits: 8), const TotpConfig(digits: 8));
      expect(const TotpConfig().hashCode, const TotpConfig().hashCode);
      expect(const TotpConfig(t0: 5), isNot(const TotpConfig()));
      expect(
        const TotpConfig().toString(),
        'TotpConfig(sha1, 6 digits, 30s, t0 0)',
      );
    });

    test('hotp view keeps algorithm and digits', () {
      expect(
        const TotpConfig(algorithm: OtpAlgorithm.sha512, digits: 8).hotp,
        const HotpConfig(algorithm: OtpAlgorithm.sha512, digits: 8),
      );
    });
  });

  group('Totp.stepAt', () {
    final totp = Totp(secret);

    test('steps change exactly on the period boundary', () {
      expect(totp.stepAt(_at(0)), 0);
      expect(totp.stepAt(_at(29999)), 0);
      expect(totp.stepAt(_at(30000)), 1);
      expect(totp.stepAt(_at(59999)), 1);
      expect(totp.stepAt(_at(60000)), 2);
    });

    test('honours T0 and period (FR-OTP-02 AC2)', () {
      final custom = Totp(
        secret,
        config: const TotpConfig(period: Duration(seconds: 60), t0: 100),
      );
      expect(custom.stepAt(_at(100000)), 0);
      expect(custom.stepAt(_at(159999)), 0);
      expect(custom.stepAt(_at(160000)), 1);
    });

    test('supports periods of 15 and 60 seconds', () {
      expect(
        Totp(
          secret,
          config: const TotpConfig(period: Duration(seconds: 15)),
        ).stepAt(_at(15000)),
        1,
      );
      expect(
        Totp(
          secret,
          config: const TotpConfig(period: Duration(seconds: 60)),
        ).stepAt(_at(59999)),
        0,
      );
    });

    test('rejects times before T0', () {
      expect(
        () => totp.stepAt(_at(-1)),
        throwsA(
          isA<OtpConfigException>().having((e) => e.field, 'field', 'time'),
        ),
      );
      final later = Totp(secret, config: const TotpConfig(t0: 100));
      expect(
        () => later.stepAt(_at(99999)),
        throwsA(isA<OtpConfigException>()),
      );
    });

    test('rejects non-positive or fractional-second periods', () {
      for (final p in [
        Duration.zero,
        const Duration(seconds: -30),
        const Duration(milliseconds: 1500),
      ]) {
        expect(
          () => Totp(secret, config: TotpConfig(period: p)).stepAt(_at(0)),
          throwsA(
            isA<OtpConfigException>().having((e) => e.field, 'field', 'period'),
          ),
          reason: '$p',
        );
      }
    });

    test('handles times beyond 32-bit seconds (year 2603)', () {
      expect(totp.stepAt(_at(20000000000 * 1000)), 666666666);
    });
  });

  group('Totp.generate', () {
    test('uses the injected clock when no time is given (FR-OTP-02 AC3)', () {
      final clock = _FixedClock(_at(59000));
      final totp = Totp(
        secret,
        config: const TotpConfig(digits: 8),
        clock: clock,
      );
      expect(totp.generate(), '94287082');
      clock.value = _at(1111111109000);
      expect(totp.generate(), '07081804');
    });

    test('an explicit time overrides the clock', () {
      final totp = Totp(
        secret,
        config: const TotpConfig(digits: 8),
        clock: _FixedClock(_at(0)),
      );
      expect(totp.generate(_at(59000)), '94287082');
    });

    test('generateForStep equals HOTP of the step', () {
      final totp = Totp(secret);
      expect(totp.generateForStep(1), Hotp(secret).generate(1));
      expect(
        () => totp.generateForStep(-1),
        throwsA(isA<OtpConfigException>()),
      );
    });

    test('the default clock is the system clock', () {
      final totp = Totp(secret);
      final before = totp.stepAt(DateTime.now());
      final step = totp.stepAt(const SystemClock().now());
      expect(step - before, inInclusiveRange(0, 1));
      expect(totp.generate(), hasLength(6));
    });
  });

  group('Totp.remaining and progress (FR-OTP-06)', () {
    final totp = Totp(secret);

    test('at the start of a step: full period remaining, progress 0', () {
      expect(totp.remaining(_at(0)), const Duration(seconds: 30));
      expect(totp.progress(_at(0)), 0.0);
      expect(totp.remaining(_at(30000)), const Duration(seconds: 30));
      expect(totp.progress(_at(30000)), 0.0);
    });

    test('at second 29: one second remaining', () {
      expect(totp.remaining(_at(29000)), const Duration(seconds: 1));
      expect(totp.progress(_at(29000)), closeTo(29 / 30, 1e-12));
    });

    test('progress stays below 1 at the last millisecond', () {
      expect(totp.remaining(_at(29999)), const Duration(milliseconds: 1));
      expect(totp.progress(_at(29999)), lessThan(1.0));
    });

    test('use the clock when no time is given', () {
      final clocked = Totp(secret, clock: _FixedClock(_at(10000)));
      expect(clocked.remaining(), const Duration(seconds: 20));
      expect(clocked.progress(), closeTo(1 / 3, 1e-12));
    });

    test('respect T0', () {
      final custom = Totp(secret, config: const TotpConfig(t0: 10));
      expect(custom.remaining(_at(10000)), const Duration(seconds: 30));
    });
  });
}
