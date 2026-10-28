/// Optional camera scanner for `otpauth://` QR codes (ADR-0005).
///
/// [OtpQrScanner] reports parsed `OtpAuthUri`s. On the web it uses the
/// browser's `BarcodeDetector` and loads no remote decoder unless
/// [OtpQrWebOptions] opt in.
library;

import 'src/otp_qr_scanner.dart';
import 'src/otp_qr_web_options.dart';

export 'src/otp_qr_scanner.dart';
export 'src/otp_qr_scanner_status.dart' show OtpQrScannerStatus;
export 'src/otp_qr_web_options.dart' show OtpQrWebOptions;
