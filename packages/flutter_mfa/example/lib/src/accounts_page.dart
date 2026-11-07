import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mfa/flutter_mfa.dart';
import 'package:flutter_mfa_ui/flutter_mfa_ui.dart';

import 'account_detail_page.dart';
import 'add_account_dialog.dart';
import 'error_text.dart';
import 'relying_party_page.dart';
import 'scan_page.dart';

/// Lists the enrolled accounts with live codes (UC3) and adds accounts by
/// scanning (UC1) or typing the setup key (UC2).
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
  Stream<List<OtpAccount>>? _accounts;
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
      setState(() {
        _client = client;
        _accounts = client.watchAccounts();
      });
    } on MfaException catch (e) {
      if (mounted) setState(() => _startError = e);
    }
  }

  @override
  void dispose() {
    unawaited(_client?.dispose());
    super.dispose();
  }

  void _show(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _add(MfaClient client) async {
    final how = await showModalBottomSheet<_AddMethod>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: const Text('Scan QR code'),
              onTap: () => Navigator.of(context).pop(_AddMethod.scan),
            ),
            ListTile(
              leading: const Icon(Icons.keyboard),
              title: const Text('Enter setup key'),
              onTap: () => Navigator.of(context).pop(_AddMethod.manual),
            ),
          ],
        ),
      ),
    );
    if (!mounted || how == null) return;
    final added = switch (how) {
      _AddMethod.scan => await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => ScanPage(client: client)),
      ),
      _AddMethod.manual => await showDialog<bool>(
        context: context,
        builder: (_) => AddAccountDialog(client: client),
      ),
    };
    if (added ?? false) _show('Account added.');
  }

  Future<void> _copy(MfaClient client, OtpAccount account) async {
    try {
      await client.copyCode(account.id);
      _show('Code copied. It is cleared from the clipboard shortly.');
    } on MfaException catch (e) {
      _show(errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = _client;
    final accounts = _accounts;
    return Scaffold(
      appBar: AppBar(
        title: const Text('flutter_mfa example'),
        actions: [
          if (client != null)
            IconButton(
              tooltip: 'Relying-party demo',
              icon: const Icon(Icons.verified_user_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RelyingPartyPage(client: client),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: client == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _add(client),
              icon: const Icon(Icons.add),
              label: const Text('Add account'),
            ),
      body: switch ((client, accounts, _startError)) {
        (_, _, final Object error) => _Message(errorText(error)),
        (final MfaClient client, final Stream<List<OtpAccount>> accounts, _) =>
          OtpAccountList(
            accounts: accounts,
            // Counter-based accounts have no live code; open them to
            // generate one.
            codeStream: (account) => account.type == OtpType.totp
                ? client.codeStream(account.id)
                : null,
            onTap: (account) => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    AccountDetailPage(client: client, account: account),
              ),
            ),
            onCopy: (account) => _copy(client, account),
            emptyBuilder: (_) =>
                const _Message('No accounts yet. Tap “Add account”.'),
            errorBuilder: (_) => const _Message(
              'The accounts could not be read. Wipe the vault or restore a '
              'backup.',
            ),
            padding: const EdgeInsets.only(bottom: 88),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

enum _AddMethod { scan, manual }

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
