import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:flutter_mfa_ui/flutter_mfa_ui.dart';

import 'fixtures.dart';

/// [theme] with the golden fonts on every text style. Without the fonts
/// loaded (see test/goldens/golden_fonts.dart), Flutter's test font is used.
MfaThemeData withGoldenFonts(MfaThemeData theme) {
  TextStyle f(TextStyle s) => s.copyWith(
    fontFamily: 'Roboto',
    fontFamilyFallback: const ['NotoSansArabic', 'NotoSansDevanagari'],
  );
  return theme.copyWith(
    codeTextStyle: f(theme.codeTextStyle),
    titleTextStyle: f(theme.titleTextStyle),
    bodyTextStyle: f(theme.bodyTextStyle),
    labelTextStyle: f(theme.labelTextStyle),
  );
}

final enrolmentUri = OtpAuthUri.parse(
  'otpauth://totp/Example:alice@example.com?secret=GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ&issuer=Example',
);

/// Every flutter_mfa_ui widget in its main states, as an app would host it.
Widget gallery({
  required MfaThemeData theme,
  Locale locale = const Locale('en'),
  double textScale = 1,
  TextEditingController? filled,
}) {
  final t = withGoldenFonts(theme);
  Widget section(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    child: child,
  );
  return MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: Localizations(
      locale: locale,
      delegates: const [
        MfaLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      child: MfaTheme(
        data: t,
        child: DefaultTextStyle(
          style: t.bodyTextStyle,
          child: ColoredBox(
            color: t.surface,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                section(OtpCodeField(onCompleted: (_) {})),
                section(OtpCodeField(onCompleted: (_) {}, controller: filled)),
                section(
                  OtpCodeField(
                    onCompleted: (_) {},
                    errorText: 'That code is wrong. Try again.',
                  ),
                ),
                section(
                  Wrap(
                    alignment: WrapAlignment.spaceEvenly,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      OtpCodeDisplay(code: code, onCopy: () {}),
                      const OtpCountdownRing(
                        progress: 0.6,
                        remaining: Duration(seconds: 12),
                      ),
                      const OtpCountdownRing(
                        progress: 0.9,
                        remaining: Duration(seconds: 3),
                      ),
                    ],
                  ),
                ),
                section(const OtpCodeDisplay(code: code, hidden: true)),
                section(
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final status in MfaStatus.values)
                        MfaStatusBadge(status: status),
                    ],
                  ),
                ),
                OtpAccountTile(
                  account: account(),
                  codeStream: Stream.value(code),
                  onCopy: () {},
                ),
                OtpAccountTile(
                  account: account(
                    id: 'b',
                    issuer: 'Bank',
                    name: 'bob',
                    type: OtpType.hotp,
                  ),
                  codeStream: null,
                ),
                section(
                  EnrollmentQrView(uri: enrolmentUri, onCopySecret: (_) {}),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
