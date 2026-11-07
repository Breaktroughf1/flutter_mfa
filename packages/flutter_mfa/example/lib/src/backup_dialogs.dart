import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mfa/flutter_mfa.dart';

import 'error_text.dart';

const _codec = BackupCodec();

/// Exports every account as an encrypted, armoured backup (UC6, FR-BAK-01).
///
/// The passphrase is typed twice and must pass `PassphrasePolicy`. The
/// result is text the user can copy into a password manager or a file.
class ExportBackupDialog extends StatefulWidget {
  /// Creates the dialog over [client].
  const ExportBackupDialog({super.key, required this.client});

  /// The client whose accounts are exported.
  final MfaClient client;

  @override
  State<ExportBackupDialog> createState() => _ExportBackupDialogState();
}

class _ExportBackupDialogState extends State<ExportBackupDialog> {
  final _passphrase = TextEditingController();
  final _confirm = TextEditingController();
  String? _armored;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _passphrase
      ..clear()
      ..dispose();
    _confirm
      ..clear()
      ..dispose();
    super.dispose();
  }

  Future<void> _export() async {
    if (_passphrase.text != _confirm.text) {
      setState(() => _error = 'The passphrases do not match.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await widget.client.exportEncrypted(_passphrase.text);
      if (mounted) setState(() => _armored = _codec.armor(data));
    } on MfaException catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final armored = _armored;
    return AlertDialog(
      title: const Text('Export encrypted backup'),
      content: SingleChildScrollView(
        child: armored == null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Choose a passphrase of at least 12 characters. Without '
                    'it the backup cannot be restored, and nobody can '
                    'recover it for you.',
                  ),
                  _PassphraseField(
                    controller: _passphrase,
                    label: 'Passphrase',
                  ),
                  _PassphraseField(
                    controller: _confirm,
                    label: 'Repeat passphrase',
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                    const Text('Encrypting… this takes a few seconds.'),
                  ],
                  _ErrorText(_error),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Keep this text somewhere safe, apart from the '
                    'passphrase.',
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    armored,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
      ),
      actions: armored == null
          ? [
              TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: _busy ? null : _export,
                child: const Text('Export'),
              ),
            ]
          : [
              TextButton(
                onPressed: () async {
                  // Encrypted, so an ordinary copy is fine.
                  await Clipboard.setData(ClipboardData(text: armored));
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text('Copy and close'),
              ),
            ],
    );
  }
}

/// Restores accounts from an armoured backup (UC7, FR-BAK-03). Pops the
/// `ImportReport` once the import is committed.
class RestoreBackupDialog extends StatefulWidget {
  /// Creates the dialog over [client]; [onDuplicate] is preselected.
  const RestoreBackupDialog({
    super.key,
    required this.client,
    this.onDuplicate = DuplicateStrategy.skip,
  });

  /// The client the accounts are restored into.
  final MfaClient client;

  /// The duplicate strategy selected when the dialog opens.
  final DuplicateStrategy onDuplicate;

  @override
  State<RestoreBackupDialog> createState() => _RestoreBackupDialogState();
}

class _RestoreBackupDialogState extends State<RestoreBackupDialog> {
  final _text = TextEditingController();
  final _passphrase = TextEditingController();
  late var _strategy = widget.onDuplicate;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    _passphrase
      ..clear()
      ..dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final report = await widget.client.importEncrypted(
        _codec.dearmor(_text.text),
        _passphrase.text,
        onDuplicate: _strategy,
      );
      if (mounted) Navigator.of(context).pop(report);
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
      title: const Text('Restore from backup'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _text,
              decoration: const InputDecoration(
                labelText: 'Backup text',
                hintText: '-----BEGIN FLUTTER MFA BACKUP-----',
              ),
              minLines: 3,
              maxLines: 6,
              autocorrect: false,
              enableSuggestions: false,
            ),
            _PassphraseField(controller: _passphrase, label: 'Passphrase'),
            const SizedBox(height: 16),
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text('Accounts already on this device'),
            ),
            const SizedBox(height: 8),
            SegmentedButton<DuplicateStrategy>(
              segments: const [
                ButtonSegment(
                  value: DuplicateStrategy.skip,
                  label: Text('Keep'),
                ),
                ButtonSegment(
                  value: DuplicateStrategy.replace,
                  label: Text('Replace'),
                ),
                ButtonSegment(
                  value: DuplicateStrategy.keepBoth,
                  label: Text('Keep both'),
                ),
              ],
              selected: {_strategy},
              onSelectionChanged: (s) => setState(() => _strategy = s.single),
            ),
            if (_busy) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              const Text('Decrypting… this takes a few seconds.'),
            ],
            _ErrorText(_error),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _restore,
          child: const Text('Restore'),
        ),
      ],
    );
  }
}

/// A one-line summary of an import for a snack bar.
String importSummary(ImportReport report) =>
    'Restored ${report.added.length} new, replaced ${report.replaced.length}, '
    'kept ${report.skipped.length} already here.';

class _PassphraseField extends StatelessWidget {
  const _PassphraseField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    decoration: InputDecoration(labelText: label),
    obscureText: true,
    autocorrect: false,
    enableSuggestions: false,
    enableIMEPersonalizedLearning: false,
  );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.error);

  final String? error;

  @override
  Widget build(BuildContext context) => switch (error) {
    final String text => Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        text,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ),
    null => const SizedBox.shrink(),
  };
}
