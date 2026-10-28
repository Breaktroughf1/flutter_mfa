import 'package:flutter/widgets.dart';
import 'package:flutter_mfa_ui/flutter_mfa_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/harness.dart';

void main() {
  Color colourOf(WidgetTester tester, String seconds) =>
      tester.widget<Text>(find.text(seconds)).style!.color!;

  testWidgets('shows and announces the seconds left, rounded up', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        const OtpCountdownRing(
          progress: 0.6,
          remaining: Duration(milliseconds: 11200),
        ),
      ),
    );
    expect(find.text('12'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(OtpCountdownRing)).label,
      '12 seconds left',
    );
    expect(colourOf(tester, '12'), MfaThemeData.light().primary);
    handle.dispose();
  });

  testWidgets('turns to the warning colour in the last five seconds', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const OtpCountdownRing(progress: 0.9, remaining: Duration(seconds: 5)),
      ),
    );
    expect(colourOf(tester, '5'), MfaThemeData.light().warning);
  });

  testWidgets('grows with the text size', (tester) async {
    Future<Size> sizeAt(double scale) async {
      await tester.pumpWidget(
        host(
          const OtpCountdownRing(progress: 0, remaining: Duration(seconds: 30)),
          media: MediaQueryData(textScaler: TextScaler.linear(scale)),
        ),
      );
      return tester.getSize(find.byType(OtpCountdownRing));
    }

    expect(await sizeAt(1), const Size(40, 40));
    expect(await sizeAt(2), const Size(80, 80));
  });

  testWidgets('repaints only when something changed', (tester) async {
    Future<CustomPainter> painterFor(
      double progress,
      Duration remaining,
    ) async {
      await tester.pumpWidget(
        host(OtpCountdownRing(progress: progress, remaining: remaining)),
      );
      return tester
          .widget<CustomPaint>(
            find.descendant(
              of: find.byType(OtpCountdownRing),
              matching: find.byType(CustomPaint),
            ),
          )
          .painter!;
    }

    final a = await painterFor(0.5, const Duration(seconds: 15));
    final same = await painterFor(0.5, const Duration(seconds: 15));
    final later = await painterFor(0.6, const Duration(seconds: 12));
    final warning = await painterFor(0.6, const Duration(seconds: 3));
    expect(same.shouldRepaint(a), isFalse);
    expect(later.shouldRepaint(a), isTrue);
    expect(warning.shouldRepaint(later), isTrue);
    await tester.pumpWidget(
      host(
        const OtpCountdownRing(progress: 0.6, remaining: Duration(seconds: 3)),
        theme: MfaThemeData.light().copyWith(outline: const Color(0xFF000000)),
      ),
    );
    final track = tester
        .widget<CustomPaint>(
          find.descendant(
            of: find.byType(OtpCountdownRing),
            matching: find.byType(CustomPaint),
          ),
        )
        .painter!;
    expect(track.shouldRepaint(warning), isTrue);
  });
}
