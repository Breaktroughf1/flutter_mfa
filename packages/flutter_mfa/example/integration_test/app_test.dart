import 'package:flutter_mfa_example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Smoke test; the full enrol → code → backup → restore journey is FR-EX-03 (M4-03).
  testWidgets('example app boots on the device', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pumpAndSettle();
    expect(find.text(ExampleApp.title), findsOneWidget);
  });
}
