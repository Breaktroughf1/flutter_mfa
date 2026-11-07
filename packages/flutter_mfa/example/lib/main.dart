import 'package:flutter/material.dart';

/// Starts the example app.
void main() => runApp(const ExampleApp());

/// Root widget of the flutter_mfa example.
class ExampleApp extends StatelessWidget {
  /// Creates the example app.
  const ExampleApp({super.key});

  /// Title shown in the app bar; also used by tests.
  static const title = 'flutter_mfa example';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: title,
      home: Scaffold(
        appBar: AppBar(title: const Text(title)),
        body: const Center(
          child: Text(
            'Authenticator demo: accounts, codes, enrolment and backup (built from M1-15).',
          ),
        ),
      ),
    );
  }
}
