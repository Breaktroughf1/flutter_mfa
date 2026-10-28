import 'package:mobile_scanner/mobile_scanner.dart';

/// Why `OtpQrScanner` is not showing the camera (FR-QR-02).
///
/// Passed to `OtpQrScanner.permissionBuilder`. Offer manual entry of the
/// setup key in every state except [requesting].
enum OtpQrScannerStatus {
  /// The camera is starting; the system permission prompt may be open.
  requesting,

  /// The user declined camera access; asking again may show the prompt.
  denied,

  /// Camera access is off and the system will not ask again; only the
  /// system settings can turn it back on.
  permanentlyDenied,

  /// No camera can be used (none present, in use by another app, or it
  /// failed to start).
  unavailable,

  /// The browser has no built-in QR decoder (`BarcodeDetector`) and the
  /// `OtpQrWebOptions` allow no script decoder. The camera is never
  /// requested.
  unsupportedBrowser,

  /// The web page is not a secure (HTTPS) context, so the browser blocks the
  /// camera. The camera is never requested.
  insecureContext,
}

/// The status for a camera start that failed with [code].
///
/// Only Android shows the permission prompt again after a denial, and only
/// until the user has declined twice (or chosen "Don't ask again"). It does
/// not report which case applies, so a first denial there is [denied] and a
/// denial after asking again is [permanentlyDenied]. iOS and browsers never
/// ask again, so any denial there is [permanentlyDenied].
OtpQrScannerStatus statusForStartError(
  MobileScannerErrorCode code, {
  required bool canAskAgain,
  required bool deniedBefore,
}) {
  if (code != MobileScannerErrorCode.permissionDenied) {
    return OtpQrScannerStatus.unavailable;
  }
  return canAskAgain && !deniedBefore
      ? OtpQrScannerStatus.denied
      : OtpQrScannerStatus.permanentlyDenied;
}
