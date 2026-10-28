import 'package:flutter/material.dart';
import 'package:flutter_mfa_example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ'; // RFC 4226/6238 test secret

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
    await tester.pumpAndSettle();
    expect(find.text(ExampleApp.title), findsOneWidget);

    await tester.tap(find.text('Add account'));
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
    await tester.pumpAndSettle();

    final tile = find.widgetWithText(ListTile, name);
    await tester.scrollUntilVisible(tile, 200);
    expect(
      find.descendant(
        of: tile,
        matching: find.textContaining(RegExp(r'^\d{3} \d{3}$')),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(of: tile, matching: find.byTooltip('Remove')),
    );
    await tester.pumpAndSettle();
    expect(find.text(name), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
