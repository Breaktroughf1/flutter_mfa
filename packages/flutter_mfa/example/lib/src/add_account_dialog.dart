import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mfa/flutter_mfa.dart';

import 'error_text.dart';

/// Adds an account from a Base32 secret typed by the user (UC2).
///
/// Pops `true` once the account is stored. Invalid input is reported in the
/// dialog and nothing is stored.
class AddAccountDialog extends StatefulWidget {
  /// Creates the dialog over [client].
  const AddAccountDialog({super.key, required this.client});

  /// The client accounts are enrolled with.
  final MfaClient client;

  @override
  State<AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends State<AddAccountDialog> {
  final _issuer = TextEditingController();
  final _name = TextEditingController();
  final _secret = TextEditingController();
  var _type = OtpType.totp;
  var _protection = ProtectionLevel.standard;
  List<ProtectionLevel> _levels = const [ProtectionLevel.standard];

  @override
  void initState() {
    super.initState();
    // Offer only what this device can provide (never a silent downgrade).
    unawaited(
      widget.client.capabilities.then((caps) {
        if (!mounted) return;
        setState(() {
          _levels = ProtectionLevel.values
              .where(caps.supportedLevels.contains)
              .toList();
        });
      }, onError: (Object _) {}),
    );
  }

  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    // The secret field's text is not retained beyond the dialog.
    _secret
      ..clear()
      ..dispose();
    _issuer.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final issuer = _issuer.text.trim();
      await widget.client.enrollManual(
        secretBase32: _secret.text,
        accountName: _name.text.trim(),
        issuer: issuer.isEmpty ? null : issuer,
        type: _type,
        protection: _protection,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on MfaException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = errorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add account'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _issuer,
              decoration: const InputDecoration(labelText: 'Issuer (optional)'),
            ),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Account name'),
            ),
            TextField(
              controller: _secret,
              decoration: const InputDecoration(
                labelText: 'Secret key (Base32)',
              ),
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              keyboardType: TextInputType.visiblePassword,
            ),
            const SizedBox(height: 16),
            SegmentedButton<OtpType>(
              segments: const [
                ButtonSegment(value: OtpType.totp, label: Text('Time-based')),
                ButtonSegment(
                  value: OtpType.hotp,
                  label: Text('Counter-based'),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.single),
            ),
            if (_levels.length > 1) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<ProtectionLevel>(
                initialValue: _protection,
                decoration: const InputDecoration(labelText: 'Protection'),
                items: [
                  for (final level in _levels)
                    DropdownMenuItem(
                      value: level,
                      child: Text(protectionLabel(level)),
                    ),
                ],
                onChanged: (level) =>
                    setState(() => _protection = level ?? _protection),
              ),
            ],
            if (_error case final error?)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: const Text('Add'),
        ),
      ],
    );
  }
}

/// A short label for [level], shared by the add dialog and the detail page.
String protectionLabel(ProtectionLevel level) => switch (level) {
  ProtectionLevel.standard => 'Standard',
  ProtectionLevel.biometric => 'Fingerprint or face for every code',
  ProtectionLevel.hardwareBound => 'Fingerprint or face, secure hardware',
};
