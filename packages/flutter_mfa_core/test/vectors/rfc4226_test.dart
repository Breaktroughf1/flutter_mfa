import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:flutter_mfa_core/src/testing/rfc_vectors.dart';
import 'package:test/test.dart';

void main() {
  test('there are exactly the 10 Appendix D vectors', () {
    expect(rfc4226Vectors.map((v) => v.counter), List.generate(10, (i) => i));
  });

  final hotp = Hotp(OtpSecret.fromBytes(rfc4226Secret));
  for (final v in rfc4226Vectors) {
    test('RFC 4226 Appendix D: counter ${v.counter} (FR-OTP-01 AC1)', () {
      expect(hotp.generate(v.counter), v.code);
    });
  }
}
