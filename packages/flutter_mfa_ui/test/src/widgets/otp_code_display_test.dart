import 'dart:ui' show SemanticsAction;

import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/widgets.dart';
import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:flutter_mfa_ui/flutter_mfa_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/harness.dart';

OtpCode code(String value) => OtpCode(
  value: value,
  remaining: const Duration(seconds: 12),
  progress: 0.6,
  step: 1,
);

void main() {
  testWidgets('groups the digits for reading (FR-UI-02 AC1)', (tester) async {
    await tester.pumpWidget(host(OtpCodeDisplay(code: code('123456'))));
    expect(find.text('123 456'), findsOneWidget);
    await tester.pumpWidget(host(OtpCodeDisplay(code: code('12345678'))));
    expect(find.text('1234 5678'), findsOneWidget);
  });

  testWidgets('screen readers hear the digits one by one', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(OtpCodeDisplay(code: code('123456'))));
    final node = tester.getSemantics(find.text('123 456'));
    expect(node.label, 'Code 1 2 3 4 5 6');
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    handle.dispose();
  });

  testWidgets('tap copies and confirms (AC2)', (tester) async {
    final handle = tester.ensureSemantics();
    var copies = 0;
    await tester.pumpWidget(
      host(OtpCodeDisplay(code: code('123456'), onCopy: () => copies++)),
    );
    final node = tester.getSemantics(find.text('123 456'));
    expect(node.flagsCollection.isButton, isTrue);
    expect(
      node.getSemanticsData().customSemanticsActionIds,
      contains(
        CustomSemanticsAction.getIdentifier(
          const CustomSemanticsAction.overridingAction(
            hint: 'Copy code',
            action: SemanticsAction.tap,
          ),
        ),
      ),
    );
    await tester.tap(find.text('123 456'));
    await tester.pump();
    expect(copies, 1);
    expect(find.text('Code copied'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.text('Code copied'))
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );
    await tester.tap(find.text('123 456'));
    await tester.pump(OtpCodeDisplay.confirmationDuration);
    expect(copies, 2);
    expect(find.text('Code copied'), findsNothing);
    node.owner!.performAction(node.id, SemanticsAction.tap);
    await tester.pump();
    expect(copies, 3, reason: 'screen readers can copy too');
    await tester.pumpWidget(const SizedBox());
    handle.dispose();
  });

  testWidgets('the copy target is at least the minimum tap size', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(OtpCodeDisplay(code: code('123456'), onCopy: () {})),
    );
    final size = tester.getSize(find.byType(GestureDetector));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(size.width, greaterThanOrEqualTo(48));
  });

  testWidgets('hidden shows dots, hides the code from screen readers and '
      'disables copy (AC3)', (tester) async {
    final handle = tester.ensureSemantics();
    var copies = 0;
    await tester.pumpWidget(
      host(
        OtpCodeDisplay(
          code: code('123456'),
          hidden: true,
          onCopy: () => copies++,
        ),
      ),
    );
    expect(find.text('••• •••'), findsOneWidget);
    expect(find.textContaining('1'), findsNothing);
    expect(tester.getSemantics(find.text('••• •••')).label, 'Code hidden');
    await tester.tap(find.text('••• •••'));
    expect(copies, 0);
    handle.dispose();
  });

  testWidgets('stays left to right in right-to-left locales', (tester) async {
    await tester.pumpWidget(
      host(OtpCodeDisplay(code: code('123456')), direction: TextDirection.rtl),
    );
    expect(
      tester.widget<Text>(find.text('123 456')).textDirection,
      TextDirection.ltr,
    );
  });
}
