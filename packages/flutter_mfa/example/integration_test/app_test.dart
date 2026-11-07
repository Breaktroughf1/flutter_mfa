import 'package:flutter/material.dart';
import 'package:flutter_mfa_example/main.dart';
import 'package:flutter_mfa_ui/flutter_mfa_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ'; // RFC 4226/6238 test secret

/// Pumps until [finder] matches (or, with `until: false`, stops matching)
/// or [timeout] passes; the vault opens
/// asynchronously (Keystore key creation can take seconds on emulators).
Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  bool until = true,
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty == until && DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Every visible text, to explain a failure (labels and error messages only;
/// the app never shows secrets).
String _screen(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).join(' | ');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // FR-EX-01 on the device's real vault (Keystore, Keychain or WebCrypto).
  // The test touches only the account it creates, so accounts already on
  // the device are never removed. The full enrol → code → backup → restore
  // journey is FR-EX-03 (M4-03).
  testWidgets('boots, adds an account, shows its code and removes it', (
    tester,
  ) async {
    final name = 'it-${DateTime.now().microsecondsSinceEpoch}';
    await tester.pumpWidget(const ExampleApp());
    await _pumpUntil(tester, find.text('Add account'));
    await tester.pumpAndSettle();
    expect(find.text(ExampleApp.title), findsOneWidget);
    expect(find.text('Add account'), findsOneWidget, reason: _screen(tester));

    await tester.tap(find.text('Add account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enter setup key'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Account name'),
      name,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Secret key (Base32)'),
      _secret,
    );
    await tester.tap(find.text('Add'));
    final tile = find.ancestor(
      of: find.text(name),
      matching: find.byType(OtpAccountTile),
    );
    await _pumpUntil(tester, tile);
    expect(tile, findsOneWidget, reason: _screen(tester));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      tile,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final code = find.descendant(
      of: tile,
      matching: find.textContaining(RegExp(r'^\d{3} \d{3}$')),
    );
    await _pumpUntil(tester, code);
    expect(code, findsOneWidget, reason: _screen(tester));

    // Remove it from its detail page.
    await tester.tap(find.text(name));
    await _pumpUntil(tester, find.byTooltip('Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await _pumpUntil(tester, find.text(name), until: false);
    expect(find.text(name), findsNothing, reason: _screen(tester));

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
