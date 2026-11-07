import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mfa/flutter_mfa.dart';

import 'add_account_dialog.dart';
import 'code_tile.dart';
import 'error_text.dart';

/// Lists the enrolled accounts with their current codes (UC3) and adds
/// accounts manually (UC2).
class AccountsPage extends StatefulWidget {
  /// Creates the page; [createClient] opens the vault.
  const AccountsPage({super.key, required this.createClient});

  /// Opens the client the page works with.
  final Future<MfaClient> Function() createClient;

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  MfaClient? _client;
  Object? _startError;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  Future<void> _open() async {
    try {
      final client = await widget.createClient();
      if (!mounted) {
        await client.dispose();
        return;
      }
      setState(() => _client = client);
    } on MfaException catch (e) {
      if (mounted) setState(() => _startError = e);
    }
  }

  @override
  void dispose() {
    unawaited(_client?.dispose());
    super.dispose();
  }

  void _show(Object error) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(errorText(error))));
  }

  Future<void> _add(MfaClient client) async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => AddAccountDialog(client: client),
    );
    if (added ?? false) _show('Account added.');
  }

  Future<void> _remove(MfaClient client, OtpAccount account) async {
    try {
      await client.remove(account.id);
    } on MfaException catch (e) {
      _show(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = _client;
    return Scaffold(
      appBar: AppBar(title: const Text('flutter_mfa example')),
      floatingActionButton: client == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _add(client),
              icon: const Icon(Icons.add),
              label: const Text('Add account'),
            ),
      body: switch ((client, _startError)) {
        (_, final Object error) => _Message(errorText(error)),
        (null, _) => const Center(child: CircularProgressIndicator()),
        (final MfaClient client, _) => StreamBuilder<List<OtpAccount>>(
          stream: client.watchAccounts(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return _Message(errorText(snapshot.error!));
            final accounts = snapshot.data;
            if (accounts == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (accounts.isEmpty) {
              return const _Message('No accounts yet. Tap “Add account”.');
            }
            return ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                for (final account in accounts)
                  CodeTile(
                    key: ValueKey(account.id),
                    client: client,
                    account: account,
                    onError: _show,
                    onRemove: () => _remove(client, account),
                  ),
              ],
            );
          },
        ),
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}
