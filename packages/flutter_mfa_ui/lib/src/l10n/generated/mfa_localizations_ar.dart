// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'mfa_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class MfaLocalizationsAr extends MfaLocalizations {
  MfaLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get otpCodeFieldLabel => 'رمز لمرة واحدة';

  @override
  String otpCodeFieldHint(int length) {
    return 'أدخل الرمز المكوّن من $length أرقام';
  }

  @override
  String get copyCode => 'نسخ الرمز';

  @override
  String get codeCopied => 'تم نسخ الرمز';

  @override
  String get showCode => 'إظهار الرمز';

  @override
  String get hideCode => 'إخفاء الرمز';

  @override
  String get codeHidden => 'الرمز مخفي';

  @override
  String secondsRemaining(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'تبقّت $seconds ثانية',
      many: 'تبقّت $seconds ثانية',
      few: 'تبقّت $seconds ثوانٍ',
      two: 'تبقّت ثانيتان',
      one: 'تبقّت ثانية واحدة',
      zero: 'لم يتبقَّ وقت',
    );
    return '$_temp0';
  }

  @override
  String get statusEnrolled => 'مُفعّل';

  @override
  String get statusNotEnrolled => 'غير مُفعّل';

  @override
  String get statusLocked => 'مُقفل';

  @override
  String get statusKeyInvalidated => 'تجب إعادة الإضافة';

  @override
  String get statusIntegrityWarning => 'تحذير من فحص الجهاز';

  @override
  String get tapToGenerate => 'انقر لإنشاء رمز';

  @override
  String get noAccounts => 'لا توجد حسابات بعد';

  @override
  String get enrollmentQrLabel => 'رمز QR لإضافة هذا الحساب إلى تطبيق المصادقة';

  @override
  String get setupKey => 'مفتاح الإعداد';

  @override
  String get copySetupKey => 'نسخ مفتاح الإعداد';

  @override
  String get setupKeyCopied => 'تم نسخ مفتاح الإعداد';

  @override
  String get enrollmentPrivacyWarning =>
      'حافظ على سرية هذا. يستطيع أي شخص يرى رمز QR أو المفتاح أو يلتقط لقطة شاشة له إنشاء رموز تسجيل الدخول الخاصة بك.';

  @override
  String get scanHint => 'وجّه الكاميرا نحو رمز QR';

  @override
  String get cameraPermissionRequesting => 'في انتظار إذن الكاميرا';

  @override
  String get cameraPermissionDenied => 'يلزم الوصول إلى الكاميرا لمسح رمز QR.';

  @override
  String get cameraPermissionPermanentlyDenied =>
      'الوصول إلى الكاميرا مُعطّل. اسمح به من الإعدادات للمسح.';

  @override
  String get openSettings => 'فتح الإعدادات';

  @override
  String get tryAgain => 'حاول مرة أخرى';

  @override
  String get cameraUnavailable =>
      'لا تتوفر كاميرا. أدخل مفتاح الإعداد بدلاً من ذلك.';

  @override
  String get cameraInsecureContext =>
      'يتطلب المسح صفحة آمنة (HTTPS). أدخل مفتاح الإعداد بدلاً من ذلك.';
}
