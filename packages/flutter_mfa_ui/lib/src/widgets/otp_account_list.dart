import 'package:flutter/widgets.dart';
import 'package:flutter_mfa_core/flutter_mfa_core.dart';

import '../l10n/mfa_strings.dart';
import '../theme/mfa_theme.dart';
import 'otp_account_tile.dart';

/// A scrolling list of [OtpAccountTile]s driven by an account stream
/// (FR-UI-04).
///
/// Pass `MfaClient.watchAccounts()` as [accounts] and a function returning
/// each account's code stream (for example `client.codeStream` for TOTP
/// accounts, `null` for HOTP). Shows "No accounts yet" when the list is
/// empty and nothing while the first list loads. Stream errors are left to
/// [errorBuilder] (default: the localized "Code unavailable" message), so
/// error details are never displayed.
class OtpAccountList extends StatelessWidget {
  /// Creates a list over [accounts].
  const OtpAccountList({
    super.key,
    required this.accounts,
    required this.codeStream,
    this.onTap,
    this.onCopy,
    this.emptyBuilder,
    this.errorBuilder,
    this.padding,
  });

  /// The accounts to show, for example `MfaClient.watchAccounts()`.
  final Stream<List<OtpAccount>> accounts;

  /// The code stream for an account, or `null` for none yet (HOTP).
  final Stream<OtpCode>? Function(OtpAccount account) codeStream;

  /// Called when an account's tile is tapped.
  final ValueChanged<OtpAccount>? onTap;

  /// Copies an account's current code; `null` disables copying.
  final ValueChanged<OtpAccount>? onCopy;

  /// Builds the empty state; defaults to a localized "No accounts yet".
  final WidgetBuilder? emptyBuilder;

  /// Builds the state shown when [accounts] reports an error.
  final WidgetBuilder? errorBuilder;

  /// Padding around the list.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<OtpAccount>>(
    stream: accounts,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return errorBuilder?.call(context) ??
            _message(context, mfaStrings(context).codeUnavailable);
      }
      final list = snapshot.data;
      if (list == null) return const SizedBox.shrink();
      if (list.isEmpty) {
        return emptyBuilder?.call(context) ??
            _message(context, mfaStrings(context).noAccounts);
      }
      return ListView.builder(
        padding: padding,
        itemCount: list.length,
        itemBuilder: (context, i) {
          final account = list[i];
          return _LiveTile(
            key: ValueKey(account.id),
            account: account,
            codeStream: codeStream,
            onTap: onTap == null ? null : () => onTap!(account),
            onCopy: onCopy == null ? null : () => onCopy!(account),
          );
        },
      );
    },
  );

  static Widget _message(BuildContext context, String text) {
    final theme = MfaTheme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(theme.spacing * 3),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: theme.bodyTextStyle.copyWith(color: theme.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// Holds an account's code stream across rebuilds, so a new account list
/// does not resubscribe (and reset) every tile. The stream is created again
/// only when the item is rebuilt from scratch, for example after scrolling
/// back into view, so single-subscription streams are never listened to
/// twice.
class _LiveTile extends StatefulWidget {
  const _LiveTile({
    super.key,
    required this.account,
    required this.codeStream,
    required this.onTap,
    required this.onCopy,
  });

  final OtpAccount account;
  final Stream<OtpCode>? Function(OtpAccount account) codeStream;
  final VoidCallback? onTap;
  final VoidCallback? onCopy;

  @override
  State<_LiveTile> createState() => _LiveTileState();
}

class _LiveTileState extends State<_LiveTile> {
  late final Stream<OtpCode>? _stream = widget.codeStream(widget.account);

  @override
  Widget build(BuildContext context) => OtpAccountTile(
    account: widget.account,
    codeStream: _stream,
    onTap: widget.onTap,
    onCopy: widget.onCopy,
  );
}
