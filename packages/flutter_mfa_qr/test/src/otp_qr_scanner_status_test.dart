import 'package:flutter_mfa_qr/src/otp_qr_scanner_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  const denied = MobileScannerErrorCode.permissionDenied;

  test('a first denial where the system can ask again is denied', () {
    expect(
      statusForStartError(denied, canAskAgain: true, deniedBefore: false),
      OtpQrScannerStatus.denied,
    );
  });

  test('a repeated denial is permanently denied', () {
    expect(
      statusForStartError(denied, canAskAgain: true, deniedBefore: true),
      OtpQrScannerStatus.permanentlyDenied,
    );
  });

  test('where the system never asks again any denial is permanent', () {
    for (final before in [false, true]) {
      expect(
        statusForStartError(denied, canAskAgain: false, deniedBefore: before),
        OtpQrScannerStatus.permanentlyDenied,
      );
    }
  });

  test('every other failure is unavailable (FR-QR-02)', () {
    for (final code in MobileScannerErrorCode.values) {
      if (code == denied) continue;
      expect(
        statusForStartError(code, canAskAgain: true, deniedBefore: false),
        OtpQrScannerStatus.unavailable,
        reason: code.name,
      );
    }
  });
}
