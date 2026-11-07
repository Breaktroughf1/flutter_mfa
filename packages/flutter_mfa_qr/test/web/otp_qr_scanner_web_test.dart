@TestOn('browser')
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_mfa_qr/flutter_mfa_qr.dart';
import 'package:flutter_mfa_qr/src/web/browser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Records the web decoder configuration; the camera never starts.
final class _FakeScanner extends MobileScannerPlatform {
  final readers = <WebBarcodeReader>[];
  final scriptUrls = <String>[];
  var starts = 0;
  final _pending = Completer<MobileScannerViewAttributes>();

  @override
  void setWebBarcodeReader(WebBarcodeReader reader) => readers.add(reader);

  @override
  void setBarcodeLibraryScriptUrl(String scriptUrl) =>
      scriptUrls.add(scriptUrl);

  @override
  Stream<BarcodeCapture?> get barcodesStream => const Stream.empty();

  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();

  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();

  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) {
    starts++;
    return _pending.future;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  late _FakeScanner camera;

  setUp(() => MobileScannerPlatform.instance = camera = _FakeScanner());

  Future<void> pumpScanner(WidgetTester tester, OtpQrWebOptions options) =>
      tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: OtpQrScanner(onScanned: (_) {}, webOptions: options),
        ),
      );

  test('the test page is a secure context', () {
    expect(isSecureContext, isTrue);
  });

  testWidgets('loads no decoder script by default (FR-QR-03 AC1)', (
    tester,
  ) async {
    await pumpScanner(tester, const OtpQrWebOptions());
    expect(camera.readers, [WebBarcodeReader.barcodeDetector]);
    expect(camera.scriptUrls, isEmpty);
  });

  testWidgets(
    'without a native QR decoder the camera is never requested by default',
    (tester) async {
      final native = await tester.runAsync(supportsNativeQrDecoding);
      await pumpScanner(tester, const OtpQrWebOptions());
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      const message =
          "This browser can't scan QR codes. Enter the setup key instead.";
      if (native!) {
        expect(camera.starts, 1);
        expect(find.text(message), findsNothing);
      } else {
        expect(camera.starts, 0);
        expect(find.text(message), findsOneWidget);
      }
    },
  );

  testWidgets(
    'a retry offered by a custom builder never starts the camera without a '
    'decoder',
    (tester) async {
      final native = await tester.runAsync(supportsNativeQrDecoding);
      VoidCallback? retry;
      OtpQrScannerStatus? shown;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: OtpQrScanner(
            onScanned: (_) {},
            permissionBuilder: (context, status, r) {
              shown = status;
              retry = r;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      if (native!) return; // this browser can decode: nothing to check
      expect(shown, OtpQrScannerStatus.unsupportedBrowser);
      retry!();
      await tester.pump();
      expect(camera.starts, 0);
      expect(shown, OtpQrScannerStatus.unsupportedBrowser);
    },
  );

  testWidgets('a self-hosted decoder script is used when supplied', (
    tester,
  ) async {
    await pumpScanner(
      tester,
      OtpQrWebOptions(decoderScriptUrl: Uri.parse('zxing/index.min.js')),
    );
    expect(camera.readers, [WebBarcodeReader.zxingJs]);
    expect(camera.scriptUrls, ['zxing/index.min.js']);
  });

  testWidgets('the CDN decoder is used only when allowed', (tester) async {
    await pumpScanner(tester, const OtpQrWebOptions(allowRemoteDecoder: true));
    expect(camera.readers, [WebBarcodeReader.auto]);
    expect(camera.scriptUrls, isEmpty);
  });
}
