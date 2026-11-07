import 'package:flutter/material.dart';
import 'package:flutter_mfa/flutter_mfa.dart';
import 'package:flutter_mfa_example/src/protection.dart';
import 'package:flutter_mfa_platform_interface/flutter_mfa_platform_interface.dart';
import 'package:flutter_mfa_platform_interface/testing.dart';
import 'package:flutter_test/flutter_test.dart';

VaultCapabilities _levels(Set<ProtectionLevel> levels) => VaultCapabilities(
  hardwareBacked: true,
  strongBox: false,
  secureEnclave: false,
  biometricsEnrolled: levels.length > 1,
  secureContext: true,
  persistentStorage: true,
  screenCaptureProtection: true,
  supportedLevels: levels,
);

void main() {
  late InMemoryMfaPlatform vault;
  late MfaClient client;

  setUp(() async {
    vault = InMemoryMfaPlatform();
    MfaPlatform.instance = vault;
    client = await MfaClient.create();
  });
  tearDown(() => client.dispose());

  /// Opens a page whose button calls [pickProtection] and records the result.
  Future<List<ProtectionLevel?>> open(WidgetTester tester) async {
    final results = <ProtectionLevel?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(
              await pickProtection(context, client, accountLabel: 'Example'),
            ),
            child: const Text('Pick'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Pick'));
    await tester.pumpAndSettle();
    return results;
  }

  testWidgets('a device with only standard storage is not asked', (
    tester,
  ) async {
    vault.currentCapabilities = _levels({ProtectionLevel.standard});
    final results = await open(tester);
    expect(find.byType(SimpleDialog), findsNothing);
    expect(results, [ProtectionLevel.standard]);
  });

  testWidgets('the dialog offers only the levels the device has', (
    tester,
  ) async {
    vault.currentCapabilities = _levels({
      ProtectionLevel.standard,
      ProtectionLevel.biometric,
    });
    final results = await open(tester);
    expect(find.text('Protect Example'), findsOneWidget);
    expect(find.text('Standard'), findsOneWidget);
    expect(find.text('Fingerprint or face for every code'), findsOneWidget);
    expect(find.text('Fingerprint or face, secure hardware'), findsNothing);
    await tester.tap(find.text('Fingerprint or face for every code'));
    await tester.pumpAndSettle();
    expect(results, [ProtectionLevel.biometric]);
  });

  testWidgets('dismissing the dialog cancels', (tester) async {
    vault.currentCapabilities = InMemoryMfaPlatform.allCapabilities;
    final results = await open(tester);
    await tester.tapAt(const Offset(5, 5)); // outside the dialog
    await tester.pumpAndSettle();
    expect(results, [null]);
  });
}
