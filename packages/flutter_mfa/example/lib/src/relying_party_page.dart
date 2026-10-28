import 'package:flutter/material.dart';
import 'package:flutter_mfa/flutter_mfa.dart';
import 'package:flutter_mfa_ui/flutter_mfa_ui.dart';

import 'error_text.dart';

/// Plays the service side of enrolment (FR-FAC-07): generate a secret, show
/// it as a QR code, and confirm the first code before "storing" it.
///
/// In a real service the secret and the code check live on your server
/// (ADR-0002); this page keeps them in memory only to demonstrate the flow.
class RelyingPartyPage extends StatefulWidget {
  /// Creates the page; [client] copies the setup key and can add the
  /// account to this device's authenticator.
  const RelyingPartyPage({super.key, required this.client});

  /// The client used to copy the setup key and add the account here.
  final MfaClient client;

  @override
  State<RelyingPartyPage> createState() => _RelyingPartyPageState();
}

class _RelyingPartyPageState extends State<RelyingPartyPage> {
  final _issuer = TextEditingController(text: 'Breaktrough Demo');
  final _name = TextEditingController(text: 'alice@example.com');
  final _code = TextEditingController();
  RelyingPartyEnrollment? _enrollment;
  String? _setupError;
  String? _codeError;
  bool _confirmed = false;

  @override
  void dispose() {
    _issuer.dispose();
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  void _show(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _generate() {
    setState(() {
      _setupError = null;
      _codeError = null;
      _confirmed = false;
      _code.clear();
      try {
        _enrollment = MfaClient.createEnrollment(
          issuer: _issuer.text,
          accountName: _name.text,
        );
      } on OtpAuthUriException {
        _enrollment = null;
        _setupError = 'The service name must not contain a colon.';
      } on MfaException catch (e) {
        _enrollment = null;
        _setupError = errorText(e);
      }
    });
  }

  Future<void> _confirm(String code) async {
    final enrollment = _enrollment;
    if (enrollment == null) return;
    // Your server would also pass the account's last used step here and
    // rate-limit attempts per user.
    final result = await enrollment.verifier.verify(
      code,
      subject: enrollment.uri.accountName,
    );
    if (!mounted) return;
    setState(() {
      _confirmed = result is Accepted;
      _codeError = switch (result) {
        Accepted() => null,
        Rejected(reason: RejectReason.malformed) => 'Enter all six digits.',
        Rejected() => 'That code is not right. Check the time on your device.',
      };
      if (!_confirmed) _code.clear();
    });
  }

  Future<void> _addHere(RelyingPartyEnrollment enrollment) async {
    try {
      await widget.client.enrollFromUri(enrollment.uri.toUri().toString());
      _show('Added to this app. Enter the code it shows below.');
    } on MfaException catch (e) {
      _show(errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final enrollment = _enrollment;
    return Scaffold(
      appBar: AppBar(title: const Text('Relying-party demo')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'This screen plays the service you sign in to. In production the '
            'secret and the code check stay on your server.',
          ),
          TextField(
            controller: _issuer,
            decoration: const InputDecoration(labelText: 'Service name'),
          ),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'User account'),
          ),
          if (_setupError case final error?)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton(
              onPressed: _generate,
              child: Text(
                enrollment == null ? 'Generate secret' : 'Generate a new one',
              ),
            ),
          ),
          if (enrollment != null) ...[
            const SizedBox(height: 24),
            Text(
              '1. Scan this with an authenticator app',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            EnrollmentQrView(
              uri: enrollment.uri,
              onCopySecret: widget.client.copySensitive,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => _addHere(enrollment),
                icon: const Icon(Icons.add),
                label: const Text('Or add it to this app'),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '2. Enter the code it shows',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            OtpCodeField(
              controller: _code,
              onCompleted: _confirm,
              errorText: _codeError,
            ),
            if (_confirmed) ...[
              const SizedBox(height: 24),
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: MfaStatusBadge(status: MfaStatus.enrolled),
              ),
              const SizedBox(height: 8),
              const Text(
                'Code confirmed. The service would now store the secret with '
                'the account and ask for a code at every sign-in.',
              ),
            ],
          ],
        ],
      ),
    );
  }
}
