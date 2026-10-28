import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'mfa_localizations_ar.dart';
import 'mfa_localizations_en.dart';
import 'mfa_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of MfaLocalizations
/// returned by `MfaLocalizations.of(context)`.
///
/// Applications need to include `MfaLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/mfa_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: MfaLocalizations.localizationsDelegates,
///   supportedLocales: MfaLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the MfaLocalizations.supportedLocales
/// property.
abstract class MfaLocalizations {
  MfaLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static MfaLocalizations? of(BuildContext context) {
    return Localizations.of<MfaLocalizations>(context, MfaLocalizations);
  }

  static const LocalizationsDelegate<MfaLocalizations> delegate =
      _MfaLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('hi'),
  ];

  /// Accessible label of the code entry field.
  ///
  /// In en, this message translates to:
  /// **'One-time code'**
  String get otpCodeFieldLabel;

  /// Accessible hint of the code entry field.
  ///
  /// In en, this message translates to:
  /// **'Enter the {length}-digit code'**
  String otpCodeFieldHint(int length);

  /// Action that copies the current code.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get copyCode;

  /// Announced after the code was copied.
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get codeCopied;

  /// Action that reveals a hidden code.
  ///
  /// In en, this message translates to:
  /// **'Show code'**
  String get showCode;

  /// Action that hides the code.
  ///
  /// In en, this message translates to:
  /// **'Hide code'**
  String get hideCode;

  /// Accessible value of a hidden code.
  ///
  /// In en, this message translates to:
  /// **'Code hidden'**
  String get codeHidden;

  /// Time left before the code changes.
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, =1{1 second left} other{{seconds} seconds left}}'**
  String secondsRemaining(int seconds);

  /// Status: two-factor authentication is set up.
  ///
  /// In en, this message translates to:
  /// **'Enrolled'**
  String get statusEnrolled;

  /// Status: two-factor authentication is not set up.
  ///
  /// In en, this message translates to:
  /// **'Not enrolled'**
  String get statusNotEnrolled;

  /// Status: too many failed attempts.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get statusLocked;

  /// Status: biometrics changed, the account must be added again.
  ///
  /// In en, this message translates to:
  /// **'Needs re-enrolment'**
  String get statusKeyInvalidated;

  /// Status: the device integrity check reported a problem.
  ///
  /// In en, this message translates to:
  /// **'Device check warning'**
  String get statusIntegrityWarning;

  /// Shown for counter-based accounts before a code is generated.
  ///
  /// In en, this message translates to:
  /// **'Tap to generate a code'**
  String get tapToGenerate;

  /// Shown when the account list is empty.
  ///
  /// In en, this message translates to:
  /// **'No accounts yet'**
  String get noAccounts;

  /// Accessible label of the enrolment QR code.
  ///
  /// In en, this message translates to:
  /// **'QR code to add this account to an authenticator app'**
  String get enrollmentQrLabel;

  /// Title of the manually typed secret.
  ///
  /// In en, this message translates to:
  /// **'Setup key'**
  String get setupKey;

  /// Action that copies the setup key.
  ///
  /// In en, this message translates to:
  /// **'Copy setup key'**
  String get copySetupKey;

  /// Announced after the setup key was copied.
  ///
  /// In en, this message translates to:
  /// **'Setup key copied'**
  String get setupKeyCopied;

  /// Warning shown with the enrolment QR code.
  ///
  /// In en, this message translates to:
  /// **'Keep this private. Anyone who sees or screenshots this QR code or key can generate your sign-in codes.'**
  String get enrollmentPrivacyWarning;

  /// Instruction shown while scanning.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the QR code'**
  String get scanHint;

  /// Shown while the camera permission prompt is open.
  ///
  /// In en, this message translates to:
  /// **'Waiting for camera permission'**
  String get cameraPermissionRequesting;

  /// Shown when the camera permission was denied.
  ///
  /// In en, this message translates to:
  /// **'Camera access is needed to scan the QR code.'**
  String get cameraPermissionDenied;

  /// Shown when the camera permission was denied permanently.
  ///
  /// In en, this message translates to:
  /// **'Camera access is turned off. Allow it in Settings to scan.'**
  String get cameraPermissionPermanentlyDenied;

  /// Action that opens the system settings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// Action that retries.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// Shown when no camera can be used.
  ///
  /// In en, this message translates to:
  /// **'No camera is available. Enter the setup key instead.'**
  String get cameraUnavailable;

  /// Shown on the web outside a secure context.
  ///
  /// In en, this message translates to:
  /// **'Scanning needs a secure (HTTPS) page. Enter the setup key instead.'**
  String get cameraInsecureContext;

  /// Action that pastes a code from the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// Accessible label of a code; digits are separated by spaces so they are read one by one.
  ///
  /// In en, this message translates to:
  /// **'Code {digits}'**
  String codeLabel(String digits);

  /// Shown when the code could not be produced (for example the vault is locked).
  ///
  /// In en, this message translates to:
  /// **'Code unavailable'**
  String get codeUnavailable;

  /// Accessible label of an account with an issuer.
  ///
  /// In en, this message translates to:
  /// **'{issuer}, {account}'**
  String accountLabel(String issuer, String account);
}

class _MfaLocalizationsDelegate
    extends LocalizationsDelegate<MfaLocalizations> {
  const _MfaLocalizationsDelegate();

  @override
  Future<MfaLocalizations> load(Locale locale) {
    return SynchronousFuture<MfaLocalizations>(lookupMfaLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_MfaLocalizationsDelegate old) => false;
}

MfaLocalizations lookupMfaLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return MfaLocalizationsAr();
    case 'en':
      return MfaLocalizationsEn();
    case 'hi':
      return MfaLocalizationsHi();
  }

  throw FlutterError(
    'MfaLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
