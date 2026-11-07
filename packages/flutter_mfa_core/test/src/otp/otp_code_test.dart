import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:test/test.dart';

void main() {
  OtpCode code(String v) => OtpCode(
    value: v,
    remaining: const Duration(seconds: 12),
    progress: 0.6,
    step: 3,
  );

  test('groups 6, 7 and 8 digit codes for readability (FR-UI-02 AC1)', () {
    expect(code('123456').grouped, '123 456');
    expect(code('1234567').grouped, '1234 567');
    expect(code('12345678').grouped, '1234 5678');
  });

  test('toString never contains the code', () {
    expect(
      code('123456').toString(),
      'OtpCode(<redacted 6 digits>, step: 3, remaining: 12000ms)',
    );
  });

  test('value equality', () {
    expect(code('123456'), code('123456'));
    expect(code('123456').hashCode, code('123456').hashCode);
    expect(code('123456'), isNot(code('654321')));
  });
}
