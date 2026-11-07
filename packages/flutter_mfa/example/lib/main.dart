import 'package:flutter/material.dart';
import 'package:flutter_mfa/flutter_mfa.dart';

import 'src/accounts_page.dart';

/// Starts the example app.
void main() => runApp(const ExampleApp());

/// Root widget of the flutter_mfa example (FR-EX-01): one codebase for
/// Android, iOS and web that uses only the `MfaClient` API.
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
      home: AccountsPage(createClient: createClient),
    );
  }
}
