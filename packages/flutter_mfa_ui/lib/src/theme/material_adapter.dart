import 'package:flutter/material.dart';

import 'mfa_theme_data.dart';

/// Derives an [MfaThemeData] from a Material [ThemeData] (ADR-0006, ADR-0013).
///
/// One of the two files allowed to import Material.
extension MfaMaterialTheme on ThemeData {
  /// An [MfaThemeData] using this theme's colour scheme and text theme.
  ///
  /// Material has no success or warning roles, so those keep the accessible
  /// defaults for the brightness.
  MfaThemeData toMfaTheme() {
    final scheme = colorScheme;
    final base = MfaThemeData.fallback(scheme.brightness);
    TextStyle style(TextStyle? from, TextStyle fallback, Color color) =>
        (from ?? fallback).copyWith(color: color);
    return base.copyWith(
      primary: scheme.primary,
      onPrimary: scheme.onPrimary,
      surface: scheme.surface,
      onSurface: scheme.onSurface,
      onSurfaceVariant: scheme.onSurfaceVariant,
      outline: scheme.outline,
      error: scheme.error,
      codeTextStyle: MfaThemeData.defaultCodeTextStyle
          .merge(textTheme.headlineMedium)
          .copyWith(
            color: scheme.onSurface,
            fontFeatures: MfaThemeData.defaultCodeTextStyle.fontFeatures,
          ),
      titleTextStyle: style(
        textTheme.titleMedium,
        base.titleTextStyle,
        scheme.onSurface,
      ),
      bodyTextStyle: style(
        textTheme.bodyMedium,
        base.bodyTextStyle,
        scheme.onSurface,
      ),
      labelTextStyle: style(
        textTheme.bodySmall,
        base.labelTextStyle,
        scheme.onSurfaceVariant,
      ),
    );
  }
}
