import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:test/test.dart';

import '../../support/fuzz.dart';

void main() {
  // RFC 4648 §10 test vectors.
  const rfc4648 = {
    '': '',
    'f': 'MY======',
    'fo': 'MZXQ====',
    'foo': 'MZXW6===',
    'foob': 'MZXW6YQ=',
    'fooba': 'MZXW6YTB',
    'foobar': 'MZXW6YTBOI======',
  };

  group('Base32.encode', () {
    test('matches RFC 4648 §10 vectors with padding', () {
      rfc4648.forEach((plain, encoded) {
        expect(Base32.encode(utf8.encode(plain), padding: true), encoded);
      });
    });

    test('omits padding by default (otpauth convention, FR-OTP-04 AC3)', () {
      rfc4648.forEach((plain, encoded) {
        expect(Base32.encode(utf8.encode(plain)), encoded.replaceAll('=', ''));
      });
    });

    test('encodes the common otpauth sample secret', () {
      final bytes = [
        0x48,
        0x65,
        0x6C,
        0x6C,
        0x6F,
        0x21,
        0xDE,
        0xAD,
        0xBE,
        0xEF,
      ];
      expect(Base32.encode(bytes), 'JBSWY3DPEHPK3PXP');
    });

    test('emits upper case only', () {
      final all = List<int>.generate(256, (i) => i);
      final out = Base32.encode(all);
      expect(out, out.toUpperCase());
      expect(RegExp(r'^[A-Z2-7]+$').hasMatch(out), isTrue);
    });

    test('rejects values outside 0..255', () {
      expect(() => Base32.encode([256]), throwsArgumentError);
      expect(() => Base32.encode([-1]), throwsArgumentError);
    });
  });

  group('Base32.decode', () {
    test('matches RFC 4648 §10 vectors with and without padding', () {
      rfc4648.forEach((plain, encoded) {
        expect(Base32.decode(encoded), utf8.encode(plain));
        expect(Base32.decode(encoded.replaceAll('=', '')), utf8.encode(plain));
      });
    });

    test('returns a Uint8List', () {
      expect(Base32.decode('MZXW6'), isA<Uint8List>());
    });

    test('accepts lower case, spaces and hyphens (FR-OTP-04 AC2)', () {
      final expected = [
        0x48,
        0x65,
        0x6C,
        0x6C,
        0x6F,
        0x21,
        0xDE,
        0xAD,
        0xBE,
        0xEF,
      ];
      expect(Base32.decode('jbswy3dpehpk3pxp'), expected);
      expect(Base32.decode('JBSW Y3DP EHPK 3PXP'), expected);
      expect(Base32.decode('jbsw-y3dp-ehpk-3pxp'), expected);
      expect(Base32.decode(' JBSWY3DPEHPK3PXP\t\n'), expected);
    });

    test('rejects invalid characters with their position (FR-OTP-04 AC4)', () {
      expect(
        () => Base32.decode('MZX1'),
        throwsA(
          isA<FormatException>()
              .having((e) => e.offset, 'offset', 3)
              .having((e) => e.source, 'source', isNull),
        ),
      );
      expect(
        () => Base32.decode('MZ!W'),
        throwsA(isA<FormatException>().having((e) => e.offset, 'offset', 2)),
      );
      for (final bad in ['0', '1', '8', '9', 'é', '٣', '+', '/']) {
        expect(() => Base32.decode('MZ$bad'), throwsFormatException);
      }
    });

    test('never echoes the input in the exception (it may be a secret)', () {
      try {
        Base32.decode('JBSWY3DPEHPK3PX1');
        fail('expected FormatException');
      } on FormatException catch (e) {
        expect(e.toString(), isNot(contains('JBSWY3DP')));
        expect(e.source, isNull);
      }
    });

    test('rejects lengths that cannot come from whole bytes', () {
      // 1, 3 or 6 symbols (mod 8) cannot encode whole bytes.
      for (final bad in ['M', 'MZX', 'MZXW6Y', 'MZXW6YTBO', 'MZXW6YTBOIA']) {
        expect(() => Base32.decode(bad), throwsFormatException, reason: bad);
      }
    });

    test('rejects padding in the middle or too much padding', () {
      expect(() => Base32.decode('MY==MZXQ'), throwsFormatException);
      expect(() => Base32.decode('MZXW6YTB========'), throwsFormatException);
      expect(() => Base32.decode('MY=======X'), throwsFormatException);
    });

    test('rejects a padded block whose length is not a multiple of 8', () {
      expect(() => Base32.decode('MY==='), throwsFormatException);
    });

    test('accepts input made only of separators as empty', () {
      expect(Base32.decode('  - '), isEmpty);
    });
  });

  group('Base32 properties', () {
    test('decode(encode(x)) == x for random byte strings', () {
      final random = fuzzRandom();
      for (var i = 0; i < fuzzRuns(); i++) {
        final bytes = List<int>.generate(
          random.nextInt(70),
          (_) => random.nextInt(256),
        );
        expect(Base32.decode(Base32.encode(bytes)), bytes);
        expect(Base32.decode(Base32.encode(bytes, padding: true)), bytes);
      }
    });

    test('random strings either decode or throw FormatException only', () {
      final random = fuzzRandom(42);
      const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567abcxyz01 -=+/!é٣\n';
      for (var i = 0; i < fuzzRuns(); i++) {
        final input = String.fromCharCodes([
          for (var j = random.nextInt(40); j > 0; j--)
            alphabet.codeUnitAt(random.nextInt(alphabet.length)),
        ]);
        try {
          Base32.decode(input);
        } on FormatException {
          // expected for invalid input
        }
      }
    });
  });
}
