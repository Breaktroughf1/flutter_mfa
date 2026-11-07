import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:flutter_mfa_ui/flutter_mfa_ui.dart';
import 'package:flutter_mfa_ui/src/widgets/status_glyph.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';
import '../../support/harness.dart';

void main() {
  testWidgets('shows issuer, account, ring and code (FR-UI-04)', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        OtpAccountTile(account: account(), codeStream: Stream.value(code)),
      ),
    );
    await tester.pump();
    expect(find.text('Example'), findsOneWidget);
    expect(find.text('alice'), findsOneWidget);
    expect(find.text('287 082'), findsOneWidget);
    expect(find.byType(OtpCountdownRing), findsOneWidget);
    expect(tester.getSemantics(find.text('Example')).label, 'Example, alice');
    handle.dispose();
  });

  testWidgets('without an issuer the account name is the title', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        OtpAccountTile(
          account: account(issuer: null),
          codeStream: const Stream.empty(),
        ),
      ),
    );
    expect(find.text('alice'), findsOneWidget);
    expect(find.byType(OtpCodeDisplay), findsNothing, reason: 'no code yet');
  });

  testWidgets('HOTP without a code asks to tap; tap and copy are wired', (
    tester,
  ) async {
    var taps = 0;
    var copies = 0;
    final controller = StreamController<OtpCode>();
    addTearDown(controller.close);
    Widget tile(Stream<OtpCode>? stream) => host(
      OtpAccountTile(
        account: account(type: OtpType.hotp),
        codeStream: stream,
        onTap: () => taps++,
        onCopy: () => copies++,
      ),
    );
    await tester.pumpWidget(tile(null));
    expect(find.text('Tap to generate a code'), findsOneWidget);
    expect(
      tester.widget<StatusGlyphIcon>(find.byType(StatusGlyphIcon)).glyph,
      StatusGlyph.counter,
    );
    await tester.tap(find.text('Example'));
    expect(taps, 1);

    await tester.pumpWidget(tile(controller.stream));
    controller.add(code);
    await tester.pumpAndSettle();
    expect(
      find.byType(OtpCountdownRing),
      findsNothing,
      reason: 'HOTP has no ring',
    );
    await tester.tap(find.text('287 082'));
    await tester.pump();
    expect(copies, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a TOTP account without a stream shows no code', (tester) async {
    await tester.pumpWidget(
      host(OtpAccountTile(account: account(), codeStream: null)),
    );
    expect(find.text('Tap to generate a code'), findsNothing);
  });

  testWidgets('stream errors show "Code unavailable", never the error', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        OtpAccountTile(
          account: account(),
          codeStream: Stream.error(
            const VaultUnavailable(
              VaultUnavailableReason.deviceLocked,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Code unavailable'), findsOneWidget);
    expect(find.textContaining('Vault'), findsNothing);
  });

  testWidgets('the name area is a full-height tap target', (tester) async {
    await tester.pumpWidget(
      host(
        OtpAccountTile(account: account(), codeStream: null, onTap: () {}),
      ),
    );
    final target = find.ancestor(
      of: find.text('Example'),
      matching: find.byType(GestureDetector),
    );
    expect(tester.getSize(target.first).height, greaterThanOrEqualTo(48));
  });
}
