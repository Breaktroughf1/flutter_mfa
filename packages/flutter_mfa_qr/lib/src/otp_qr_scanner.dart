import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:flutter_mfa_ui/flutter_mfa_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'otp_qr_scanner_status.dart';
import 'otp_qr_web_options.dart';
import 'payload_filter.dart';
import 'web/browser.dart';

/// Builds what [OtpQrScanner] shows instead of the camera in [status].
///
/// Call [retry] to start the camera again (for example from a "Try again"
/// button).
typedef OtpQrStatusBuilder =
    Widget Function(
      BuildContext context,
      OtpQrScannerStatus status,
      VoidCallback retry,
    );

/// A camera view that scans `otpauth://` enrolment QR codes (FR-QR-01..03).
///
/// Reports each valid code once through [onScanned], however long it stays in
/// front of the camera; anything else goes to [onRejected]. Payloads are
/// never logged and images are never kept. On Android the decoding uses the
/// on-device ML Kit model, on iOS Apple's Vision framework, and on the web
/// the browser's `BarcodeDetector` unless [webOptions] opt in to a script.
///
/// It fills its parent (give it a bounded size). While the camera cannot be
/// shown it shows [permissionBuilder] (by default a localized message with
/// "Try again" and, when [onOpenSettings] is set, "Open settings"); always
/// give users a way to type the setup key instead.
///
/// The app must declare camera use: `NSCameraUsageDescription` in
/// `Info.plist` on iOS. Android's camera permission comes from
/// mobile_scanner. See the package README for the web
/// Content-Security-Policy.
class OtpQrScanner extends StatefulWidget {
  /// Creates a scanner that reports parsed URIs to [onScanned].
  const OtpQrScanner({
    super.key,
    required this.onScanned,
    this.onRejected,
    this.permissionBuilder,
    this.overlayBuilder,
    this.onOpenSettings,
    this.webOptions = const OtpQrWebOptions(),
  });

  /// Called once for each valid `otpauth://` code detected.
  ///
  /// The URI holds the account secret: enrol it (for example with
  /// `MfaClient.enrollFromUri(uri.toUri().toString())`) and drop it.
  final ValueChanged<OtpAuthUri> onScanned;

  /// Called with the raw text of a QR code that is not a valid `otpauth://`
  /// URI, for example to say "This is not an authenticator QR code".
  ///
  /// The text may contain a secret (a malformed enrolment URI): never log
  /// or send it anywhere.
  final ValueChanged<String>? onRejected;

  /// Replaces the built-in view shown instead of the camera (FR-QR-02).
  /// `mfaStrings(context)` gives the built-in localized messages.
  final OtpQrStatusBuilder? permissionBuilder;

  /// Drawn over the camera preview; the default shows a viewfinder and
  /// "Point the camera at the QR code".
  final WidgetBuilder? overlayBuilder;

  /// Opens the system or browser settings, for example with a package such
  /// as `app_settings`. When set, the built-in view offers "Open settings"
  /// once camera access is permanently denied. The scanner retries when the
  /// app returns to the foreground in that state.
  final VoidCallback? onOpenSettings;

  /// How QR codes are decoded on the web; ignored on other platforms. Read
  /// when the scanner is first shown.
  final OtpQrWebOptions webOptions;

  @override
  State<OtpQrScanner> createState() => _OtpQrScannerState();
}

class _OtpQrScannerState extends State<OtpQrScanner>
    with WidgetsBindingObserver {
  final _controller = MobileScannerController(
    autoStart: false,
    formats: const [BarcodeFormat.qrCode],
  );
  final _filter = PayloadFilter();
  StreamSubscription<BarcodeCapture>? _barcodes;

  /// Why the camera is not shown, or `null` while it is scanning.
  OtpQrScannerStatus? _status = OtpQrScannerStatus.requesting;
  MobileScannerException? _lastError;
  bool _deniedBefore = false;
  bool _stoppedInBackground = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb && !isSecureContext) {
      _status = OtpQrScannerStatus.insecureContext;
      return;
    }
    var nativeDecoderOnly = false;
    if (kIsWeb) {
      final (reader, scriptUrl) = webDecoderFor(widget.webOptions);
      nativeDecoderOnly = reader == WebBarcodeReader.barcodeDetector;
      MobileScannerPlatform.instance.setWebBarcodeReader(reader);
      if (scriptUrl != null) {
        MobileScannerPlatform.instance.setBarcodeLibraryScriptUrl(scriptUrl);
      }
    }
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_onScannerState);
    _barcodes = _controller.barcodes.listen(
      _onCapture,
      // A frame that failed to decode: keep scanning.
      onError: (Object _) {},
    );
    unawaited(_begin(nativeDecoderOnly: nativeDecoderOnly));
  }

  /// Starts the camera unless nothing could decode what it sees.
  Future<void> _begin({required bool nativeDecoderOnly}) async {
    if (nativeDecoderOnly && !await supportsNativeQrDecoding()) {
      if (mounted) {
        setState(() => _status = OtpQrScannerStatus.unsupportedBrowser);
      }
      return;
    }
    if (mounted) await _start();
  }

  Future<void> _start() async {
    try {
      await _controller.start();
    } on Object catch (error) {
      // Another start (a retry or the return to the foreground) is running.
      if (error is MobileScannerException &&
          error.errorCode == MobileScannerErrorCode.controllerInitializing) {
        return;
      }
      // Disposed or detached while starting; errors from the camera itself
      // arrive through the controller's state.
      if (mounted && _status != null) {
        setState(() => _status = OtpQrScannerStatus.unavailable);
      }
    }
  }

  void _retry() {
    setState(() => _status = OtpQrScannerStatus.requesting);
    unawaited(_start());
  }

  void _onScannerState() {
    final value = _controller.value;
    final error = value.error;
    OtpQrScannerStatus? next = _status;
    if (error != null) {
      if (identical(error, _lastError)) return;
      _lastError = error;
      next = statusForStartError(
        error.errorCode,
        canAskAgain: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
        deniedBefore: _deniedBefore,
      );
      if (error.errorCode == MobileScannerErrorCode.permissionDenied) {
        _deniedBefore = true;
      }
    } else if (value.isRunning) {
      next = null;
    }
    if (next != _status) setState(() => _status = next);
  }

  void _onCapture(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final payload = barcode.rawValue;
      if (payload == null) continue;
      switch (_filter.check(payload)) {
        case ScanAccepted(:final uri):
          widget.onScanned(uri);
        case ScanRejected(:final payload):
          widget.onRejected?.call(payload);
        case null:
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
        if (_controller.value.isRunning) {
          _stoppedInBackground = true;
          unawaited(_controller.stop());
        }
      case AppLifecycleState.resumed:
        if (_stoppedInBackground) {
          _stoppedInBackground = false;
          unawaited(_start());
        } else if (_status == OtpQrScannerStatus.permanentlyDenied) {
          // The user may have allowed the camera in the settings.
          unawaited(_start());
        }
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onScannerState);
    unawaited(_barcodes?.cancel());
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (status != OtpQrScannerStatus.insecureContext)
          MobileScanner(
            controller: _controller,
            placeholderBuilder: (_) => const SizedBox.expand(),
            errorBuilder: (_, _) => const SizedBox.expand(),
            overlayBuilder: (context, _) =>
                widget.overlayBuilder?.call(context) ?? const _Viewfinder(),
          ),
        if (status != null)
          (widget.permissionBuilder ?? _defaultStatusView)(
            context,
            status,
            _retry,
          ),
      ],
    );
  }

  Widget _defaultStatusView(
    BuildContext context,
    OtpQrScannerStatus status,
    VoidCallback retry,
  ) {
    final theme = MfaTheme.of(context);
    final strings = mfaStrings(context);
    final openSettings = widget.onOpenSettings;
    final (message, actions) = switch (status) {
      OtpQrScannerStatus.requesting => (
        strings.cameraPermissionRequesting,
        const <Widget>[],
      ),
      OtpQrScannerStatus.denied => (
        strings.cameraPermissionDenied,
        [_ActionButton(label: strings.tryAgain, onTap: retry)],
      ),
      OtpQrScannerStatus.permanentlyDenied => (
        strings.cameraPermissionPermanentlyDenied,
        [
          if (openSettings != null)
            _ActionButton(label: strings.openSettings, onTap: openSettings),
          _ActionButton(label: strings.tryAgain, onTap: retry),
        ],
      ),
      OtpQrScannerStatus.unavailable => (
        strings.cameraUnavailable,
        [_ActionButton(label: strings.tryAgain, onTap: retry)],
      ),
      OtpQrScannerStatus.unsupportedBrowser => (
        strings.scanUnsupportedBrowser,
        const <Widget>[],
      ),
      OtpQrScannerStatus.insecureContext => (
        strings.cameraInsecureContext,
        const <Widget>[],
      ),
    };
    return ColoredBox(
      color: theme.surface,
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(theme.spacing * 3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                liveRegion: true,
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.bodyTextStyle.copyWith(color: theme.onSurface),
                ),
              ),
              if (actions.isNotEmpty) SizedBox(height: theme.spacing * 2),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: theme.spacing,
                runSpacing: theme.spacing,
                children: actions,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A text button meeting the theme's minimum tap target.
class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = MfaTheme.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: theme.minTapTarget,
            minWidth: theme.minTapTarget,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.primary,
              borderRadius: BorderRadius.circular(theme.radius),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing * 2,
                vertical: theme.spacing,
              ),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: Text(
                  label,
                  style: theme.labelTextStyle.copyWith(color: theme.onPrimary),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A square frame and a hint over the camera preview.
class _Viewfinder extends StatelessWidget {
  const _Viewfinder();

  @override
  Widget build(BuildContext context) {
    final theme = MfaTheme.of(context);
    return Column(
      children: [
        const Spacer(),
        FractionallySizedBox(
          widthFactor: 0.65,
          child: AspectRatio(
            aspectRatio: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFFFFFFF), width: 3),
                borderRadius: BorderRadius.circular(theme.radius),
              ),
            ),
          ),
        ),
        const Spacer(),
        Padding(
          padding: EdgeInsets.all(theme.spacing * 2),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xCC000000),
              borderRadius: BorderRadius.circular(theme.radius),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing * 2,
                vertical: theme.spacing,
              ),
              child: Text(
                mfaStrings(context).scanHint,
                textAlign: TextAlign.center,
                style: theme.bodyTextStyle.copyWith(
                  color: const Color(0xFFFFFFFF),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
