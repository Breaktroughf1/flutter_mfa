import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:flutter_mfa_ui/flutter_mfa_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';
import '../../support/harness.dart';

void main() {
  testWidgets('follows the account stream (FR-UI-04 AC1)', (tester) async {
    final accounts = StreamController<List<OtpAccount>>();
    addTearDown(accounts.close);
    final tapped = <String>[];
    final copied = <String>[];
    await tester.pumpWidget(
      host(
        SizedBox(
          height: 400,
          child: OtpAccountList(
            accounts: accounts.stream,
            codeStream: (a) =>
                a.type == OtpType.totp ? Stream.value(code) : null,
            onTap: (a) => tapped.add(a.id),
            onCopy: (a) => copied.add(a.id),
          ),
        ),
      ),
    );
    expect(find.byType(OtpAccountTile), findsNothing, reason: 'loading');
    accounts.add([]);
    await tester.pumpAndSettle();
    expect(find.text('No accounts yet'), findsOneWidget);
    accounts.add([
      account(),
      account(id: 'b', issuer: 'Bank', name: 'bob', type: OtpType.hotp),
    ]);
    await tester.pumpAndSettle();
    expect(find.byType(OtpAccountTile), findsNWidgets(2));
    expect(find.text('Tap to generate a code'), findsOneWidget);
    await tester.tap(find.text('Bank'));
    await tester.tap(find.text('287 082'));
    await tester.pump();
    expect(tapped, ['b']);
    expect(copied, ['a']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a new account list keeps each tile on its stream', (
    tester,
  ) async {
    final accounts = StreamController<List<OtpAccount>>();
    addTearDown(accounts.close);
    var created = 0;
    await tester.pumpWidget(
      host(
        SizedBox(
          height: 400,
          child: OtpAccountList(
            accounts: accounts.stream,
            codeStream: (_) {
              created++;
              return Stream.value(code);
            },
          ),
        ),
      ),
    );
    accounts.add([account()]);
    await tester.pumpAndSettle();
    accounts.add([account(), account(id: 'b', name: 'bob')]);
    await tester.pumpAndSettle();
    expect(created, 2, reason: 'one stream per account, not per rebuild');
    expect(find.text('287 082'), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('custom empty and error states', (tester) async {
    await tester.pumpWidget(
      host(
        OtpAccountList(
          accounts: Stream.value(const []),
          codeStream: (_) => null,
          emptyBuilder: (_) => const Text('Add your first account'),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Add your first account'), findsOneWidget);

    await tester.pumpWidget(
      host(
        OtpAccountList(
          accounts: Stream.error(const VaultCorrupted()),
          codeStream: (_) => null,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Code unavailable'), findsOneWidget);

    await tester.pumpWidget(
      host(
        OtpAccountList(
          accounts: Stream.error(const VaultCorrupted()),
          codeStream: (_) => null,
          errorBuilder: (_) => const Text('Vault problem'),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Vault problem'), findsOneWidget);
  });

  testWidgets('without callbacks the tiles are read-only', (tester) async {
    await tester.pumpWidget(
      host(
        SizedBox(
          height: 400,
          child: OtpAccountList(
            accounts: Stream.value([account()]),
            codeStream: (_) => Stream.value(code),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final tile = tester.widget<OtpAccountTile>(find.byType(OtpAccountTile));
    expect(tile.onTap, isNull);
    expect(tile.onCopy, isNull);
  });
}
