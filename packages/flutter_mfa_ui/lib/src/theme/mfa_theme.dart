import 'package:flutter/widgets.dart';

import 'mfa_theme_data.dart';

/// Provides [MfaThemeData] to the flutter_mfa widgets below it.
///
/// Without an ancestor [MfaTheme], widgets use [MfaThemeData.fallback] for
/// the platform brightness, so they are usable with no setup.
class MfaTheme extends InheritedWidget {
  /// Applies [data] to [child].
  const MfaTheme({super.key, required this.data, required super.child});

  /// The theme for the subtree.
  final MfaThemeData data;

  /// The nearest theme, or the default for the platform brightness.
  static MfaThemeData of(BuildContext context) =>
      maybeOf(context) ??
      MfaThemeData.fallback(
        MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.light,
      );

  /// The nearest theme, or `null` if there is no [MfaTheme] ancestor.
  static MfaThemeData? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MfaTheme>()?.data;

  @override
  bool updateShouldNotify(MfaTheme oldWidget) => data != oldWidget.data;
}
