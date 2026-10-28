import 'package:flutter/material.dart';
import 'package:flutter_mfa/flutter_mfa.dart';
import 'package:flutter_mfa_ui/flutter_mfa_ui.dart';
import 'package:flutter_mfa_ui/material.dart';

import 'src/accounts_page.dart';

/// Starts the example app.
void main() => runApp(const ExampleApp());

/// Root widget of the flutter_mfa example (FR-EX-01, FR-EX-02): one
/// codebase for Android, iOS and web that uses only public APIs of
/// flutter_mfa, flutter_mfa_ui and flutter_mfa_qr.
class ExampleApp extends StatelessWidget {
  /// Creates the example app. [createClient] defaults to
  /// [MfaClient.create]; tests pass a client over an in-memory vault.
  const ExampleApp({super.key, this.createClient = MfaClient.create});

  /// Title shown in the app bar; also used by tests.
  static const title = 'flutter_mfa example';

  /// Opens the client the app works with.
  final Future<MfaClient> Function() createClient;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: title,
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      localizationsDelegates: MfaLocalizations.localizationsDelegates,
      supportedLocales: MfaLocalizations.supportedLocales,
      // The flutter_mfa widgets follow the app's Material theme.
      builder: (context, child) =>
          MfaTheme(data: Theme.of(context).toMfaTheme(), child: child!),
      home: AccountsPage(createClient: createClient),
    );
  }
}
