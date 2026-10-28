// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'mfa_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class MfaLocalizationsHi extends MfaLocalizations {
  MfaLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get otpCodeFieldLabel => 'वन-टाइम कोड';

  @override
  String otpCodeFieldHint(int length) {
    return '$length अंकों का कोड दर्ज करें';
  }

  @override
  String get copyCode => 'कोड कॉपी करें';

  @override
  String get codeCopied => 'कोड कॉपी हो गया';

  @override
  String get showCode => 'कोड दिखाएँ';

  @override
  String get hideCode => 'कोड छिपाएँ';

  @override
  String get codeHidden => 'कोड छिपा हुआ है';

  @override
  String secondsRemaining(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds सेकंड बाकी',
      one: '1 सेकंड बाकी',
    );
    return '$_temp0';
  }

  @override
  String get statusEnrolled => 'सक्रिय';

  @override
  String get statusNotEnrolled => 'सक्रिय नहीं';

  @override
  String get statusLocked => 'लॉक है';

  @override
  String get statusKeyInvalidated => 'फिर से जोड़ना होगा';

  @override
  String get statusIntegrityWarning => 'डिवाइस जाँच चेतावनी';

  @override
  String get tapToGenerate => 'कोड बनाने के लिए टैप करें';

  @override
  String get noAccounts => 'अभी कोई खाता नहीं है';

  @override
  String get enrollmentQrLabel =>
      'इस खाते को ऑथेंटिकेटर ऐप में जोड़ने का QR कोड';

  @override
  String get setupKey => 'सेटअप कुंजी';

  @override
  String get copySetupKey => 'सेटअप कुंजी कॉपी करें';

  @override
  String get setupKeyCopied => 'सेटअप कुंजी कॉपी हो गई';

  @override
  String get enrollmentPrivacyWarning =>
      'इसे निजी रखें। जो भी यह QR कोड या कुंजी देखे या उसका स्क्रीनशॉट ले, वह आपके साइन-इन कोड बना सकता है।';

  @override
  String get scanHint => 'कैमरे को QR कोड की ओर रखें';

  @override
  String get cameraPermissionRequesting => 'कैमरा अनुमति की प्रतीक्षा है';

  @override
  String get cameraPermissionDenied =>
      'QR कोड स्कैन करने के लिए कैमरा अनुमति चाहिए।';

  @override
  String get cameraPermissionPermanentlyDenied =>
      'कैमरा अनुमति बंद है। स्कैन करने के लिए इसे सेटिंग्स में चालू करें।';

  @override
  String get openSettings => 'सेटिंग्स खोलें';

  @override
  String get tryAgain => 'फिर से कोशिश करें';

  @override
  String get cameraUnavailable =>
      'कोई कैमरा उपलब्ध नहीं है। इसके बजाय सेटअप कुंजी दर्ज करें।';

  @override
  String get cameraInsecureContext =>
      'स्कैन करने के लिए सुरक्षित (HTTPS) पेज चाहिए। इसके बजाय सेटअप कुंजी दर्ज करें।';

  @override
  String get paste => 'पेस्ट करें';

  @override
  String codeLabel(String digits) {
    return 'कोड $digits';
  }
}
