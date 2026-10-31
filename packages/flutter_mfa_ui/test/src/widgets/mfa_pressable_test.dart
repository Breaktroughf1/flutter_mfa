import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mfa_ui/flutter_mfa_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';
import '../../support/harness.dart';

/// [host] with the keyboard shortcuts and actions every `WidgetsApp`
/// provides (Tab traversal).
Widget _app(Widget child) => Shortcuts(
  shortcuts: WidgetsApp.defaultShortcuts,
  child: Actions(
    actions: WidgetsApp.defaultActions,
    // As a Navigator does: key events start inside the app.
    child: FocusScope(autofocus: true, child: host(child)),
  ),
);

void main() {
  testWidgets(
    'is reached with Tab and pressed with Enter or Space (FR-UI-08)',
    (
      tester,
    ) async {
      var pressed = 0;
      await tester.pumpWidget(
        _app(
          MfaPressable(
            onPressed: () => pressed++,
            child: const SizedBox.square(dimension: 48),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(pressed, 2);

      await tester.tap(find.byType(MfaPressable));
      expect(pressed, 3);
    },
  );

  testWidgets('shows a focus outline only while focused by keyboard', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        MfaPressable(
          onPressed: () {},
          child: const SizedBox.square(dimension: 48),
        ),
      ),
    );
    BoxDecoration decoration() =>
        tester
                .widget<DecoratedBox>(
                  find.descendant(
                    of: find.byType(MfaPressable),
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .decoration
            as BoxDecoration;
    expect(decoration().border, isNull);
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(decoration().border, isNotNull);
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  testWidgets('a null onPressed is not focusable', (tester) async {
    await tester.pumpWidget(
      _app(
        const MfaPressable(
          onPressed: null,
          child: SizedBox.square(dimension: 48),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus?.context?.widget,
      isNot(isA<FocusableActionDetector>()),
    );
  });

  testWidgets('tiles, codes and the copy button are keyboard reachable', (
    tester,
  ) async {
    var tapped = 0;
    var copied = 0;
    await tester.pumpWidget(
      _app(
        OtpAccountTile(
          account: account(),
          codeStream: Stream.value(code),
          onTap: () => tapped++,
          onCopy: () => copied++,
        ),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(tapped, 1);
    expect(copied, 1);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('the code field is announced as enabled', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(OtpCodeField(onCompleted: (_) {})));
    final node = tester
        .getSemantics(find.bySemanticsLabel('One-time code'))
        .getSemanticsData();
    // A bool on Flutter 3.35 and a Tristate on 3.47: accept either "true".
    expect([
      'true',
      'Tristate.isTrue',
    ], contains('${node.flagsCollection.isEnabled}'));
    semantics.dispose();
  });
}
