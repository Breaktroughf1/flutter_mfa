import 'package:flutter_mfa_ui_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the example title', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.text(ExampleApp.title), findsOneWidget);
  });
}
