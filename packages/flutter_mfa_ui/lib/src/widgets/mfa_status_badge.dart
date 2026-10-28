import 'package:flutter/widgets.dart';

import '../l10n/mfa_strings.dart';
import '../theme/mfa_theme.dart';
import 'status_glyph.dart';

/// The MFA state of an account or user, for [MfaStatusBadge].
enum MfaStatus {
  /// Two-factor authentication is set up.
  enrolled,

  /// Two-factor authentication is not set up.
  notEnrolled,

  /// Too many failed attempts; verification is paused.
  locked,

  /// Biometrics changed, so a protected account must be added again.
  keyInvalidated,

  /// The device integrity check reported a problem.
  integrityWarning,
}

/// A small badge showing an [MfaStatus] with an icon **and** text, so the
/// state is never conveyed by colour alone (FR-UI-03, WCAG 1.4.1).
class MfaStatusBadge extends StatelessWidget {
  /// Creates a badge for [status].
  const MfaStatusBadge({super.key, required this.status});

  /// The state shown.
  final MfaStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = MfaTheme.of(context);
    final strings = mfaStrings(context);
    final (glyph, color, label) = switch (status) {
      MfaStatus.enrolled => (
        StatusGlyph.check,
        theme.success,
        strings.statusEnrolled,
      ),
      MfaStatus.notEnrolled => (
        StatusGlyph.circle,
        theme.onSurfaceVariant,
        strings.statusNotEnrolled,
      ),
      MfaStatus.locked => (StatusGlyph.lock, theme.error, strings.statusLocked),
      MfaStatus.keyInvalidated => (
        StatusGlyph.warning,
        theme.warning,
        strings.statusKeyInvalidated,
      ),
      MfaStatus.integrityWarning => (
        StatusGlyph.shield,
        theme.warning,
        strings.statusIntegrityWarning,
      ),
    };
    final textStyle = theme.labelTextStyle.copyWith(
      color: color,
      fontWeight: FontWeight.w600,
    );
    final iconSize = MediaQuery.textScalerOf(context).scale(16);
    return Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing,
          vertical: theme.spacing / 2,
        ),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(theme.radius * 2),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusGlyphIcon(glyph, color: color, size: iconSize),
            SizedBox(width: theme.spacing / 2),
            Flexible(child: Text(label, style: textStyle)),
          ],
        ),
      ),
    );
  }
}
