import 'package:flutter_mfa_qr/src/otp_qr_web_options.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  test('by default only the native BarcodeDetector is used (FR-QR-03 AC1)', () {
    expect(const OtpQrWebOptions().allowRemoteDecoder, isFalse);
    expect(const OtpQrWebOptions().decoderScriptUrl, isNull);
    expect(webDecoderFor(const OtpQrWebOptions()), (
      WebBarcodeReader.barcodeDetector,
      null,
    ));
  });

  test('allowRemoteDecoder falls back to the CDN decoder', () {
    expect(webDecoderFor(const OtpQrWebOptions(allowRemoteDecoder: true)), (
      WebBarcodeReader.auto,
      null,
    ));
  });

  test(
    'a self-hosted script uses the self-contained zxing reader and wins',
    () {
      for (final url in [
        'zxing/index.min.js',
        '/static/zxing.js',
        'https://assets.example.com/zxing.js',
      ]) {
        expect(
          webDecoderFor(
            OtpQrWebOptions(
              allowRemoteDecoder: true,
              decoderScriptUrl: Uri.parse(url),
            ),
          ),
          (WebBarcodeReader.zxingJs, url),
        );
      }
    },
  );

  test(
    'scripts over plain HTTP or from script-capable schemes are refused',
    () {
      for (final url in [
        'http://example.com/zxing.js',
        '//cdn.example.com/zxing.js',
        'data:text/javascript,alert(1)',
        'javascript:alert(1)',
        'https:zxing.js',
        '',
      ]) {
        expect(
          () =>
              webDecoderFor(OtpQrWebOptions(decoderScriptUrl: Uri.parse(url))),
          throwsArgumentError,
          reason: url,
        );
      }
    },
  );

  test('options compare by value', () {
    final a = OtpQrWebOptions(decoderScriptUrl: Uri.parse('z.js'));
    final b = OtpQrWebOptions(decoderScriptUrl: Uri.parse('z.js'));
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(const OtpQrWebOptions()));
  });
}
