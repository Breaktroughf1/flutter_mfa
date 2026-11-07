import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:flutter_mfa_core/testing.dart';
import 'package:flutter_mfa_qr/src/payload_filter.dart';
import 'package:flutter_test/flutter_test.dart';

const _uri =
    'otpauth://totp/Breaktrough:alice%40example.com?secret=JBSWY3DPEHPK3PXP&issuer=Breaktrough';

void main() {
  late FakeClock clock;
  late PayloadFilter filter;

  setUp(() {
    clock = FakeClock(DateTime.utc(2026, 10, 28));
    filter = PayloadFilter(clock: clock);
  });

  test('accepts a valid otpauth URI as a parsed OtpAuthUri (FR-QR-01 AC1)', () {
    final result = filter.check(_uri);
    expect(result, isA<ScanAccepted>());
    final uri = (result! as ScanAccepted).uri;
    expect(uri.issuer, 'Breaktrough');
    expect(uri.accountName, 'alice@example.com');
    expect(uri.type, OtpType.totp);
  });

  test('rejects other payloads and malformed otpauth URIs', () {
    for (final payload in [
      'https://example.com',
      'WIFI:S:home;T:WPA;P:pass;;',
      'otpauth://totp/a?secret=not-base32!',
      'otpauth://unknown/a?secret=JBSWY3DPEHPK3PXP',
    ]) {
      final result = filter.check(payload);
      expect(result, isA<ScanRejected>());
      expect((result! as ScanRejected).payload, payload);
    }
  });

  test('ignores empty payloads', () {
    expect(filter.check(''), isNull);
  });

  test('reports a code held in front of the camera once (FR-QR-01 AC2)', () {
    expect(filter.check(_uri), isA<ScanAccepted>());
    for (var i = 0; i < 20; i++) {
      clock.advance(const Duration(milliseconds: 500));
      expect(filter.check(_uri), isNull, reason: 'detection $i');
    }
  });

  test('reports the same code again after it was out of view', () {
    expect(filter.check(_uri), isA<ScanAccepted>());
    clock.advance(const Duration(seconds: 2));
    expect(filter.check(_uri), isA<ScanAccepted>());
  });

  test('a different code is reported at once and resets the window', () {
    expect(filter.check(_uri), isA<ScanAccepted>());
    expect(filter.check('hello'), isA<ScanRejected>());
    expect(filter.check('hello'), isNull, reason: 'rejections debounce too');
    expect(filter.check(_uri), isA<ScanAccepted>());
  });

  test('the parsed URI does not reveal the secret in toString', () {
    final uri = (filter.check(_uri)! as ScanAccepted).uri;
    expect(uri.toString(), isNot(contains('JBSWY3DPEHPK3PXP')));
  });
}
