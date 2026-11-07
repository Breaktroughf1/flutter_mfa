import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_mfa_core/flutter_mfa_core.dart';

import '../l10n/mfa_strings.dart';
import '../theme/mfa_theme.dart';
import 'status_glyph.dart';

/// Shows a one-time code grouped for reading (`123 456`, `1234 5678`)
/// (FR-UI-02).
///
/// With [onCopy], tapping copies: wire it to `MfaClient.copyCode`, which
/// marks the clip sensitive and clears it after the configured expiry
/// (30 s by default). "Code copied" is then shown and announced. With
/// [hidden], dots are shown and screen readers hear "Code hidden".
///
/// Screen readers hear the digits one by one. Codes are always laid out
/// left to right.
class OtpCodeDisplay extends StatefulWidget {
  /// Creates a display for [code].
  const OtpCodeDisplay({
    super.key,
    required this.code,
    this.onCopy,
    this.hidden = false,
  });

  /// The code shown.
  final OtpCode code;

  /// Copies the code; `null` makes the display read-only.
  final VoidCallback? onCopy;

  /// Whether the digits are hidden.
  final bool hidden;

  /// How long the "Code copied" confirmation stays visible.
  static const confirmationDuration = Duration(seconds: 2);

  @override
  State<OtpCodeDisplay> createState() => _OtpCodeDisplayState();
}

class _OtpCodeDisplayState extends State<OtpCodeDisplay> {
  Timer? _confirmation;

  @override
  void dispose() {
    _confirmation?.cancel();
    super.dispose();
  }

  void _copy() {
    widget.onCopy!();
    _confirmation?.cancel();
    setState(() {
      _confirmation = Timer(OtpCodeDisplay.confirmationDuration, () {
        if (mounted) setState(() => _confirmation = null);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = MfaTheme.of(context);
    final strings = mfaStrings(context);
    final code = widget.code;
    final shown = widget.hidden
        ? code.grouped.replaceAll(RegExp('[0-9]'), '•')
        : code.grouped;
    final label = widget.hidden
        ? strings.codeHidden
        : strings.codeLabel(code.value.split('').join(' '));
    final copyable = widget.onCopy != null && !widget.hidden;
    final copied = _confirmation != null;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.ltr,
      children: [
        Flexible(
          child: Text(
            shown,
            textDirection: TextDirection.ltr,
            style: theme.codeTextStyle,
            maxLines: 1,
            softWrap: false,
          ),
        ),
        if (copyable) ...[
          SizedBox(width: theme.spacing),
          StatusGlyphIcon(
            StatusGlyph.copy,
            color: theme.primary,
            size: MediaQuery.textScalerOf(context).scale(20),
          ),
        ],
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          container: true,
          label: label,
          button: copyable,
          onTap: copyable ? _copy : null,
          onTapHint: copyable ? strings.copyCode : null,
          excludeSemantics: true,
          child: GestureDetector(
            onTap: copyable ? _copy : null,
            behavior: HitTestBehavior.opaque,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: theme.minTapTarget,
                minWidth: theme.minTapTarget,
              ),
              child: Align(widthFactor: 1, heightFactor: 1, child: content),
            ),
          ),
        ),
        if (copied)
          Semantics(
            container: true,
            liveRegion: true,
            child: Text(
              strings.codeCopied,
              style: theme.labelTextStyle.copyWith(color: theme.success),
            ),
          ),
      ],
    );
  }
}
