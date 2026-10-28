import 'package:flutter/widgets.dart';
import 'package:flutter_mfa_core/flutter_mfa_core.dart';

import '../l10n/mfa_strings.dart';
import '../theme/mfa_theme.dart';
import '../theme/mfa_theme_data.dart';
import 'otp_code_display.dart';
import 'otp_countdown_ring.dart';
import 'status_glyph.dart';

/// One account with its live code (FR-UI-04).
///
/// Shows the issuer and account name, the current code from [codeStream]
/// (with a countdown ring for time-based accounts) and, with [onCopy], tap
/// to copy. Pass `MfaClient.codeStream(account.id)` for TOTP accounts. For
/// counter-based (HOTP) accounts pass `null` until the user asks for a
/// code: the tile then says "Tap to generate a code" and [onTap] should
/// call `MfaClient.currentCode`.
///
/// Stream errors (for example a locked vault) show "Code unavailable"; the
/// error itself is never displayed, so it cannot leak details.
class OtpAccountTile extends StatelessWidget {
  /// Creates a tile for [account].
  const OtpAccountTile({
    super.key,
    required this.account,
    required this.codeStream,
    this.onTap,
    this.onCopy,
  });

  /// The account shown.
  final OtpAccount account;

  /// Codes for [account]; `null` for an HOTP account with no code yet.
  final Stream<OtpCode>? codeStream;

  /// Called when the tile is tapped (open details, or generate an HOTP code).
  final VoidCallback? onTap;

  /// Copies the current code; `null` disables copying.
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = MfaTheme.of(context);
    final strings = mfaStrings(context);
    final issuer = account.issuer;
    final title = issuer ?? account.accountName;
    final label = issuer == null
        ? account.accountName
        : strings.accountLabel(issuer, account.accountName);
    final isTotp = account.type == OtpType.totp;
    final stream = codeStream;

    Widget names = Semantics(
      label: label,
      button: onTap != null,
      onTap: onTap,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: theme.titleTextStyle),
          if (issuer != null)
            Text(account.accountName, style: theme.labelTextStyle),
        ],
      ),
    );
    names = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: theme.minTapTarget),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          heightFactor: 1,
          child: names,
        ),
      ),
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing * 2,
        vertical: theme.spacing,
      ),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(bottom: BorderSide(color: theme.outline, width: 0.5)),
      ),
      child: stream == null
          ? _layout(
              theme,
              leading: StatusGlyphIcon(
                StatusGlyph.counter,
                color: theme.onSurfaceVariant,
                size: MediaQuery.textScalerOf(context).scale(24),
              ),
              names: names,
              code: Text(
                isTotp ? '' : strings.tapToGenerate,
                style: theme.labelTextStyle,
              ),
            )
          : StreamBuilder<OtpCode>(
              stream: stream,
              builder: (context, snapshot) {
                final code = snapshot.data;
                final Widget leading;
                final Widget codeWidget;
                if (snapshot.hasError) {
                  leading = StatusGlyphIcon(
                    StatusGlyph.warning,
                    color: theme.error,
                    size: MediaQuery.textScalerOf(context).scale(24),
                  );
                  codeWidget = Text(
                    strings.codeUnavailable,
                    style: theme.bodyTextStyle.copyWith(color: theme.error),
                  );
                } else if (code == null) {
                  leading = SizedBox.square(
                    dimension: MediaQuery.textScalerOf(context).scale(40),
                  );
                  codeWidget = const SizedBox.shrink();
                } else {
                  leading = isTotp
                      ? OtpCountdownRing(
                          progress: code.progress,
                          remaining: code.remaining,
                        )
                      : StatusGlyphIcon(
                          StatusGlyph.counter,
                          color: theme.onSurfaceVariant,
                          size: MediaQuery.textScalerOf(context).scale(24),
                        );
                  codeWidget = OtpCodeDisplay(code: code, onCopy: onCopy);
                }
                return _layout(
                  theme,
                  leading: leading,
                  names: names,
                  code: codeWidget,
                );
              },
            ),
    );
  }

  Widget _layout(
    MfaThemeData theme, {
    required Widget leading,
    required Widget names,
    required Widget code,
  }) => Row(
    children: [
      leading,
      SizedBox(width: theme.spacing * 2),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [names, code],
        ),
      ),
    ],
  );
}
