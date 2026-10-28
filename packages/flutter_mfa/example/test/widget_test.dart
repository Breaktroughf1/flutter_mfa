import 'package:flutter/material.dart';
import 'package:flutter_mfa/flutter_mfa.dart';
import 'package:flutter_mfa_core/testing.dart';
import 'package:flutter_mfa_example/main.dart';
import 'package:flutter_mfa_platform_interface/flutter_mfa_platform_interface.dart';
import 'package:flutter_mfa_platform_interface/testing.dart';
import 'package:flutter_mfa_ui/flutter_mfa_ui.dart';
import 'package:flutter_test/flutter_test.dart';

const _secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ'; // RFC 4226/6238 test secret

void main() {
  late InMemoryMfaPlatform vault;
  late FakeClock clock;

  setUp(() {
    vault = InMemoryMfaPlatform();
    MfaPlatform.instance = vault;
    clock = FakeClock(DateTime.fromMillisecondsSinceEpoch(59000, isUtc: true));
  });

  Future<void> boot(WidgetTester tester) async {
    await tester.pumpWidget(
      ExampleApp(
        createClient: () =>
            MfaClient.create(options: MfaClientOptions(clock: clock)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> addAccount(
    WidgetTester tester, {
    required String secret,
    String name = 'alice',
    bool counter = false,
  }) async {
    await tester.tap(find.text('Add account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enter setup key'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Issuer (optional)'),
      'Example',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Account name'),
      name,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Secret key (Base32)'),
      secret,
    );
    if (counter) await tester.tap(find.text('Counter-based'));
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
  }

  /// Unmounts the app so its timers stop.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  testWidgets('boots with an empty list', (tester) async {
    await boot(tester);
    expect(find.text(ExampleApp.title), findsOneWidget);
    expect(find.textContaining('No accounts yet'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('accounts are added by scanning or by typing the setup key', (
    tester,
  ) async {
    await boot(tester);
    await tester.tap(find.text('Add account'));
    await tester.pumpAndSettle();
    expect(find.text('Scan QR code'), findsOneWidget);
    expect(find.text('Enter setup key'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets(
    'a time-based account shows a live code that copies sensitively',
    (
      tester,
    ) async {
      await boot(tester);
      await addAccount(tester, secret: _secret);
      expect(find.text('Example'), findsOneWidget);
      expect(find.text('alice'), findsOneWidget);
      expect(find.text('287 082'), findsOneWidget, reason: 'RFC 6238 at T=59');

      await tester.tap(find.text('287 082'));
      await tester.pumpAndSettle();
      expect(vault.clipboard?.$1, '287082');
      expect(find.textContaining('cleared from the clipboard'), findsOneWidget);

      clock.advance(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('287 082'), findsNothing, reason: 'next step at T=60');
      await unmount(tester);
    },
  );

  testWidgets(
    'a counter-based account generates codes on its detail page only',
    (tester) async {
      await boot(tester);
      await addAccount(tester, secret: _secret, counter: true);
      expect(find.text('Tap to generate a code'), findsOneWidget);
      await tester.tap(find.text('Example'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate code'));
      await tester.pumpAndSettle();
      expect(find.text('755 224'), findsOneWidget, reason: 'counter 0');
      await tester.tap(find.text('755 224'));
      await tester.pumpAndSettle();
      expect(vault.clipboard?.$1, '755224', reason: 'copies the shown code');
      await tester.tap(find.text('Generate code'));
      await tester.pumpAndSettle();
      expect(find.text('287 082'), findsOneWidget, reason: 'counter 1');
      await unmount(tester);
    },
  );

  testWidgets('the detail page renames and removes an account', (
    tester,
  ) async {
    await boot(tester);
    await addAccount(tester, secret: _secret);
    await tester.tap(find.text('Example'));
    await tester.pumpAndSettle();
    expect(find.byType(OtpCountdownRing), findsOneWidget);

    await tester.tap(find.byTooltip('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Account name'),
      'bob',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('bob'), findsOneWidget);
    expect((await MfaClient.create()).accounts(), completion(hasLength(1)));

    await tester.tap(find.byTooltip('Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No accounts yet'), findsOneWidget);
    expect(await vault.keys(), ['__index_v1__']);
    await unmount(tester);
  });

  testWidgets('an invalid secret is reported and nothing is stored', (
    tester,
  ) async {
    await boot(tester);
    await addAccount(tester, secret: 'not base32!');
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('Invalid'), findsOneWidget);
    expect(await vault.keys(), isEmpty);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No accounts yet'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets(
    'relying-party demo: generate, show the QR, confirm the first code '
    '(FR-FAC-07)',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await boot(tester);
      await tester.tap(find.byTooltip('Relying-party demo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate secret'));
      await tester.pumpAndSettle();
      expect(find.byType(EnrollmentQrView), findsOneWidget);

      // The setup key the user would type, shown in groups of four.
      final shown = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .firstWhere(
            (t) => RegExp(r'^[A-Z2-7]{4}( [A-Z2-7]{1,4})+$').hasMatch(t),
          );
      final key = shown.replaceAll(' ', '');
      final right = Totp(OtpSecret.fromBase32(key)).generate(DateTime.now());
      final wrong = right.replaceRange(
        5,
        6,
        '${(int.parse(right[5]) + 1) % 10}',
      );
      // The demo page's list, not the accounts list on the route below it
      // or a text field's own scrollable.
      final pageScroll = find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first;
      final field = find.descendant(
        of: find.byType(OtpCodeField),
        matching: find.byType(EditableText),
      );

      await tester.scrollUntilVisible(
        find.byType(OtpCodeField),
        200,
        scrollable: pageScroll,
      );
      await tester.enterText(field, wrong);
      await tester.pumpAndSettle();
      expect(find.textContaining('not right'), findsOneWidget);

      await tester.enterText(field, right);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(MfaStatusBadge),
        200,
        scrollable: pageScroll,
      );
      expect(find.textContaining('Code confirmed'), findsOneWidget);
      expect(find.byType(MfaStatusBadge), findsOneWidget);

      await tester.drag(pageScroll, const Offset(0, 2000)); // back to the top
      await tester.pumpAndSettle();
      final copyKey = find.bySemanticsLabel('Copy setup key');
      await tester.ensureVisible(copyKey);
      await tester.pumpAndSettle();
      await tester.tap(copyKey);
      await tester.pumpAndSettle();
      // Compared without printing the key on failure.
      expect(vault.clipboard?.$1 == key, isTrue, reason: 'setup key copied');

      await tester.ensureVisible(find.text('Or add it to this app'));
      await tester.tap(find.text('Or add it to this app'));
      await tester.pumpAndSettle();
      final accounts = await (await MfaClient.create()).accounts();
      expect(accounts.single.issuer, 'Breaktrough Demo');
      await unmount(tester);
      semantics.dispose();
    },
  );

  testWidgets('an unavailable vault is explained instead of crashing', (
    tester,
  ) async {
    vault.failNext(
      VaultOperation.capabilities,
      const VaultUnavailable(VaultUnavailableReason.insecureContext),
    );
    await boot(tester);
    expect(find.textContaining('HTTPS'), findsOneWidget);
    expect(find.text('Add account'), findsNothing);
    await unmount(tester);
  });
}
