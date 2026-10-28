import 'dart:ui' show SemanticsAction;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mfa_ui/flutter_mfa_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/harness.dart';

void main() {
  late List<String> completed;
  late List<String> changed;

  setUp(() {
    completed = [];
    changed = [];
  });

  Widget field({
    int length = 6,
    TextEditingController? controller,
    String? errorText,
    bool obscure = false,
    bool autofocus = false,
    String? semanticLabel,
  }) => OtpCodeField(
    length: length,
    controller: controller,
    errorText: errorText,
    obscure: obscure,
    autofocus: autofocus,
    semanticLabel: semanticLabel,
    onCompleted: completed.add,
    onChanged: changed.add,
  );

  EditableText editable(WidgetTester tester) =>
      tester.widget<EditableText>(find.byType(EditableText));

  String boxText(WidgetTester tester, int i) => tester
      .widget<Text>(
        find.descendant(
          of: find.byKey(ValueKey('otp-box-$i')),
          matching: find.byType(Text),
        ),
      )
      .data!;

  testWidgets('is one text field for screen readers (FR-UI-01 AC1)', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(field()));
    // Checked field by field: the semantics matchers differ between the
    // supported Flutter versions.
    final node = tester.getSemantics(find.byType(EditableText));
    final data = node.getSemanticsData();
    expect(node.label, 'One-time code');
    expect(node.hint, 'Enter the 6-digit code');
    expect(node.flagsCollection.isTextField, isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    expect(data.hasAction(SemanticsAction.focus), isTrue);
    expect(data.textDirection, TextDirection.ltr);
    expect(find.byType(EditableText), findsOneWidget);
    for (var i = 0; i < 6; i++) {
      expect(
        find.ancestor(
          of: find.byKey(ValueKey('otp-box-$i')),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
        reason: 'the digit boxes are not separate fields',
      );
    }
    handle.dispose();
  });

  testWidgets('screen-reader tap and focus open the keyboard', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(field()));
    final node = tester.getSemantics(find.byType(EditableText));
    node.owner!.performAction(node.id, SemanticsAction.tap);
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
    tester.testTextInput.hide();
    node.owner!.performAction(node.id, SemanticsAction.focus);
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
    handle.dispose();
  });

  testWidgets('a custom label replaces the default', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(field(semanticLabel: 'Bank code')));
    expect(
      tester.getSemantics(find.byType(EditableText)).label,
      'Bank code',
    );
    handle.dispose();
  });

  testWidgets('accepts digits only, up to the length', (tester) async {
    await tester.pumpWidget(host(field(length: 8)));
    await tester.enterText(find.byType(EditableText), '12a3');
    expect(editable(tester).controller.text, '123');
    await tester.enterText(find.byType(EditableText), '1234567890');
    await tester.pump();
    expect(editable(tester).controller.text, '12345678');
    expect(boxText(tester, 0), '1');
    expect(boxText(tester, 7), '8');
  });

  testWidgets('pasting a formatted code fills every box (AC2)', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => switch (call.method) {
        'Clipboard.getData' => {'text': 'Your code: 123 456'},
        'Clipboard.hasStrings' => {'value': true},
        _ => null,
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(host(field()));
    await tester.tap(find.byType(OtpCodeField));
    await tester.pump();
    await tester
        .state<EditableTextState>(find.byType(EditableText))
        .pasteText(
          SelectionChangedCause.toolbar,
        );
    await tester.pump();
    expect(editable(tester).controller.text, '123456');
    expect(completed, ['123456']);
    expect([for (var i = 0; i < 6; i++) boxText(tester, i)].join(), '123456');
  });

  testWidgets(
    'asks for one-time-code autofill and a numeric keyboard (AC3, AC4)',
    (
      tester,
    ) async {
      await tester.pumpWidget(host(field()));
      final text = editable(tester);
      expect(text.autofillHints, [AutofillHints.oneTimeCode]);
      expect(text.keyboardType, TextInputType.number);
      expect(text.autocorrect, isFalse);
      expect(text.enableSuggestions, isFalse);
      expect(text.enableIMEPersonalizedLearning, isFalse);
    },
  );

  testWidgets('onCompleted fires once per completion (AC5)', (tester) async {
    await tester.pumpWidget(host(field()));
    await tester.enterText(find.byType(EditableText), '123456');
    await tester.enterText(find.byType(EditableText), '123456');
    expect(completed, ['123456']);
    await tester.enterText(find.byType(EditableText), '12345');
    await tester.enterText(find.byType(EditableText), '123457');
    expect(completed, ['123456', '123457']);
    expect(changed, ['123456', '12345', '123457']);
  });

  testWidgets('a programmatic full code completes too', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(field(controller: controller)));
    controller.text = '654321';
    await tester.pump();
    expect(completed, ['654321']);
    controller.selection = const TextSelection.collapsed(offset: 2);
    await tester.pump();
    expect(completed, ['654321'], reason: 'selection changes are ignored');
  });

  testWidgets('a controller that is already full does not complete again', (
    tester,
  ) async {
    final first = TextEditingController(text: '111111');
    final second = TextEditingController(text: '222222');
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await tester.pumpWidget(host(field(controller: first)));
    await tester.pumpWidget(host(field(controller: second)));
    expect(boxText(tester, 0), '2');
    first.text = '333333';
    await tester.pump();
    expect(completed, isEmpty, reason: 'the old controller is detached');
    await tester.pumpWidget(host(field()));
    await tester.enterText(find.byType(EditableText), '444444');
    expect(completed, ['444444']);
    await tester.pumpWidget(host(field(controller: second)));
    second.text = '55555';
    await tester.pump();
    expect(changed.last, '55555');
  });

  testWidgets('shows and announces an error (AC6)', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(field(errorText: 'That code is wrong')));
    expect(find.text('That code is wrong'), findsOneWidget);
    final errorNode = tester.getSemantics(find.text('That code is wrong'));
    expect(errorNode.label, 'That code is wrong');
    expect(errorNode.flagsCollection.isLiveRegion, isTrue);
    final box = tester.widget<Container>(
      find.byKey(const ValueKey('otp-box-0')),
    );
    final border = (box.decoration! as BoxDecoration).border! as Border;
    expect(border.top.color, MfaThemeData.light().error);
    handle.dispose();
  });

  testWidgets('obscure draws dots and hides the digits from assistive tech', (
    tester,
  ) async {
    await tester.pumpWidget(host(field(obscure: true)));
    await tester.enterText(find.byType(EditableText), '12');
    await tester.pump();
    expect(boxText(tester, 0), '•');
    expect(boxText(tester, 2), '');
    expect(editable(tester).obscureText, isTrue);
  });

  testWidgets('focus highlights the next box; autofocus works', (tester) async {
    await tester.pumpWidget(host(field(autofocus: true)));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
    Color borderOf(int i) =>
        ((tester
                            .widget<Container>(
                              find.byKey(ValueKey('otp-box-$i')),
                            )
                            .decoration!
                        as BoxDecoration)
                    .border!
                as Border)
            .top
            .color;
    final theme = MfaThemeData.light();
    expect(borderOf(0), theme.primary);
    await tester.enterText(find.byType(EditableText), '123456');
    await tester.pump();
    expect(borderOf(5), theme.primary, reason: 'last box when full');
    expect(borderOf(0), theme.outline);
  });

  testWidgets('tapping the boxes focuses the field and opens the keyboard', (
    tester,
  ) async {
    await tester.pumpWidget(host(field()));
    expect(tester.testTextInput.isVisible, isFalse);
    // The transparent field sits above the boxes, so tap at a box's position.
    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey('otp-box-3'))),
    );
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('long press offers Paste on platforms without a system menu', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => switch (call.method) {
        'Clipboard.getData' => {'text': '987654'},
        'Clipboard.hasStrings' => {'value': true},
        _ => null,
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(host(field()));
    await tester.longPress(find.byType(OtpCodeField));
    await tester.pumpAndSettle();
    expect(find.text('Paste'), findsOneWidget);
    final pasteRect = tester.getRect(find.text('Paste'));
    final fieldRect = tester.getRect(find.byType(OtpCodeField));
    expect(
      pasteRect.bottom,
      lessThanOrEqualTo(fieldRect.top),
      reason: 'above the field',
    );
    expect(
      tester
          .getSize(
            find
                .ancestor(
                  of: find.text('Paste'),
                  matching: find.byType(Container),
                )
                .first,
          )
          .height,
      48,
    );
    await tester.tap(find.text('Paste'));
    await tester.pumpAndSettle();
    expect(completed, ['987654']);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('no Paste item without clipboard text', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => switch (call.method) {
        'Clipboard.hasStrings' => {'value': false},
        _ => null,
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(host(field()));
    await tester.longPress(find.byType(OtpCodeField));
    await tester.pumpAndSettle();
    expect(find.text('Paste'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('uses the system menu where supported (iOS 16+)', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(
      host(
        field(),
        media: const MediaQueryData(supportsShowingSystemContextMenu: true),
      ),
    );
    final state = tester.state<EditableTextState>(find.byType(EditableText));
    final menu = state.widget.contextMenuBuilder!(
      tester.element(find.byType(EditableText)),
      state,
    );
    expect(menu, isA<SystemContextMenu>());
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('digits stay left to right in right-to-left locales', (
    tester,
  ) async {
    await tester.pumpWidget(host(field(), direction: TextDirection.rtl));
    expect(
      tester.getCenter(find.byKey(const ValueKey('otp-box-0'))).dx,
      lessThan(tester.getCenter(find.byKey(const ValueKey('otp-box-1'))).dx),
    );
    expect(editable(tester).textDirection, TextDirection.ltr);
  });

  test('length is limited to 6, 7 or 8', () {
    expect(
      () => OtpCodeField(length: 5, onCompleted: (_) {}),
      throwsAssertionError,
    );
    expect(
      () => OtpCodeField(length: 9, onCompleted: (_) {}),
      throwsAssertionError,
    );
  });
}
