import 'package:flutter_mfa/flutter_mfa.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RelyingPartyEnrollment enrol({
    String issuer = 'Breaktrough',
    String accountName = 'alice@example.com',
    TotpConfig config = const TotpConfig(),
  }) => MfaClient.createEnrollment(
    issuer: issuer,
    accountName: accountName,
    config: config,
  );

  test('the URI round-trips through the parser with every parameter '
      '(FR-FAC-07 AC1)', () {
    final e = enrol(
      issuer: ' Breaktrough ',
      accountName: ' alice@example.com ',
      config: const TotpConfig(
        algorithm: OtpAlgorithm.sha256,
        digits: 8,
        period: Duration(seconds: 60),
      ),
    );
    final parsed = OtpAuthUri.parse(e.uri.toUri().toString());
    expect(parsed.type, OtpType.totp);
    expect(parsed.issuer, 'Breaktrough');
    expect(parsed.accountName, 'alice@example.com');
    expect(parsed.algorithm, OtpAlgorithm.sha256);
    expect(parsed.digits, 8);
    expect(parsed.period, const Duration(seconds: 60));
    expect(parsed.secret, e.secret);
  });

  test('secrets have the recommended length and are new every time', () {
    for (final (algorithm, length) in [
      (OtpAlgorithm.sha1, 20),
      (OtpAlgorithm.sha256, 32),
      (OtpAlgorithm.sha512, 64),
    ]) {
      expect(
        enrol(config: TotpConfig(algorithm: algorithm)).secret.length,
        length,
      );
    }
    expect(enrol().secret, isNot(enrol().secret));
  });

  test(
    'the verifier confirms the first code and then rejects replays',
    () async {
      final e = enrol();
      final now = DateTime.utc(2026, 10, 28, 12);
      final code = Totp(e.secret).generate(now);

      final first = await e.verifier.verify(code, subject: 'alice', at: now);
      expect(first, isA<Accepted>());
      final replay = await e.verifier.verify(
        code,
        subject: 'alice',
        at: now,
        lastUsedStep: (first as Accepted).nextState,
      );
      expect(replay, const Rejected(RejectReason.replayed));

      final wrong = code == '000000' ? '111111' : '000000';
      expect(
        await e.verifier.verify(wrong, subject: 'alice', at: now),
        isA<Rejected>(),
      );
    },
  );

  test('invalid input is refused before a secret is used', () {
    Matcher field(String name) => throwsA(
      isA<OtpConfigException>().having((e) => e.field, 'field', name),
    );
    expect(() => enrol(issuer: '  '), field('issuer'));
    expect(() => enrol(accountName: ''), field('accountName'));
    expect(() => enrol(config: const TotpConfig(t0: 30)), field('t0'));
    expect(
      () => enrol(config: const TotpConfig(digits: 5)),
      throwsA(isA<MfaException>()),
    );
  });

  test('an issuer containing the label separator is refused', () {
    expect(
      () => enrol(issuer: 'Breaktrough: Staging'),
      throwsA(
        isA<OtpAuthUriException>().having((e) => e.field, 'field', 'issuer'),
      ),
    );
  });

  test('toString never reveals the secret', () {
    final e = enrol();
    expect(e.toString(), isNot(contains(e.secret.toBase32())));
    expect(e.toString(), contains('redacted'));
  });
}
