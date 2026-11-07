import 'dart:typed_data';

import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:test/test.dart';

void main() {
  final rfcSecret = OtpSecret.fromBytes(
    Uint8List.fromList('12345678901234567890'.codeUnits),
  );

  group('Hotp', () {
    test('defaults to SHA-1 and 6 digits (FR-OTP-03)', () {
      const config = HotpConfig();
      expect(config.algorithm, OtpAlgorithm.sha1);
      expect(config.digits, 6);
      expect(Hotp(rfcSecret).generate(0), '755224');
    });

    test('supports 7 and 8 digits with left zero padding', () {
      // Counter 0, SHA-1: truncated value 1284755224.
      expect(
        Hotp(rfcSecret, config: const HotpConfig(digits: 7)).generate(0),
        '4755224',
      );
      expect(
        Hotp(rfcSecret, config: const HotpConfig(digits: 8)).generate(0),
        '84755224',
      );
    });

    test('rejects digits other than 6, 7, 8 (FR-OTP-01 AC2)', () {
      for (final d in [0, 5, 9, 10, -1]) {
        expect(
          () => Hotp(rfcSecret, config: HotpConfig(digits: d)).generate(0),
          throwsA(
            isA<OtpConfigException>().having((e) => e.field, 'field', 'digits'),
          ),
          reason: '$d digits',
        );
      }
    });

    test('rejects negative counters', () {
      expect(
        () => Hotp(rfcSecret).generate(-1),
        throwsA(
          isA<OtpConfigException>().having((e) => e.field, 'field', 'counter'),
        ),
      );
    });

    test('accepts counters up to 2^53-1 and rejects larger ones '
        '(documented web ceiling, FR-OTP-01 AC3)', () {
      expect(Hotp.maxCounter, 9007199254740991);
      expect(Hotp(rfcSecret).generate(Hotp.maxCounter), '891307');
      expect(
        () => Hotp(rfcSecret).generate(Hotp.maxCounter + 1),
        throwsA(isA<OtpConfigException>()),
      );
    });

    test('encodes large counters as 64-bit big-endian', () {
      // Independently computed (Python hmac) for counter 2^32 + 1 and 2^40.
      expect(Hotp(rfcSecret).generate(4294967297), '108930');
      expect(Hotp(rfcSecret).generate(1099511627776), '445672');
    });

    test('works with every algorithm', () {
      for (final a in OtpAlgorithm.values) {
        expect(
          Hotp(rfcSecret, config: HotpConfig(algorithm: a)).generate(1),
          hasLength(6),
        );
      }
    });

    test('config has value equality', () {
      expect(const HotpConfig(digits: 8), const HotpConfig(digits: 8));
      expect(const HotpConfig().hashCode, const HotpConfig().hashCode);
      expect(const HotpConfig(digits: 8), isNot(const HotpConfig()));
      expect(const HotpConfig().toString(), 'HotpConfig(sha1, 6 digits)');
    });
  });
}
