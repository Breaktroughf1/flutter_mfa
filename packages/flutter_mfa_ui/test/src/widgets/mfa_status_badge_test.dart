import 'package:flutter/widgets.dart';
import 'package:flutter_mfa_ui/flutter_mfa_ui.dart';
import 'package:flutter_mfa_ui/src/widgets/status_glyph.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/harness.dart';

void main() {
  final theme = MfaThemeData.light();
  final expected = {
    MfaStatus.enrolled: ('Enrolled', StatusGlyph.check, theme.success),
    MfaStatus.notEnrolled: (
      'Not enrolled',
      StatusGlyph.circle,
      theme.onSurfaceVariant,
    ),
    MfaStatus.locked: ('Locked', StatusGlyph.lock, theme.error),
    MfaStatus.keyInvalidated: (
      'Needs re-enrolment',
      StatusGlyph.warning,
      theme.warning,
    ),
    MfaStatus.integrityWarning: (
      'Device check warning',
      StatusGlyph.shield,
      theme.warning,
    ),
  };

  for (final MapEntry(key: status, value: (label, glyph, colour))
      in expected.entries) {
    testWidgets('${status.name}: icon and text, not colour alone (FR-UI-03)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(MfaStatusBadge(status: status)));
      expect(find.text(label), findsOneWidget);
      final icon = tester.widget<StatusGlyphIcon>(find.byType(StatusGlyphIcon));
      expect(icon.glyph, glyph);
      expect(icon.color, colour);
      expect(tester.widget<Text>(find.text(label)).style!.color, colour);
      expect(tester.getSemantics(find.byType(MfaStatusBadge)).label, label);
      handle.dispose();
    });
  }

  testWidgets('every glyph paints and repaints only on change', (tester) async {
    for (final glyph in StatusGlyph.values) {
      await tester.pumpWidget(
        host(StatusGlyphIcon(glyph, color: const Color(0xFF000000))),
      );
      expect(tester.takeException(), isNull);
    }
    CustomPainter painter() => tester
        .widget<CustomPaint>(
          find.descendant(
            of: find.byType(StatusGlyphIcon),
            matching: find.byType(CustomPaint),
          ),
        )
        .painter!;
    final eyeOff = painter();
    await tester.pumpWidget(
      host(const StatusGlyphIcon(StatusGlyph.eyeOff, color: Color(0xFF000000))),
    );
    expect(painter().shouldRepaint(eyeOff), isFalse);
    await tester.pumpWidget(
      host(const StatusGlyphIcon(StatusGlyph.eyeOff, color: Color(0xFFFFFFFF))),
    );
    expect(painter().shouldRepaint(eyeOff), isTrue);
    await tester.pumpWidget(
      host(const StatusGlyphIcon(StatusGlyph.eye, color: Color(0xFF000000))),
    );
    expect(painter().shouldRepaint(eyeOff), isTrue);
  });
}
