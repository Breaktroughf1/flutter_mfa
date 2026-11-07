import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:flutter_mfa_core/testing.dart';
import 'package:test/test.dart';

void main() {
  group('FakeClock', () {
    test('returns the set time and advances on demand', () {
      final clock = FakeClock(DateTime.utc(2026));
      expect(clock.now(), DateTime.utc(2026));
      clock.advance(const Duration(seconds: 30));
      expect(clock.now(), DateTime.utc(2026, 1, 1, 0, 0, 30));
      clock.time = DateTime.utc(2030);
      expect(clock.now(), DateTime.utc(2030));
    });

    test('drives TOTP deterministically', () {
      final clock = FakeClock(
        DateTime.fromMillisecondsSinceEpoch(59000, isUtc: true),
      );
      final totp = Totp(
        OtpSecret.fromBytes(rfc4226Secret),
        config: const TotpConfig(digits: 8),
        clock: clock,
      );
      expect(totp.generate(), '94287082');
    });
  });

  group('SeededRandom', () {
    test('is deterministic for a seed and differs across seeds', () {
      List<int> draw(SeededRandom r) => [
        for (var i = 0; i < 8; i++) r.nextInt(1000),
      ];
      expect(draw(SeededRandom(7)), draw(SeededRandom(7)));
      expect(draw(SeededRandom(7)), isNot(draw(SeededRandom(8))));
    });

    test('supports the full Random interface', () {
      final r = SeededRandom(1);
      expect(r.nextDouble(), inInclusiveRange(0, 1));
      expect(r.nextBool(), isA<bool>());
    });

    test('makes OtpSecret.generate reproducible in tests', () {
      expect(
        OtpSecret.generate(random: SeededRandom(3)),
        OtpSecret.generate(random: SeededRandom(3)),
      );
    });
  });

  test('exports the frozen RFC vectors', () {
    expect(rfc4226Vectors, hasLength(10));
    expect(rfc6238Vectors, hasLength(18));
    expect(rfc6238Seed(OtpAlgorithm.sha512), hasLength(64));
  });
}
