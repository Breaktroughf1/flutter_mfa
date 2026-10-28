import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mfa/flutter_mfa.dart';

/// One account with its current code.
///
/// TOTP codes refresh every second; HOTP codes are generated on tap, which
/// advances the counter.
class CodeTile extends StatefulWidget {
  /// Creates a tile for [account].
  const CodeTile({
    super.key,
    required this.client,
    required this.account,
    required this.onError,
    required this.onRemove,
  });

  /// The client the codes come from.
  final MfaClient client;

  /// The account shown.
  final OtpAccount account;

  /// Reports a failure to the user.
  final void Function(Object error) onError;

  /// Removes the account.
  final VoidCallback onRemove;

  @override
  State<CodeTile> createState() => _CodeTileState();
}

class _CodeTileState extends State<CodeTile> {
  OtpCode? _code;
  Timer? _ticker;
  bool _failed = false;

  bool get _isTotp => widget.account.type == OtpType.totp;

  @override
  void initState() {
    super.initState();
    if (_isTotp) {
      unawaited(_refresh());
      _ticker = Timer.periodic(
        const Duration(seconds: 1),
        (_) => unawaited(_refresh()),
      );
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final code = await widget.client.currentCode(widget.account.id);
      if (mounted) setState(() => _code = code);
    } on MfaException catch (e) {
      _ticker?.cancel();
      if (!mounted) return;
      setState(() => _failed = true);
      widget.onError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final code = _code;
    final issuer = account.issuer;
    return ListTile(
      title: Text(
        issuer == null
            ? account.accountName
            : '$issuer · ${account.accountName}',
      ),
      subtitle: Text(
        _failed
            ? 'Unavailable'
            : code == null
            ? (_isTotp ? '…' : 'Tap to generate a code')
            : code.grouped,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      leading: _isTotp
          ? SizedBox.square(
              dimension: 32,
              child: CircularProgressIndicator(
                value: 1 - (code?.progress ?? 0),
              ),
            )
          : const Icon(Icons.pin_outlined),
      onTap: _isTotp || _failed ? null : _refresh,
      trailing: IconButton(
        tooltip: 'Remove',
        icon: const Icon(Icons.delete_outline),
        onPressed: widget.onRemove,
      ),
    );
  }
}
