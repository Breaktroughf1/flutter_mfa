import 'package:flutter/cupertino.dart';

import 'mfa_theme_data.dart';

/// Derives an [MfaThemeData] from a [CupertinoThemeData] (ADR-0006,
/// ADR-0013).
///
/// One of the two files allowed to import Cupertino.
extension MfaCupertinoTheme on CupertinoThemeData {
  /// An [MfaThemeData] using this theme's primary colour, background and
  /// text style.
  ///
  /// [brightness] is used when the theme does not set one (default light).
  /// Dynamic colours are resolved for that brightness. Roles without an
  /// accessible Cupertino equivalent (borders, error, success, warning)
  /// keep the defaults, because the system tints are too light for text.
  MfaThemeData toMfaTheme({Brightness? brightness}) {
    final resolved = this.brightness ?? brightness ?? Brightness.light;
    final base = MfaThemeData.fallback(resolved);
    Color pick(Color color) => color is CupertinoDynamicColor
        ? (resolved == Brightness.dark ? color.darkColor : color.color)
        : color;
    final label = pick(CupertinoColors.label);
    final secondary = pick(CupertinoColors.secondaryLabel);
    final body = textTheme.textStyle;
    return base.copyWith(
      primary: pick(primaryColor),
      onPrimary: pick(primaryContrastingColor),
      surface: pick(scaffoldBackgroundColor),
      onSurface: label,
      onSurfaceVariant: secondary,
      codeTextStyle: base.codeTextStyle.copyWith(
        fontFamily: body.fontFamily,
        color: label,
      ),
      titleTextStyle: base.titleTextStyle.copyWith(
        fontFamily: body.fontFamily,
        color: label,
      ),
      bodyTextStyle: base.bodyTextStyle.copyWith(
        fontFamily: body.fontFamily,
        color: label,
      ),
      labelTextStyle: base.labelTextStyle.copyWith(
        fontFamily: body.fontFamily,
        color: secondary,
      ),
    );
  }
}
