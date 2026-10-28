import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_mfa_ui/flutter_mfa_ui.dart';
import 'package:flutter_mfa_ui/src/l10n/mfa_strings.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every message, so a new string without a translation fails coverage.
List<String> allMessages(MfaLocalizations l) => [
  l.otpCodeFieldLabel,
  l.otpCodeFieldHint(6),
  l.copyCode,
  l.codeCopied,
  l.showCode,
  l.hideCode,
  l.codeHidden,
  for (final n in [0, 1, 2, 3, 11, 100]) l.secondsRemaining(n),
  l.statusEnrolled,
  l.statusNotEnrolled,
  l.statusLocked,
  l.statusKeyInvalidated,
  l.statusIntegrityWarning,
  l.tapToGenerate,
  l.noAccounts,
  l.enrollmentQrLabel,
  l.setupKey,
  l.copySetupKey,
  l.setupKeyCopied,
  l.enrollmentPrivacyWarning,
  l.scanHint,
  l.cameraPermissionRequesting,
  l.cameraPermissionDenied,
  l.cameraPermissionPermanentlyDenied,
  l.openSettings,
  l.tryAgain,
  l.cameraUnavailable,
  l.cameraInsecureContext,
  l.paste,
];

void main() {
  test('supports English, Hindi and Arabic (FR-UI-07 AC2)', () {
    expect(
      MfaLocalizations.supportedLocales.map((l) => l.languageCode).toSet(),
      {'en', 'hi', 'ar'},
    );
  });

  for (final locale in MfaLocalizations.supportedLocales) {
    test('${locale.languageCode}: every message is translated and filled', () {
      final l = lookupMfaLocalizations(locale);
      final messages = allMessages(l);
      expect(messages, everyElement(isNotEmpty));
      expect(messages, everyElement(isNot(contains('{'))));
      if (locale.languageCode != 'en') {
        final english = allMessages(lookupMfaLocalizations(const Locale('en')));
        expect(messages, isNot(english), reason: 'not an English copy');
      }
    });
  }

  test('placeholders and plurals render', () {
    final en = lookupMfaLocalizations(const Locale('en'));
    expect(en.otpCodeFieldHint(8), 'Enter the 8-digit code');
    expect(en.secondsRemaining(1), '1 second left');
    expect(en.secondsRemaining(30), '30 seconds left');
    final ar = lookupMfaLocalizations(const Locale('ar'));
    expect(ar.secondsRemaining(2), 'تبقّت ثانيتان');
    expect(ar.secondsRemaining(5), contains('5'));
    expect(
      lookupMfaLocalizations(const Locale('hi')).otpCodeFieldHint(6),
      contains('6'),
    );
  });

  test('an unsupported locale is rejected by lookup', () {
    expect(
      () => lookupMfaLocalizations(const Locale('xx')),
      throwsFlutterError,
    );
    expect(MfaLocalizations.delegate.isSupported(const Locale('hi')), isTrue);
    expect(MfaLocalizations.delegate.isSupported(const Locale('xx')), isFalse);
    expect(
      MfaLocalizations.delegate.shouldReload(MfaLocalizations.delegate),
      isFalse,
    );
  });

  Future<(String, TextDirection)> stringsIn(
    WidgetTester tester, {
    Locale? locale,
  }) async {
    late String label;
    late TextDirection direction;
    final probe = Builder(
      builder: (context) {
        label = mfaStrings(context).copyCode;
        direction = Directionality.of(context);
        return const SizedBox();
      },
    );
    await tester.pumpWidget(
      locale == null
          ? Directionality(textDirection: TextDirection.ltr, child: probe)
          : Localizations(
              locale: locale,
              delegates: const [
                MfaLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
              ],
              child: probe,
            ),
    );
    return (label, direction);
  }

  testWidgets('widgets fall back to English without the delegate', (
    tester,
  ) async {
    expect(await stringsIn(tester), ('Copy code', TextDirection.ltr));
  });

  testWidgets('the delegate provides Hindi, and Arabic right to left', (
    tester,
  ) async {
    expect(
      await stringsIn(tester, locale: const Locale('hi')),
      ('कोड कॉपी करें', TextDirection.ltr),
    );
    expect(
      await stringsIn(tester, locale: const Locale('ar')),
      ('نسخ الرمز', TextDirection.rtl),
    );
  });
}
