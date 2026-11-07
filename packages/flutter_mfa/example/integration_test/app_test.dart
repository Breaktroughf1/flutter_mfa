import 'package:flutter/material.dart';
import 'package:flutter_mfa/flutter_mfa.dart';
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
  // the device are never removed. The full journey is the next test.
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

  // FR-EX-03: enrol → code → encrypted backup → remove → restore → the code
  // continues where it left off. A counter-based account makes every code
  // deterministic (RFC 4226 test secret: counter 0 → 755224, 1 → 287082).
  testWidgets(
    'full journey: backup and restore keep the account and its counter',
    (
      tester,
    ) async {
      const passphrase = 'correct horse battery staple';
      const crypto = Duration(minutes: 3); // 600 000 PBKDF2 rounds, debug build
      final name = 'it-hotp-${DateTime.now().microsecondsSinceEpoch}';
      await tester.pumpWidget(const ExampleApp());
      await _pumpUntil(tester, find.text('Add account'));
      await tester.pumpAndSettle();

      Future<void> openAccount() async {
        final label = find.text(name);
        await _pumpUntil(tester, label);
        // Let the closing dialog's barrier go first, or it swallows the tap.
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          label,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(label);
        await _pumpUntil(tester, find.text('Generate code'));
        await tester.pumpAndSettle();
        expect(
          find.text('Generate code'),
          findsOneWidget,
          reason: _screen(tester),
        );
      }

      Future<void> openSettings() async {
        await tester.tap(find.byTooltip('Settings'));
        await _pumpUntil(tester, find.text('Export encrypted backup'));
        await tester.pumpAndSettle();
      }

      // 1. Enrol a counter-based account and use its first code.
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
      // The dialog scrolls on small screens (320x640 emulators): bring the
      // choice into view before tapping, and check it took.
      final counter = find.text('Counter-based');
      await tester.ensureVisible(counter);
      await tester.pumpAndSettle();
      await tester.tap(counter);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SegmentedButton<OtpType>>(
              find.byType(SegmentedButton<OtpType>),
            )
            .selected,
        {OtpType.hotp},
        reason: _screen(tester),
      );
      await tester.tap(find.text('Add'));
      await openAccount();
      await tester.tap(find.text('Generate code'));
      await _pumpUntil(tester, find.text('755 224'));
      expect(find.text('755 224'), findsOneWidget, reason: _screen(tester));
      await tester.pageBack();
      await tester.pumpAndSettle();

      // 2. Export an encrypted backup.
      await openSettings();
      await tester.ensureVisible(find.text('Export encrypted backup'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export encrypted backup'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Passphrase'),
        passphrase,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Repeat passphrase'),
        passphrase,
      );
      await tester.tap(find.text('Export'));
      await _pumpUntil(tester, find.byType(SelectableText), timeout: crypto);
      final armored = tester
          .widget<SelectableText>(find.byType(SelectableText))
          .data!;
      expect(armored, startsWith('-----BEGIN FLUTTER MFA BACKUP-----'));
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      // 3. Remove the account.
      Future<void> removeAccount() async {
        await openAccount();
        await tester.tap(find.byTooltip('Remove'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
        await _pumpUntil(tester, find.text(name), until: false);
        expect(find.text(name), findsNothing, reason: _screen(tester));
        await tester.pumpAndSettle();
      }

      await removeAccount();

      // 4. Restore it. "Keep" (the default) leaves any other accounts on the
      // device untouched; only the removed one comes back.
      await openSettings();
      await tester.ensureVisible(find.text('Restore from backup'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore from backup'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Backup text'),
        armored,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Passphrase'),
        passphrase,
      );
      await tester.tap(find.text('Restore'));
      await _pumpUntil(
        tester,
        find.textContaining('Restored'),
        timeout: crypto,
      );
      expect(
        find.textContaining('Restored'),
        findsOneWidget,
        reason: _screen(tester),
      );
      await tester.pageBack();
      await tester.pumpAndSettle();

      // 5. The restored account continues from counter 1.
      await openAccount();
      await tester.tap(find.text('Generate code'));
      await _pumpUntil(tester, find.text('287 082'));
      expect(find.text('287 082'), findsOneWidget, reason: _screen(tester));
      await tester.pageBack();
      await tester.pumpAndSettle();

      // 6. Clean up.
      await removeAccount();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
