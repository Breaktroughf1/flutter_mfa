import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mfa/flutter_mfa.dart';

/// Device protection and integrity status (FR-EX-02, FR-FAC-03).
class SettingsPage extends StatefulWidget {
  /// Creates the page for [client].
  const SettingsPage({super.key, required this.client});

  /// The client whose vault and integrity check are shown.
  final MfaClient client;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  VaultCapabilities? _capabilities;
  IntegrityReport? _integrity;
  String? _integrityError;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final capabilities = await widget.client.capabilities;
    if (mounted) setState(() => _capabilities = capabilities);
    await _checkIntegrity();
  }

  Future<void> _checkIntegrity() async {
    try {
      final report = await widget.client.checkIntegrity();
      if (mounted) {
        setState(() {
          _integrity = report;
          _integrityError = null;
        });
      }
    } on Object {
      // The app's integrity policy threw: it decided to block.
      if (mounted) {
        setState(
          () => _integrityError = "Blocked by the app's integrity policy.",
        );
      }
    }
  }

  static String _level(ProtectionLevel level) => switch (level) {
    ProtectionLevel.standard => 'Standard',
    ProtectionLevel.biometric => 'Biometric',
    ProtectionLevel.hardwareBound => 'Hardware-bound',
  };

  static String _verdict(IntegrityVerdict verdict) => switch (verdict) {
    IntegrityVerdict.trusted => 'No problems found',
    IntegrityVerdict.suspicious => 'Unusual environment',
    IntegrityVerdict.compromised => 'Device may be compromised',
    IntegrityVerdict.unknown => 'Not checked',
  };

  @override
  Widget build(BuildContext context) {
    final caps = _capabilities;
    final integrity = _integrity;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _Heading('Device protection'),
          if (caps == null)
            const ListTile(title: Text('Checking…'))
          else ...[
            ListTile(
              title: const Text('Hardware-backed keys'),
              trailing: Text(caps.hardwareBacked ? 'Yes' : 'No'),
            ),
            ListTile(
              title: const Text('Biometrics enrolled'),
              trailing: Text(caps.biometricsEnrolled ? 'Yes' : 'No'),
            ),
            ListTile(
              title: const Text('Protection levels on this device'),
              subtitle: Text(
                caps.supportedLevels.isEmpty
                    ? 'None: the vault cannot be used here'
                    : ProtectionLevel.values
                          .where(caps.supportedLevels.contains)
                          .map(_level)
                          .join(', '),
              ),
            ),
          ],
          const _Heading('Integrity'),
          ListTile(
            title: Text(
              _integrityError ??
                  (integrity == null
                      ? 'Checking…'
                      : _verdict(integrity.verdict)),
            ),
            subtitle: Text(
              integrity == null || integrity.signals.isEmpty
                  ? 'Root and jailbreak detection is a hint, not a guarantee. '
                        'This example uses no detector.'
                  : integrity.signals.join(', '),
            ),
            trailing: IconButton(
              tooltip: 'Check again',
              icon: const Icon(Icons.refresh),
              onPressed: _checkIntegrity,
            ),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    ),
  );
}
