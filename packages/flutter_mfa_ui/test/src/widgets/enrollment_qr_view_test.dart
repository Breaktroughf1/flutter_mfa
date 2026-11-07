import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:flutter_mfa_ui/flutter_mfa_ui.dart';
import 'package:flutter_mfa_ui/src/widgets/enrollment_qr_view.dart'
    show groupSetupKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:zxing2/qrcode.dart';

import '../../support/harness.dart';

final uri = OtpAuthUri.parse(
  'otpauth://totp/Example:alice@example.com?secret=GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ&issuer=Example',
);

/// Renders [finder] and decodes it as a QR code.
Future<String> decodeQr(WidgetTester tester, Finder finder) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.ancestor(of: finder, matching: find.byType(RepaintBoundary)).first,
  );
  final pixels = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return (image.width, image.height, data!);
  });
  final (width, height, rgba) = pixels!;
  final argb = Int32List(width * height);
  for (var i = 0; i < argb.length; i++) {
    final r = rgba.getUint8(i * 4);
    final g = rgba.getUint8(i * 4 + 1);
    final b = rgba.getUint8(i * 4 + 2);
    argb[i] = (0xFF << 24) | (r << 16) | (g << 8) | b;
  }
  final source = RGBLuminanceSource(width, height, argb);
  return QRCodeReader().decode(BinaryBitmap(HybridBinarizer(source))).text;
}

void main() {
  Widget view({bool showSecret = true, ValueChanged<String>? onCopy}) => host(
    SizedBox(
      width: 300,
      child: RepaintBoundary(
        child: EnrollmentQrView(
          uri: uri,
          showSecret: showSecret,
          onCopySecret: onCopy,
        ),
      ),
    ),
  );

  testWidgets('the QR code decodes to the enrolment URI (FR-UI-05)', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        RepaintBoundary(
          child: SizedBox(
            width: 240,
            child: EnrollmentQrView(uri: uri, showSecret: false),
          ),
        ),
      ),
    );
    final decoded = await decodeQr(tester, find.byType(EnrollmentQrView));
    expect(OtpAuthUri.parse(decoded).toUri(), uri.toUri());
  });

  testWidgets('shows the setup key in groups of four (AC1)', (tester) async {
    await tester.pumpWidget(view());
    expect(find.text('Setup key'), findsOneWidget);
    expect(
      find.text('GEZD GNBV GY3T QOJQ GEZD GNBV GY3T QOJQ'),
      findsOneWidget,
    );
    expect(find.textContaining('Keep this private'), findsOneWidget);
  });

  testWidgets('copies the key only when the app provides a copier', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(view());
    expect(find.bySemanticsLabel('Copy setup key'), findsNothing);
    final copied = <String>[];
    await tester.pumpWidget(view(onCopy: copied.add));
    await tester.tap(find.bySemanticsLabel('Copy setup key'));
    expect(copied, ['GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ']);
    final node = tester.getSemantics(find.bySemanticsLabel('Copy setup key'));
    node.owner!.performAction(node.id, ui.SemanticsAction.tap);
    expect(copied, hasLength(2));
    expect(
      tester.getSize(find.bySemanticsLabel('Copy setup key')),
      const Size(48, 48),
    );
    handle.dispose();
  });

  testWidgets('the key can be hidden; the warning always shows', (
    tester,
  ) async {
    await tester.pumpWidget(view(showSecret: false));
    expect(find.text('Setup key'), findsNothing);
    expect(find.textContaining('GEZD'), findsNothing);
    expect(find.textContaining('Keep this private'), findsOneWidget);
  });

  testWidgets('is labelled as an image for screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(view());
    final node = tester.getSemantics(
      find.bySemanticsLabel(
        'QR code to add this account to an authenticator app',
      ),
    );
    expect(node.flagsCollection.isImage, isTrue);
    handle.dispose();
  });

  testWidgets('fits narrow and unbounded layouts', (tester) async {
    await tester.pumpWidget(
      host(
        SizedBox(
          width: 100,
          child: EnrollmentQrView(uri: uri, showSecret: false),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      host(
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: EnrollmentQrView(uri: uri, showSecret: false),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final paint = find.descendant(
      of: find.byType(EnrollmentQrView),
      matching: find.byType(CustomPaint),
    );
    expect(tester.getSize(paint.first), const Size(240, 240));
  });

  testWidgets('repaints only for a different URI', (tester) async {
    CustomPainter painter() => tester
        .widget<CustomPaint>(
          find
              .descendant(
                of: find.byType(EnrollmentQrView),
                matching: find.byType(CustomPaint),
              )
              .first,
        )
        .painter!;
    await tester.pumpWidget(view(showSecret: false));
    final first = painter();
    await tester.pumpWidget(view(showSecret: false));
    expect(painter().shouldRepaint(first), isFalse);
    await tester.pumpWidget(
      host(
        EnrollmentQrView(
          uri: OtpAuthUri.parse('otpauth://totp/bob?secret=JBSWY3DPEHPK3PXP'),
          showSecret: false,
        ),
      ),
    );
    expect(painter().shouldRepaint(first), isTrue);
  });

  test('groupSetupKey splits in fours and keeps a short tail', () {
    expect(groupSetupKey('ABCDEFGHIJ'), 'ABCD EFGH IJ');
    expect(groupSetupKey(''), '');
  });
}
