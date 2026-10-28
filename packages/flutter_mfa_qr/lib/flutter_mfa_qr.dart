/// Optional camera scanner for `otpauth://` QR codes (ADR-0005).
///
/// On the web it uses the browser's `BarcodeDetector` and loads no remote
/// decoder unless [OtpQrWebOptions] opt in.
library;

import 'src/otp_qr_web_options.dart';

export 'src/otp_qr_scanner_status.dart' show OtpQrScannerStatus;
export 'src/otp_qr_web_options.dart' show OtpQrWebOptions;
