import 'dart:typed_data';

import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:test/test.dart';

import '../../support/fuzz.dart';

const _secret = 'JBSWY3DPEHPK3PXP';
const _secret20 = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ'; // 20 bytes

Matcher _uriError(String field) =>
    throwsA(isA<OtpAuthUriException>().having((e) => e.field, 'field', field));

void main() {
  group('OtpAuthUri.parse — Google Key URI examples', () {
    test('parses the canonical TOTP example (FR-URI-01 AC1)', () {
      final u = OtpAuthUri.parse(
        'otpauth://totp/Example:alice@google.com?secret=$_secret&issuer=Example',
      );
      expect(u.type, OtpType.totp);
      expect(u.issuer, 'Example');
      expect(u.accountName, 'alice@google.com');
      expect(u.secret.toBase32(), _secret);
      expect(u.algorithm, OtpAlgorithm.sha1);
      expect(u.digits, 6);
      expect(u.period, const Duration(seconds: 30));
      expect(u.counter, isNull);
      expect(u.extras, isEmpty);
      expect(u.compatibilityWarnings, [CompatibilityWarning.shortSecret]);
    });

    test('parses all optional parameters', () {
      final u = OtpAuthUri.parse(
        'otpauth://totp/ACME%20Co:john.doe@email.com?secret=$_secret20'
        '&issuer=ACME%20Co&algorithm=SHA256&digits=8&period=60',
      );
      expect(u.issuer, 'ACME Co');
      expect(u.accountName, 'john.doe@email.com');
      expect(u.algorithm, OtpAlgorithm.sha256);
      expect(u.digits, 8);
      expect(u.period, const Duration(seconds: 60));
      expect(
        u.totpConfig,
        const TotpConfig(
          algorithm: OtpAlgorithm.sha256,
          digits: 8,
          period: Duration(seconds: 60),
        ),
      );
      expect(u.hotpConfig, isNull);
      expect(u.compatibilityWarnings, {
        CompatibilityWarning.nonDefaultAlgorithm,
        CompatibilityWarning.nonDefaultDigits,
        CompatibilityWarning.nonDefaultPeriod,
      });
    });

    test('parses HOTP with its counter', () {
      final u = OtpAuthUri.parse(
        'otpauth://hotp/Example:alice?secret=$_secret20&counter=42',
      );
      expect(u.type, OtpType.hotp);
      expect(u.counter, 42);
      expect(u.hotpConfig, const HotpConfig());
      expect(u.totpConfig, isNull);
      expect(u.issuer, 'Example');
    });

    test('scheme, type and algorithm are case-insensitive', () {
      final u = OtpAuthUri.parse(
        'OTPAUTH://TOTP/alice?secret=$_secret20&algorithm=sha512',
      );
      expect(u.type, OtpType.totp);
      expect(u.algorithm, OtpAlgorithm.sha512);
    });
  });

  group('OtpAuthUri.parse — labels (FR-URI-01 AC1, AC3)', () {
    test('account only, no issuer', () {
      final u = OtpAuthUri.parse(
        'otpauth://totp/alice%40example.com?secret=$_secret20',
      );
      expect(u.issuer, isNull);
      expect(u.accountName, 'alice@example.com');
    });

    test('issuer in label only', () {
      final u = OtpAuthUri.parse(
        'otpauth://totp/Example:alice?secret=$_secret20',
      );
      expect(u.issuer, 'Example');
      expect(u.compatibilityWarnings, isEmpty);
    });

    test('issuer in parameter only', () {
      final u = OtpAuthUri.parse(
        'otpauth://totp/alice?secret=$_secret20&issuer=Example',
      );
      expect(u.issuer, 'Example');
      expect(u.accountName, 'alice');
    });

    test(
      'issuer parameter wins over a different label prefix, with a warning',
      () {
        final u = OtpAuthUri.parse(
          'otpauth://totp/Old:alice?secret=$_secret20&issuer=New',
        );
        expect(u.issuer, 'New');
        expect(u.compatibilityWarnings, [CompatibilityWarning.issuerMismatch]);
      },
    );

    test('accepts a percent-encoded colon separator and spaces after it', () {
      final u = OtpAuthUri.parse(
        'otpauth://totp/Example%3A%20alice?secret=$_secret20',
      );
      expect(u.issuer, 'Example');
      expect(u.accountName, 'alice');
    });

    test('decodes unicode labels', () {
      final u = OtpAuthUri.parse(
        'otpauth://totp/%E0%A4%89%E0%A4%A6%E0%A4%BE:%D8%B9%D9%84%D9%8A?secret=$_secret20',
      );
      expect(u.issuer, 'उदा');
      expect(u.accountName, 'علي');
    });

    test('rejects an empty account name', () {
      expect(
        () => OtpAuthUri.parse('otpauth://totp/?secret=$_secret20'),
        _uriError('label'),
      );
      expect(
        () => OtpAuthUri.parse('otpauth://totp/Example:?secret=$_secret20'),
        _uriError('label'),
      );
      expect(
        () => OtpAuthUri.parse('otpauth://totp?secret=$_secret20'),
        _uriError('label'),
      );
    });

    test('splits at whichever separator comes first, literal or encoded', () {
      final a = OtpAuthUri.parse(
        'otpauth://totp/Ex:al%3Aice?secret=$_secret20',
      );
      expect((a.issuer, a.accountName), ('Ex', 'al:ice'));
      final b = OtpAuthUri.parse(
        'otpauth://totp/Ex%3Aal:ice?secret=$_secret20',
      );
      expect((b.issuer, b.accountName), ('Ex', 'al:ice'));
    });

    test('rejects invalid UTF-8 in the label or parameters', () {
      expect(
        () => OtpAuthUri.parse('otpauth://totp/%FF?secret=$_secret20'),
        _uriError('label'),
      );
      expect(
        () => OtpAuthUri.parse(
          'otpauth://totp/a?secret=$_secret20&issuer=%C3%28',
        ),
        _uriError('uri'),
      );
    });

    test('rejects malformed percent-encoding', () {
      expect(
        () => OtpAuthUri.parse('otpauth://totp/al%ZZice?secret=$_secret20'),
        throwsFormatException,
      );
    });
  });

  group('OtpAuthUri.parse — parameters (FR-URI-01 AC2, AC4)', () {
    test('secret is required and must be valid base32', () {
      expect(
        () => OtpAuthUri.parse('otpauth://totp/alice'),
        _uriError('secret'),
      );
      expect(
        () => OtpAuthUri.parse('otpauth://totp/alice?secret='),
        _uriError('secret'),
      );
      expect(
        () => OtpAuthUri.parse('otpauth://totp/alice?secret=JBSWY3DP1'),
        _uriError('secret'),
      );
      expect(
        () => OtpAuthUri.parse('otpauth://totp/alice?secret=MZXW6'),
        _uriError('secret'),
        reason: 'too short',
      );
    });

    test('lower-case secrets with spaces are accepted', () {
      final u = OtpAuthUri.parse(
        'otpauth://totp/alice?secret=gezd%20gnbv%20gy3t%20qojq%20gezd%20gnbv%20gy3t%20qojq',
      );
      expect(u.secret.toBase32(), _secret20);
    });

    test('hotp requires a counter; it must be a non-negative integer', () {
      expect(
        () => OtpAuthUri.parse('otpauth://hotp/alice?secret=$_secret20'),
        _uriError('counter'),
      );
      for (final bad in [
        '-1',
        'x',
        '1.5',
        '٣',
        ' 1',
        '99999999999999999999',
        '9007199254740992',
      ]) {
        expect(
          () => OtpAuthUri.parse(
            'otpauth://hotp/alice?secret=$_secret20&counter=${Uri.encodeQueryComponent(bad)}',
          ),
          _uriError('counter'),
          reason: bad,
        );
      }
    });

    test('digits must be 6, 7 or 8', () {
      for (final bad in ['5', '9', 'six', '']) {
        expect(
          () => OtpAuthUri.parse(
            'otpauth://totp/a?secret=$_secret20&digits=$bad',
          ),
          _uriError('digits'),
          reason: bad,
        );
      }
      expect(
        OtpAuthUri.parse('otpauth://totp/a?secret=$_secret20&digits=7').digits,
        7,
      );
    });

    test('period must be a positive integer number of seconds', () {
      for (final bad in ['0', '-30', '1.5', 'x']) {
        expect(
          () => OtpAuthUri.parse(
            'otpauth://totp/a?secret=$_secret20&period=$bad',
          ),
          _uriError('period'),
          reason: bad,
        );
      }
      expect(
        OtpAuthUri.parse('otpauth://totp/a?secret=$_secret20&period=15').period,
        const Duration(seconds: 15),
      );
    });

    test('unknown algorithms are rejected', () {
      expect(
        () => OtpAuthUri.parse(
          'otpauth://totp/a?secret=$_secret20&algorithm=MD5',
        ),
        _uriError('algorithm'),
      );
    });

    test('duplicate known parameters are rejected as ambiguous', () {
      expect(
        () => OtpAuthUri.parse(
          'otpauth://totp/a?secret=$_secret20&secret=$_secret20',
        ),
        _uriError('secret'),
      );
      expect(
        () => OtpAuthUri.parse(
          'otpauth://totp/a?secret=$_secret20&digits=6&digits=8',
        ),
        _uriError('digits'),
      );
    });

    test('unknown parameters are preserved in extras', () {
      final u = OtpAuthUri.parse(
        'otpauth://totp/a?secret=$_secret20&image=https%3A%2F%2Fx.test%2Fl.png&foo=bar',
      );
      expect(u.extras, {'image': 'https://x.test/l.png', 'foo': 'bar'});
    });

    test('a counter on totp and a period on hotp are ignored', () {
      final t = OtpAuthUri.parse(
        'otpauth://totp/a?secret=$_secret20&counter=5',
      );
      expect(t.counter, isNull);
      expect(t.extras, isEmpty);
      final h = OtpAuthUri.parse(
        'otpauth://hotp/a?secret=$_secret20&counter=1&period=60',
      );
      expect(h.period, const Duration(seconds: 30));
      expect(h.extras, isEmpty);
    });

    test('known parameter names are matched case-insensitively', () {
      final u = OtpAuthUri.parse('otpauth://totp/a?Secret=$_secret20&DIGITS=8');
      expect(u.digits, 8);
    });

    test('non-otpauth schemes and unknown types are rejected', () {
      expect(
        () => OtpAuthUri.parse('https://totp/a?secret=$_secret20'),
        _uriError('scheme'),
      );
      expect(
        () => OtpAuthUri.parse('otpauth://motp/a?secret=$_secret20'),
        _uriError('type'),
      );
      expect(
        () => OtpAuthUri.parse('otpauth-migration://offline?data=x'),
        _uriError('scheme'),
      );
      expect(() => OtpAuthUri.parse('not a uri at all'), throwsFormatException);
      expect(() => OtpAuthUri.parse(''), throwsFormatException);
    });

    test('errors never contain the secret', () {
      try {
        OtpAuthUri.parse('otpauth://totp/a?secret=$_secret20&digits=9');
        fail('expected an error');
      } on OtpAuthUriException catch (e) {
        expect(e.toString(), isNot(contains('GEZD')));
        expect(e.source, isNull);
      }
    });
  });

  group('OtpAuthUri.tryParse', () {
    test('returns null instead of throwing', () {
      expect(OtpAuthUri.tryParse('https://example.com'), isNull);
      expect(
        OtpAuthUri.tryParse('otpauth://totp/a?secret=$_secret20'),
        isNotNull,
      );
    });
  });

  group('OtpAuthUri.toUri (FR-URI-02)', () {
    final secret = OtpSecret.fromBase32(_secret20);

    test('emits only non-default parameters, issuer in label and parameter', () {
      final u = OtpAuthUri(
        type: OtpType.totp,
        secret: secret,
        accountName: 'alice@example.com',
        issuer: 'ACME Co',
      );
      expect(
        u.toUri().toString(),
        'otpauth://totp/ACME%20Co:alice%40example.com?secret=$_secret20&issuer=ACME%20Co',
      );
    });

    test('emits algorithm, digits, period, counter and sorted extras', () {
      final u = OtpAuthUri(
        type: OtpType.hotp,
        secret: secret,
        accountName: 'bob',
        algorithm: OtpAlgorithm.sha512,
        digits: 8,
        counter: 7,
        extras: const {'z': '1', 'image': 'https://x.test/a b.png'},
      );
      expect(
        u.toUri().toString(),
        'otpauth://hotp/bob?secret=$_secret20&algorithm=SHA512&digits=8&counter=7'
        '&image=https%3A%2F%2Fx.test%2Fa%20b.png&z=1',
      );
    });

    test('rejects colons in issuer or account name (Key URI format)', () {
      expect(
        () => OtpAuthUri(
          type: OtpType.totp,
          secret: secret,
          accountName: 'a:b',
        ).toUri(),
        _uriError('label'),
      );
      expect(
        () => OtpAuthUri(
          type: OtpType.totp,
          secret: secret,
          accountName: 'a',
          issuer: 'x:y',
        ).toUri(),
        _uriError('issuer'),
      );
    });

    test('rejects invalid configuration', () {
      expect(
        () => OtpAuthUri(
          type: OtpType.totp,
          secret: secret,
          accountName: '',
        ).toUri(),
        _uriError('label'),
      );
      expect(
        () => OtpAuthUri(
          type: OtpType.totp,
          secret: secret,
          accountName: 'a',
          digits: 9,
        ).toUri(),
        _uriError('digits'),
      );
      expect(
        () => OtpAuthUri(
          type: OtpType.totp,
          secret: secret,
          accountName: 'a',
          period: const Duration(milliseconds: 1500),
        ).toUri(),
        _uriError('period'),
      );
      expect(
        () => OtpAuthUri(
          type: OtpType.hotp,
          secret: secret,
          accountName: 'a',
        ).toUri(),
        _uriError('counter'),
      );
      expect(
        () => OtpAuthUri(
          type: OtpType.hotp,
          secret: secret,
          accountName: 'a',
          counter: -1,
        ).toUri(),
        _uriError('counter'),
      );
      expect(
        () => OtpAuthUri(
          type: OtpType.totp,
          secret: secret,
          accountName: 'a',
          extras: const {'secret': 'x'},
        ).toUri(),
        _uriError('extras'),
      );
    });

    test('toString is redacted and never contains the secret', () {
      final u = OtpAuthUri(
        type: OtpType.totp,
        secret: secret,
        accountName: 'alice',
        issuer: 'Ex',
      );
      expect(
        u.toString(),
        'OtpAuthUri(totp, Ex:alice, secret: <redacted 20B>)',
      );
      expect(u.toString(), isNot(contains('GEZD')));
      expect(
        OtpAuthUri(
          type: OtpType.hotp,
          secret: secret,
          accountName: 'bob',
          counter: 1,
        ).toString(),
        'OtpAuthUri(hotp, bob, secret: <redacted 20B>)',
      );
    });

    test('value equality', () {
      OtpAuthUri make([String name = 'a']) => OtpAuthUri(
        type: OtpType.totp,
        secret: secret,
        accountName: name,
        extras: const {'k': 'v'},
      );
      expect(make(), make());
      expect(make().hashCode, make().hashCode);
      expect(make(), isNot(make('b')));
      expect(
        make(),
        isNot(
          OtpAuthUri(
            type: OtpType.totp,
            secret: secret,
            accountName: 'a',
            extras: const {'k': 'w'},
          ),
        ),
      );
    });
  });

  group('OtpAuthUri properties', () {
    test(
      'parse(toUri(x)) == x for random valid configurations (FR-URI-02 AC1)',
      () {
        final random = fuzzRandom(7);
        const chars = 'abcXYZ019 .@_-+!~*\'()/?#&=%éाع😀';
        String text(int min) => String.fromCharCodes(
          [
            for (var i = min + random.nextInt(12); i > 0; i--)
              chars.runes.elementAt(random.nextInt(chars.runes.length)),
          ],
        ).trim().padRight(min, 'x');
        for (var i = 0; i < fuzzRuns() ~/ 10; i++) {
          final type = random.nextBool() ? OtpType.totp : OtpType.hotp;
          final original = OtpAuthUri(
            type: type,
            secret: OtpSecret.fromBytes(
              Uint8List.fromList(
                List.generate(
                  10 + random.nextInt(60),
                  (_) => random.nextInt(256),
                ),
              ),
            ),
            accountName: text(1),
            issuer: random.nextBool() ? text(1) : null,
            algorithm: OtpAlgorithm.values[random.nextInt(3)],
            digits: 6 + random.nextInt(3),
            period: type == OtpType.totp
                ? Duration(seconds: 1 + random.nextInt(120))
                : const Duration(seconds: 30),
            counter: type == OtpType.hotp ? random.nextInt(1 << 31) : null,
            extras: random.nextBool() ? {'image': text(1)} : const {},
          );
          final parsed = OtpAuthUri.parse(original.toUri().toString());
          expect(parsed, original);
          expect(
            parsed.compatibilityWarnings.contains(
              CompatibilityWarning.issuerMismatch,
            ),
            isFalse,
          );
        }
      },
    );

    test('random and mutated input only ever throws FormatException '
        '(FR-URI-01 AC5)', () {
      final random = fuzzRandom(11);
      const seed =
          'otpauth://totp/Ex:alice?secret=$_secret20&issuer=Ex&digits=6&period=30&counter=1&algorithm=SHA1';
      const alphabet = 'otpauth:/?&=%3A:abcXYZ234567 -+.#@[]\\\u0000é😀';
      for (var i = 0; i < fuzzRuns(); i++) {
        final chars = seed.split('');
        for (var m = 1 + random.nextInt(4); m > 0; m--) {
          final pos = random.nextInt(chars.length + 1);
          final op = random.nextInt(3);
          final c = alphabet[random.nextInt(alphabet.length)];
          if (op == 0 && pos < chars.length) {
            chars[pos] = c;
          } else if (op == 1 && pos < chars.length) {
            chars.removeAt(pos);
          } else {
            chars.insert(pos, c);
          }
        }
        final input = random.nextInt(10) == 0
            ? String.fromCharCodes(
                List.generate(
                  random.nextInt(60),
                  (_) => random.nextInt(0x3000),
                ),
              )
            : chars.join();
        try {
          OtpAuthUri.parse(input);
        } on FormatException {
          // expected
        }
      }
    });
  });
}
