import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mfa/flutter_mfa.dart';
import 'package:flutter_mfa_ui/flutter_mfa_ui.dart';

import 'error_text.dart';

/// One account: its code (live for time-based accounts, on request for
/// counter-based ones), copy, rename and remove.
class AccountDetailPage extends StatefulWidget {
  /// Creates the page for [account].
  const AccountDetailPage({
    super.key,
    required this.client,
    required this.account,
  });

  /// The client the account belongs to.
  final MfaClient client;

  /// The account shown, as it was when the page opened.
  final OtpAccount account;

  @override
  State<AccountDetailPage> createState() => _AccountDetailPageState();
}

class _AccountDetailPageState extends State<AccountDetailPage> {
  late OtpAccount _account = widget.account;
  late final Stream<OtpCode>? _codes = _isTotp
      ? widget.client.codeStream(_account.id)
      : null;
  OtpCode? _counterCode;

  bool get _isTotp => _account.type == OtpType.totp;

  void _show(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _generate() async {
    try {
      final code = await widget.client.currentCode(_account.id);
      if (mounted) setState(() => _counterCode = code);
    } on MfaException catch (e) {
      _show(errorText(e));
    }
  }

  Future<void> _copy(OtpCode code) async {
    try {
      // The code on screen, not a new one: for counter-based accounts a new
      // code would use up the next counter value.
      await widget.client.copySensitive(code.value);
      _show('Code copied. It is cleared from the clipboard shortly.');
    } on MfaException catch (e) {
      _show(errorText(e));
    }
  }

  Future<void> _rename() async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _RenameDialog(account: _account),
    );
    if (result == null) return;
    try {
      final updated = await widget.client.rename(
        _account.id,
        issuer: result.$1,
        accountName: result.$2,
      );
      if (mounted) setState(() => _account = updated);
    } on MfaException catch (e) {
      _show(errorText(e));
    }
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove account?'),
        content: const Text(
          'Its secret is deleted from this device. Make sure you can still '
          'sign in, for example with another authenticator or recovery codes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;
    try {
      await widget.client.remove(_account.id);
      if (mounted) Navigator.of(context).pop();
    } on MfaException catch (e) {
      _show(errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final issuer = _account.issuer;
    return Scaffold(
      appBar: AppBar(
        title: Text(issuer ?? _account.accountName),
        actions: [
          IconButton(
            tooltip: 'Rename',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _rename,
          ),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.delete_outline),
            onPressed: _remove,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (issuer != null)
            Text(
              _account.accountName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          const SizedBox(height: 24),
          if (_codes case final codes?)
            StreamBuilder<OtpCode>(
              stream: codes,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text(errorText(snapshot.error!));
                }
                final code = snapshot.data;
                if (code == null) return const SizedBox(height: 48);
                return Row(
                  children: [
                    OtpCountdownRing(
                      progress: code.progress,
                      remaining: code.remaining,
                    ),
                    const SizedBox(width: 16),
                    OtpCodeDisplay(code: code, onCopy: () => _copy(code)),
                  ],
                );
              },
            )
          else ...[
            if (_counterCode case final code?)
              OtpCodeDisplay(code: code, onCopy: () => _copy(code)),
            const SizedBox(height: 16),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.icon(
                onPressed: _generate,
                icon: const Icon(Icons.refresh),
                label: const Text('Generate code'),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Each code uses up one counter value; generate one only when '
              'you are about to sign in.',
            ),
          ],
          const SizedBox(height: 32),
          Text(
            'Protection: ${_account.protection.name}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.account});

  final OtpAccount account;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _issuer = TextEditingController(text: widget.account.issuer);
  late final _name = TextEditingController(text: widget.account.accountName);

  @override
  void dispose() {
    _issuer.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename account'),
      content: Column(
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
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop((_issuer.text, _name.text)),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
