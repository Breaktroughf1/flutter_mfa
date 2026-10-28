import 'package:flutter/widgets.dart';
import 'package:flutter_mfa_ui/flutter_mfa_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../goldens/gallery.dart';

/// Flutter's automated accessibility guidelines over every widget, in both
/// default themes (FR-UI-08 AC1). The manual TalkBack/VoiceOver pass is
/// recorded in docs/a11y-report.md (AC2).
void main() {
  for (final theme in [MfaThemeData.light(), MfaThemeData.dark()]) {
    testWidgets('${theme.brightness.name}: tap targets, labels and contrast', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      tester.view
        ..physicalSize = const Size(420, 1500)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final filled = TextEditingController(text: '1234');
      addTearDown(filled.dispose);
      await tester.pumpWidget(gallery(theme: theme, filled: filled));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  }
}
