import 'package:flutter/material.dart';
import 'package:flutter_mfa/flutter_mfa.dart';
import 'package:flutter_mfa_core/testing.dart';
import 'package:flutter_mfa_example/main.dart';
import 'package:flutter_mfa_platform_interface/flutter_mfa_platform_interface.dart';
import 'package:flutter_mfa_platform_interface/testing.dart';
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

  testWidgets('a manually added TOTP account shows its current code', (
    tester,
  ) async {
    await boot(tester);
    await addAccount(tester, secret: _secret);
    expect(find.text('Example · alice'), findsOneWidget);
    expect(find.text('287 082'), findsOneWidget, reason: 'RFC 6238 at T=59');

    clock.advance(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('287 082'), findsNothing, reason: 'refreshed next step');
    await unmount(tester);
  });

  testWidgets('a counter-based account generates the next code on tap', (
    tester,
  ) async {
    await boot(tester);
    await addAccount(tester, secret: _secret, counter: true);
    expect(find.text('Tap to generate a code'), findsOneWidget);
    await tester.tap(find.text('Example · alice'));
    await tester.pumpAndSettle();
    expect(find.text('755 224'), findsOneWidget, reason: 'RFC 4226 counter 0');
    await tester.tap(find.text('Example · alice'));
    await tester.pumpAndSettle();
    expect(find.text('287 082'), findsOneWidget, reason: 'RFC 4226 counter 1');
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

  testWidgets('removing an account deletes it from the vault', (tester) async {
    await boot(tester);
    await addAccount(tester, secret: _secret);
    await tester.tap(find.byTooltip('Remove'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No accounts yet'), findsOneWidget);
    expect(await vault.keys(), ['__index_v1__']);
    await unmount(tester);
  });

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
