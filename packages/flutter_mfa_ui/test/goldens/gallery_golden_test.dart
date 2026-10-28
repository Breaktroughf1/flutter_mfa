@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_mfa_ui/flutter_mfa_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/gallery.dart';
import 'golden_fonts.dart';

/// Golden images of every widget (FR-UI-08, M2-07): light, dark, Arabic
/// (right to left), Hindi and 200% text. Valid only on the pinned Linux
/// image; regenerate with `melos run goldens:update` for intended changes.
void main() {
  setUpAll(loadGoldenFonts);

  Future<void> golden(
    WidgetTester tester,
    String name, {
    required MfaThemeData theme,
    Locale locale = const Locale('en'),
    double textScale = 1,
    double height = 1500,
  }) async {
    tester.view
      ..physicalSize = Size(420, height)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final filled = TextEditingController(text: '1234');
    addTearDown(filled.dispose);
    await tester.pumpWidget(
      gallery(
        theme: theme,
        locale: locale,
        textScale: textScale,
        filled: filled,
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MfaTheme),
      matchesGoldenFile('images/$name.png'),
    );
  }

  testWidgets(
    'light',
    (tester) => golden(tester, 'gallery_light', theme: MfaThemeData.light()),
  );

  testWidgets(
    'dark',
    (tester) => golden(tester, 'gallery_dark', theme: MfaThemeData.dark()),
  );

  testWidgets(
    'Arabic, right to left (FR-UI-07 AC2)',
    (tester) => golden(
      tester,
      'gallery_ar_rtl',
      theme: MfaThemeData.light(),
      locale: const Locale('ar'),
    ),
  );

  testWidgets(
    'Hindi',
    (tester) => golden(
      tester,
      'gallery_hi',
      theme: MfaThemeData.light(),
      locale: const Locale('hi'),
    ),
  );

  testWidgets(
    '200% text',
    (tester) => golden(
      tester,
      'gallery_large_text',
      theme: MfaThemeData.light(),
      textScale: 2,
      height: 2600,
    ),
  );
}
