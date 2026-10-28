// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'mfa_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class MfaLocalizationsEn extends MfaLocalizations {
  MfaLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get otpCodeFieldLabel => 'One-time code';

  @override
  String otpCodeFieldHint(int length) {
    return 'Enter the $length-digit code';
  }

  @override
  String get copyCode => 'Copy code';

  @override
  String get codeCopied => 'Code copied';

  @override
  String get showCode => 'Show code';

  @override
  String get hideCode => 'Hide code';

  @override
  String get codeHidden => 'Code hidden';

  @override
  String secondsRemaining(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds left',
      one: '1 second left',
    );
    return '$_temp0';
  }

  @override
  String get statusEnrolled => 'Enrolled';

  @override
  String get statusNotEnrolled => 'Not enrolled';

  @override
  String get statusLocked => 'Locked';

  @override
  String get statusKeyInvalidated => 'Needs re-enrolment';

  @override
  String get statusIntegrityWarning => 'Device check warning';

  @override
  String get tapToGenerate => 'Tap to generate a code';

  @override
  String get noAccounts => 'No accounts yet';

  @override
  String get enrollmentQrLabel =>
      'QR code to add this account to an authenticator app';

  @override
  String get setupKey => 'Setup key';

  @override
  String get copySetupKey => 'Copy setup key';

  @override
  String get setupKeyCopied => 'Setup key copied';

  @override
  String get enrollmentPrivacyWarning =>
      'Keep this private. Anyone who sees or screenshots this QR code or key can generate your sign-in codes.';

  @override
  String get scanHint => 'Point the camera at the QR code';

  @override
  String get cameraPermissionRequesting => 'Waiting for camera permission';

  @override
  String get cameraPermissionDenied =>
      'Camera access is needed to scan the QR code.';

  @override
  String get cameraPermissionPermanentlyDenied =>
      'Camera access is turned off. Allow it in Settings to scan.';

  @override
  String get openSettings => 'Open settings';

  @override
  String get tryAgain => 'Try again';

  @override
  String get cameraUnavailable =>
      'No camera is available. Enter the setup key instead.';

  @override
  String get cameraInsecureContext =>
      'Scanning needs a secure (HTTPS) page. Enter the setup key instead.';

  @override
  String get scanUnsupportedBrowser =>
      'This browser can\'t scan QR codes. Enter the setup key instead.';

  @override
  String get paste => 'Paste';

  @override
  String codeLabel(String digits) {
    return 'Code $digits';
  }

  @override
  String get codeUnavailable => 'Code unavailable';

  @override
  String accountLabel(String issuer, String account) {
    return '$issuer, $account';
  }
}
