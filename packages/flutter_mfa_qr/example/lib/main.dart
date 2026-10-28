import 'package:flutter/material.dart';
import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:flutter_mfa_qr/flutter_mfa_qr.dart';
import 'package:flutter_mfa_ui/flutter_mfa_ui.dart';
import 'package:flutter_mfa_ui/material.dart';

/// A self-hosted `@zxing/library` script for browsers without
/// `BarcodeDetector`, for example
/// `flutter run -d chrome --dart-define=MFA_QR_DECODER_SCRIPT=zxing/index.min.js`
/// after copying the script to `web/zxing/` (see the package README).
const _decoderScript = String.fromEnvironment('MFA_QR_DECODER_SCRIPT');

/// Starts the example app.
void main() => runApp(const ExampleApp());

/// Root widget of the flutter_mfa_qr example.
class ExampleApp extends StatelessWidget {
  /// Creates the example app.
  const ExampleApp({super.key});

  /// Title shown in the app bar; also used by tests.
  static const title = 'flutter_mfa_qr example';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: title,
      localizationsDelegates: MfaLocalizations.localizationsDelegates,
      supportedLocales: MfaLocalizations.supportedLocales,
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      builder: (context, child) => MfaTheme(
        data: Theme.of(context).toMfaTheme(),
        child: child!,
      ),
      home: const HomePage(),
    );
  }
}

/// Shows the last scanned account (never its secret) and opens the scanner.
class HomePage extends StatefulWidget {
  /// Creates the home page.
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _result = 'Nothing scanned yet.';

  Future<void> _scan() async {
    final uri = await Navigator.of(context).push<OtpAuthUri>(
      MaterialPageRoute(builder: (_) => const ScanPage()),
    );
    if (uri == null || !mounted) return;
    // A real app enrols it here, for example with MfaClient.enrollFromUri.
    setState(() {
      final issuer = uri.issuer == null ? '' : '${uri.issuer}: ';
      _result = 'Scanned $issuer${uri.accountName} (${uri.type.name})';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(ExampleApp.title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_result, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _scan,
                child: const Text('Scan a QR code'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Scans until a valid `otpauth://` code is found, then returns it.
class ScanPage extends StatelessWidget {
  /// Creates the scan page.
  const ScanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan')),
      body: OtpQrScanner(
        webOptions: _decoderScript.isEmpty
            ? const OtpQrWebOptions()
            : OtpQrWebOptions(decoderScriptUrl: Uri.parse(_decoderScript)),
        onScanned: (uri) => Navigator.of(context).pop(uri),
        onRejected: (_) => ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Not an authenticator QR code')),
          ),
      ),
    );
  }
}
