import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:flutter_mfa_ui/flutter_mfa_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';
import '../../support/harness.dart';

/// Inside a list item, as apps use them: parts without their own node are
/// merged into the item, so a screen reader cannot reach them separately.
Widget _inList(List<Widget> children) => SizedBox(
  width: 400,
  height: 800,
  child: ListView(children: children),
);

/// The node whose label is exactly [label].
SemanticsData _node(WidgetTester tester, String label) =>
    tester.getSemantics(find.bySemanticsLabel(label)).getSemanticsData();

void main() {
  final uri = OtpAuthUri(
    type: OtpType.totp,
    secret: OtpSecret.fromBase32('JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP'),
    issuer: 'Example',
    accountName: 'alice',
  );

  testWidgets(
    'the enrolment QR code and its copy button are separate nodes (FR-UI-08)',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        host(_inList([EnrollmentQrView(uri: uri, onCopySecret: (_) {})])),
      );
      _node(tester, 'QR code to add this account to an authenticator app');
      final copy = _node(tester, 'Copy setup key');
      expect(copy.flagsCollection.isButton, isTrue);
      expect(copy.hasAction(SemanticsAction.tap), isTrue);
      semantics.dispose();
    },
  );

  testWidgets('a tile keeps its name, countdown and code apart', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        _inList([
          OtpAccountTile(
            account: account(),
            codeStream: Stream.value(code),
            onTap: () {},
            onCopy: () {},
          ),
        ]),
      ),
    );
    await tester.pump();
    final names = _node(tester, 'Example, alice');
    expect(names.hasAction(SemanticsAction.tap), isTrue);
    _node(tester, '12 seconds left');
    final display = _node(tester, 'Code 2 8 7 0 8 2');
    expect(display.hasAction(SemanticsAction.tap), isTrue);
    semantics.dispose();
  });

  testWidgets('the code field and its error are separate nodes', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        _inList([
          const Text('Enter the code from your app'),
          OtpCodeField(onCompleted: (_) {}, errorText: 'That code is wrong'),
        ]),
      ),
    );
    final field = _node(tester, 'One-time code');
    expect(field.flagsCollection.isTextField, isTrue);
    final error = _node(tester, 'That code is wrong');
    expect(error.flagsCollection.isLiveRegion, isTrue);
    _node(tester, 'Enter the code from your app');
    semantics.dispose();
  });
}
