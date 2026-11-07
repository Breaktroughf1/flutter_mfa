import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:flutter_mfa_qr/flutter_mfa_qr.dart';
import 'package:flutter_mfa_ui/flutter_mfa_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

const _uri =
    'otpauth://totp/Breaktrough:alice?secret=JBSWY3DPEHPK3PXP&issuer=Breaktrough';

/// A camera that starts with [nextStart] and delivers [detect]ed codes.
final class _FakeScanner extends MobileScannerPlatform {
  final _barcodes = StreamController<BarcodeCapture?>.broadcast();
  final startOptions = <StartOptions>[];
  var stops = 0;
  var disposes = 0;

  /// The result of the next `start`; succeeds by default.
  Future<MobileScannerViewAttributes> Function() nextStart = _started;

  static Future<MobileScannerViewAttributes> _started() async =>
      const MobileScannerViewAttributes(
        cameraDirection: CameraFacing.back,
        currentTorchMode: TorchState.unavailable,
        size: Size(640, 480),
      );

  static Future<MobileScannerViewAttributes> Function() failWith(
    MobileScannerErrorCode code,
  ) =>
      () async => throw MobileScannerException(errorCode: code);

  void detect(List<String?> payloads) => _barcodes.add(
    BarcodeCapture(barcodes: [for (final p in payloads) Barcode(rawValue: p)]),
  );

  @override
  Stream<BarcodeCapture?> get barcodesStream => _barcodes.stream;

  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();

  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();

  @override
  Widget buildCameraView() => const SizedBox(key: Key('camera'));

  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) {
    this.startOptions.add(startOptions);
    return nextStart();
  }

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> updateScanWindow(Rect? window) async {}

  @override
  Future<void> dispose() async => disposes++;
}

Widget _host(Widget child) => MediaQuery(
  data: const MediaQueryData(),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: MfaTheme(
      data: MfaThemeData.light(),
      child: Center(child: SizedBox(width: 400, height: 600, child: child)),
    ),
  ),
);

void main() {
  late _FakeScanner camera;
  late List<OtpAuthUri> scanned;
  late List<String> rejected;

  setUp(() {
    camera = _FakeScanner();
    MobileScannerPlatform.instance = camera;
    scanned = [];
    rejected = [];
  });

  Future<void> pumpScanner(
    WidgetTester tester, {
    OtpQrStatusBuilder? permissionBuilder,
    WidgetBuilder? overlayBuilder,
    VoidCallback? onOpenSettings,
  }) async {
    await tester.pumpWidget(
      _host(
        OtpQrScanner(
          onScanned: scanned.add,
          onRejected: rejected.add,
          permissionBuilder: permissionBuilder,
          overlayBuilder: overlayBuilder,
          onOpenSettings: onOpenSettings,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('scans QR codes only, without keeping images', (tester) async {
    await pumpScanner(tester);
    expect(camera.startOptions.single.formats, [BarcodeFormat.qrCode]);
    expect(camera.startOptions.single.returnImage, isFalse);
    expect(find.byKey(const Key('camera')), findsOneWidget);
    expect(find.text('Point the camera at the QR code'), findsOneWidget);
  });

  testWidgets(
    'reports a valid code once and other codes as rejected (FR-QR-01)',
    (tester) async {
      await pumpScanner(tester);
      camera
        ..detect([_uri, null])
        ..detect([_uri])
        ..detect(['https://example.com']);
      await tester.pump();
      expect(scanned.single.issuer, 'Breaktrough');
      expect(rejected, ['https://example.com']);
    },
  );

  testWidgets('shows the requesting state while the camera starts', (
    tester,
  ) async {
    final started = Completer<MobileScannerViewAttributes>();
    camera.nextStart = () => started.future;
    await pumpScanner(tester);
    expect(find.text('Waiting for camera permission'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);

    started.complete(_FakeScanner._started());
    await tester.pump();
    await tester.pump();
    expect(find.text('Waiting for camera permission'), findsNothing);
    expect(find.text('Point the camera at the QR code'), findsOneWidget);
  });

  testWidgets(
    'on Android a first denial can be retried; a second one points to the settings (FR-QR-02)',
    (tester) async {
      var settingsOpened = 0;
      camera.nextStart = _FakeScanner.failWith(
        MobileScannerErrorCode.permissionDenied,
      );
      await pumpScanner(tester, onOpenSettings: () => settingsOpened++);
      expect(
        find.text('Camera access is needed to scan the QR code.'),
        findsOneWidget,
      );
      expect(find.text('Open settings'), findsNothing);

      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump();
      expect(camera.startOptions, hasLength(2));
      expect(
        find.text('Camera access is turned off. Allow it in Settings to scan.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Open settings'));
      expect(settingsOpened, 1);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'on iOS a denial is permanent; returning to the app retries',
    (tester) async {
      camera.nextStart = _FakeScanner.failWith(
        MobileScannerErrorCode.permissionDenied,
      );
      await pumpScanner(tester);
      expect(
        find.text('Camera access is turned off. Allow it in Settings to scan.'),
        findsOneWidget,
      );
      expect(find.text('Open settings'), findsNothing, reason: 'no callback');
      expect(find.text('Try again'), findsOneWidget);

      // The user allowed the camera in the settings and came back.
      camera.nextStart = _FakeScanner._started;
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(camera.startOptions, hasLength(2));
      expect(find.text('Point the camera at the QR code'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'a retry overlapping the return to the foreground starts the camera once',
    (tester) async {
      camera.nextStart = _FakeScanner.failWith(
        MobileScannerErrorCode.permissionDenied,
      );
      await pumpScanner(tester);
      final started = Completer<MobileScannerViewAttributes>();
      camera.nextStart = () => started.future;
      // Returning to the app retries quietly; the user taps "Try again"
      // while that start is still running.
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(camera.startOptions, hasLength(2), reason: 'second start refused');
      expect(find.text('Waiting for camera permission'), findsOneWidget);

      started.complete(_FakeScanner._started());
      await tester.pump();
      await tester.pump();
      expect(find.text('Point the camera at the QR code'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('no camera is unavailable and can be retried', (tester) async {
    camera.nextStart = _FakeScanner.failWith(
      MobileScannerErrorCode.unsupported,
    );
    await pumpScanner(tester);
    expect(
      find.text('No camera is available. Enter the setup key instead.'),
      findsOneWidget,
    );

    camera.nextStart = _FakeScanner._started;
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();
    expect(camera.startOptions, hasLength(2));
    expect(find.text('Point the camera at the QR code'), findsOneWidget);
  });

  testWidgets('custom status and overlay builders replace the defaults', (
    tester,
  ) async {
    final statuses = <OtpQrScannerStatus>[];
    late VoidCallback retry;
    camera.nextStart = _FakeScanner.failWith(
      MobileScannerErrorCode.genericError,
    );
    await pumpScanner(
      tester,
      permissionBuilder: (context, status, r) {
        statuses.add(status);
        retry = r;
        return Text('status ${status.name}');
      },
      overlayBuilder: (_) => const Text('custom overlay'),
    );
    expect(find.text('status unavailable'), findsOneWidget);
    expect(statuses.first, OtpQrScannerStatus.requesting);

    camera.nextStart = _FakeScanner._started;
    retry();
    await tester.pump();
    await tester.pump();
    expect(find.text('custom overlay'), findsOneWidget);
    expect(find.textContaining('status'), findsNothing);
  });

  testWidgets(
    'stops the camera in the background and restarts it on return',
    (tester) async {
      await pumpScanner(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(camera.stops, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(camera.startOptions, hasLength(2));

      // A plain resume (no earlier stop) does not start it twice.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(camera.startOptions, hasLength(2));
    },
  );

  testWidgets('releases the camera when removed', (tester) async {
    await pumpScanner(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(camera.disposes, 1);
    camera.detect([_uri]);
    await tester.pump();
    expect(scanned, isEmpty);
  });

  testWidgets('a start that fails before reaching the camera is unavailable', (
    tester,
  ) async {
    camera.nextStart = () async => throw StateError('not attached');
    await pumpScanner(tester);
    expect(
      find.text('No camera is available. Enter the setup key instead.'),
      findsOneWidget,
    );
  });

  testWidgets('status views meet tap target, label and contrast guidelines', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    camera.nextStart = _FakeScanner.failWith(
      MobileScannerErrorCode.permissionDenied,
    );
    await pumpScanner(tester, onOpenSettings: () {});
    expect(find.text('Open settings'), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
