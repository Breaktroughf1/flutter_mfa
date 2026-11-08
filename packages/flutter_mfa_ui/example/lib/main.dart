import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:flutter_mfa_ui/flutter_mfa_ui.dart';
import 'package:flutter_mfa_ui/material.dart';

/// Starts the example app.
void main() => runApp(const ExampleApp());

/// Root widget of the flutter_mfa_ui example.
class ExampleApp extends StatefulWidget {
  /// Creates the example app.
  const ExampleApp({super.key});

  /// Title shown in the app bar; also used by tests.
  static const title = 'flutter_mfa_ui gallery';

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  static final _enrolmentUri = OtpAuthUri.parse(
    'otpauth://totp/Example:alice@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example',
  );

  static final _totpAccount = OtpAccount(
    id: 'totp-1',
    type: OtpType.totp,
    issuer: 'Example',
    accountName: 'alice@example.com',
    createdAt: DateTime.utc(2026),
  );

  static final _hotpAccount = OtpAccount(
    id: 'hotp-1',
    type: OtpType.hotp,
    issuer: 'Hardware Token',
    accountName: 'bob@example.com',
    counter: 0,
    createdAt: DateTime.utc(2026),
  );

  static const _sampleCode = OtpCode(
    value: '287082',
    remaining: Duration(seconds: 18),
    progress: 0.4,
    step: 1,
  );

  String? _enteredCode;
  Stream<OtpCode>? _hotpStream;

  @override
  Widget build(BuildContext context) {
    final materialTheme = ThemeData(
      colorSchemeSeed: Colors.indigo,
      useMaterial3: true,
    );
    return MaterialApp(
      title: ExampleApp.title,
      localizationsDelegates: const [MfaLocalizations.delegate],
      supportedLocales: MfaLocalizations.supportedLocales,
      theme: materialTheme,
      home: MfaTheme(
        data: materialTheme.toMfaTheme(),
        child: Scaffold(
          appBar: AppBar(title: const Text(ExampleApp.title)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              OtpCodeField(
                onCompleted: (code) => setState(() => _enteredCode = code),
              ),
              if (_enteredCode != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Entered: $_enteredCode',
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OtpCodeDisplay(
                    code: _sampleCode,
                    onCopy: () => Clipboard.setData(
                      ClipboardData(text: _sampleCode.value),
                    ),
                  ),
                  const SizedBox(width: 16),
                  OtpCountdownRing(
                    progress: _sampleCode.progress,
                    remaining: _sampleCode.remaining,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final status in MfaStatus.values)
                    MfaStatusBadge(status: status),
                ],
              ),
              const SizedBox(height: 16),
              OtpAccountTile(
                account: _totpAccount,
                codeStream: Stream.value(_sampleCode),
                onCopy: () => Clipboard.setData(
                  ClipboardData(text: _sampleCode.value),
                ),
              ),
              OtpAccountTile(
                account: _hotpAccount,
                codeStream: _hotpStream,
                onTap: () => setState(
                  () => _hotpStream = Stream.value(_sampleCode),
                ),
              ),
              const SizedBox(height: 24),
              EnrollmentQrView(
                uri: _enrolmentUri,
                onCopySecret: (secret) => Clipboard.setData(
                  ClipboardData(text: secret),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
