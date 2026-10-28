import 'package:flutter/material.dart';
import 'package:flutter_mfa/flutter_mfa.dart';
import 'package:flutter_mfa_qr/flutter_mfa_qr.dart';

import 'add_account_dialog.dart';
import 'error_text.dart';

/// Adds an account by scanning its enrolment QR code (UC1), with manual
/// entry always available.
///
/// Pops `true` once an account is stored.
class ScanPage extends StatefulWidget {
  /// Creates the page over [client].
  const ScanPage({super.key, required this.client});

  /// The client accounts are enrolled with.
  final MfaClient client;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  bool _busy = false;

  void _show(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _enrol(OtpAuthUri uri) async {
    // A second code seen while the first is being stored is ignored.
    if (_busy) return;
    _busy = true;
    try {
      await widget.client.enrollFromUri(uri.toUri().toString());
      if (mounted) Navigator.of(context).pop(true);
    } on MfaException catch (e) {
      _busy = false;
      _show(errorText(e));
    }
  }

  Future<void> _enterManually() async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => AddAccountDialog(client: widget.client),
    );
    if ((added ?? false) && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR code')),
      body: Column(
        children: [
          Expanded(
            child: OtpQrScanner(
              onScanned: _enrol,
              // The text may contain a secret: it is never shown or logged.
              onRejected: (_) => _show('That is not an authenticator QR code.'),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                onPressed: _enterManually,
                icon: const Icon(Icons.keyboard),
                label: const Text('Enter setup key instead'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
