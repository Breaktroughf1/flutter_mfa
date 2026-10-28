import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:flutter_mfa_core/src/testing/rfc_vectors.dart';
import 'package:test/test.dart';

void main() {
  test('there are exactly the 18 Appendix B vectors', () {
    expect(rfc6238Vectors, hasLength(18));
  });

  test('seeds have the per-algorithm RFC lengths', () {
    expect(rfc6238Seed(OtpAlgorithm.sha1), hasLength(20));
    expect(rfc6238Seed(OtpAlgorithm.sha256), hasLength(32));
    expect(rfc6238Seed(OtpAlgorithm.sha512), hasLength(64));
    expect(
      String.fromCharCodes(rfc6238Seed(OtpAlgorithm.sha256)),
      '12345678901234567890123456789012',
    );
  });

  for (final v in rfc6238Vectors) {
    test('RFC 6238 Appendix B: ${v.algorithm.name} at ${v.unixSeconds} '
        '(FR-OTP-02 AC1)', () {
      final totp = Totp(
        OtpSecret.fromBytes(rfc6238Seed(v.algorithm)),
        config: TotpConfig(algorithm: v.algorithm, digits: 8),
      );
      final at = DateTime.fromMillisecondsSinceEpoch(
        v.unixSeconds * 1000,
        isUtc: true,
      );
      expect(totp.generate(at), v.code);
    });
  }
}
