import 'package:flutter_mfa_qr_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the example title and the scan action', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.text(ExampleApp.title), findsOneWidget);
    expect(find.text('Scan a QR code'), findsOneWidget);
  });
}
