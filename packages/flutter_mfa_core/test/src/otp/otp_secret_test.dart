import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:test/test.dart';

void main() {
  final twenty = Uint8List.fromList(List<int>.generate(20, (i) => i));

  group('OtpSecret.fromBytes', () {
    test('keeps a defensive copy of the input', () {
      final input = Uint8List.fromList(twenty);
      final secret = OtpSecret.fromBytes(input);
      input[0] = 99;
      expect(secret.bytes[0], 0);
    });

    test('bytes returns a fresh copy each time', () {
      final secret = OtpSecret.fromBytes(twenty);
      secret.bytes[0] = 99;
      expect(secret.bytes[0], 0);
      expect(identical(secret.bytes, secret.bytes), isFalse);
    });

    test('accepts the 10-byte (80-bit) secrets real issuers use', () {
      expect(OtpSecret.fromBytes(Uint8List(10)).length, 10);
    });

    test('rejects secrets shorter than 10 bytes', () {
      expect(
        () => OtpSecret.fromBytes(Uint8List(9)),
        throwsA(
          isA<OtpConfigException>().having((e) => e.field, 'field', 'secret'),
        ),
      );
      expect(
        () => OtpSecret.fromBytes(Uint8List(0)),
        throwsA(isA<OtpConfigException>()),
      );
    });

    test('rejects secrets longer than 256 bytes', () {
      expect(OtpSecret.fromBytes(Uint8List(256)).length, 256);
      expect(
        () => OtpSecret.fromBytes(Uint8List(257)),
        throwsA(isA<OtpConfigException>()),
      );
    });

    test('meetsRfcMinimum is true only from 16 bytes (RFC 4226 R6)', () {
      expect(OtpSecret.fromBytes(Uint8List(15)).meetsRfcMinimum, isFalse);
      expect(OtpSecret.fromBytes(Uint8List(16)).meetsRfcMinimum, isTrue);
    });
  });

  group('OtpSecret.fromBase32', () {
    test('decodes leniently and round-trips through toBase32', () {
      final secret = OtpSecret.fromBase32('jbsw y3dp ehpk 3pxp');
      expect(secret.length, 10);
      expect(secret.toBase32(), 'JBSWY3DPEHPK3PXP');
    });

    test('invalid base32 becomes OtpConfigException without the input', () {
      expect(
        () => OtpSecret.fromBase32('JBSWY3DPEHPK3PX1'),
        throwsA(
          isA<OtpConfigException>()
              .having((e) => e.field, 'field', 'secret')
              .having((e) => e.toString(), 'toString', isNot(contains('JBSW'))),
        ),
      );
    });
  });

  group('OtpSecret.generate', () {
    test('defaults to 20 bytes (FR-OTP-05 AC2)', () {
      expect(OtpSecret.generate().length, 20);
    });

    test('rejects requests below 16 bytes (RFC 4226 R6)', () {
      expect(
        () => OtpSecret.generate(length: 15),
        throwsA(isA<OtpConfigException>()),
      );
      expect(OtpSecret.generate(length: 16).length, 16);
    });

    test('rejects requests above 256 bytes', () {
      expect(
        () => OtpSecret.generate(length: 257),
        throwsA(isA<OtpConfigException>()),
      );
    });

    test('uses the injected Random when given (tests only)', () {
      final a = OtpSecret.generate(random: Random(1));
      final b = OtpSecret.generate(random: Random(1));
      expect(a, b);
    });

    test('two default generations differ (Random.secure)', () {
      expect(OtpSecret.generate(), isNot(OtpSecret.generate()));
    });

    test('recommendedLength is 20/32/64 per algorithm (FR-OTP-05 AC3)', () {
      expect(OtpSecret.recommendedLength(OtpAlgorithm.sha1), 20);
      expect(OtpSecret.recommendedLength(OtpAlgorithm.sha256), 32);
      expect(OtpSecret.recommendedLength(OtpAlgorithm.sha512), 64);
    });
  });

  group('OtpSecret redaction and equality', () {
    test('toString never shows the bytes', () {
      final secret = OtpSecret.fromBase32('JBSWY3DPEHPK3PXP');
      expect(secret.toString(), 'OtpSecret(<redacted 10B>)');
    });

    test('equal bytes are equal; any difference is unequal', () {
      expect(OtpSecret.fromBytes(twenty), OtpSecret.fromBytes(twenty));
      final other = Uint8List.fromList(twenty)..[19] = 1;
      expect(OtpSecret.fromBytes(twenty), isNot(OtpSecret.fromBytes(other)));
      expect(
        OtpSecret.fromBytes(twenty),
        isNot(OtpSecret.fromBytes(Uint8List.sublistView(twenty, 0, 16))),
      );
      // ignore: unrelated_type_equality_checks
      expect(OtpSecret.fromBytes(twenty) == 'x', isFalse);
    });

    test('hashCode depends only on length (no content leak via hashing)', () {
      final other = Uint8List.fromList(twenty)..[0] = 7;
      expect(
        OtpSecret.fromBytes(twenty).hashCode,
        OtpSecret.fromBytes(other).hashCode,
      );
    });
  });
}
