import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Colours, text styles and metrics used by every flutter_mfa widget.
///
/// Independent of any design system (ADR-0006): build one directly, start
/// from [MfaThemeData.light] / [MfaThemeData.dark], or derive one from a
/// Material or Cupertino theme with the adapters in
/// `package:flutter_mfa_ui/material.dart` and
/// `package:flutter_mfa_ui/cupertino.dart`.
///
/// The default palettes meet WCAG 2.1 AA: every text colour has at least
/// 4.5:1 contrast against [surface], and [outline] at least 3:1 (FR-UI-08).
@immutable
final class MfaThemeData with Diagnosticable {
  /// Creates a theme from explicit values.
  const MfaThemeData({
    required this.brightness,
    required this.primary,
    required this.onPrimary,
    required this.surface,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
    required this.error,
    required this.success,
    required this.warning,
    required this.codeTextStyle,
    required this.titleTextStyle,
    required this.bodyTextStyle,
    required this.labelTextStyle,
    this.radius = 12,
    this.spacing = 8,
    this.minTapTarget = 48,
  });

  /// The default light theme.
  factory MfaThemeData.light() => _fromPalette(
    brightness: Brightness.light,
    primary: const Color(0xFF3949AB),
    onPrimary: const Color(0xFFFFFFFF),
    surface: const Color(0xFFFFFFFF),
    onSurface: const Color(0xFF1B1B1F),
    onSurfaceVariant: const Color(0xFF46464F),
    outline: const Color(0xFF767680),
    error: const Color(0xFFBA1A1A),
    success: const Color(0xFF1E6B2E),
    warning: const Color(0xFF8A5100),
  );

  /// The default dark theme.
  factory MfaThemeData.dark() => _fromPalette(
    brightness: Brightness.dark,
    primary: const Color(0xFFBAC3FF),
    onPrimary: const Color(0xFF08218A),
    surface: const Color(0xFF121318),
    onSurface: const Color(0xFFE4E1E6),
    onSurfaceVariant: const Color(0xFFC7C5D0),
    outline: const Color(0xFF91909A),
    error: const Color(0xFFFFB4AB),
    success: const Color(0xFF8BD88F),
    warning: const Color(0xFFFFB870),
  );

  /// The default theme for [brightness].
  factory MfaThemeData.fallback(Brightness brightness) =>
      brightness == Brightness.dark
      ? MfaThemeData.dark()
      : MfaThemeData.light();

  static MfaThemeData _fromPalette({
    required Brightness brightness,
    required Color primary,
    required Color onPrimary,
    required Color surface,
    required Color onSurface,
    required Color onSurfaceVariant,
    required Color outline,
    required Color error,
    required Color success,
    required Color warning,
  }) => MfaThemeData(
    brightness: brightness,
    primary: primary,
    onPrimary: onPrimary,
    surface: surface,
    onSurface: onSurface,
    onSurfaceVariant: onSurfaceVariant,
    outline: outline,
    error: error,
    success: success,
    warning: warning,
    codeTextStyle: defaultCodeTextStyle.copyWith(color: onSurface),
    titleTextStyle: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.4,
      color: onSurface,
    ),
    bodyTextStyle: TextStyle(fontSize: 14, height: 1.4, color: onSurface),
    labelTextStyle: TextStyle(
      fontSize: 12,
      height: 1.4,
      color: onSurfaceVariant,
    ),
  );

  /// The base style for one-time codes: large, tabular figures so digits do
  /// not shift as they change. Colour is set by the theme.
  static const defaultCodeTextStyle = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    letterSpacing: 2,
    height: 1.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Whether the theme is light or dark.
  final Brightness brightness;

  /// Accent for focus rings, progress and primary actions.
  final Color primary;

  /// Content drawn on [primary].
  final Color onPrimary;

  /// Background of widgets such as tiles and code fields.
  final Color surface;

  /// Main content colour on [surface] (codes, titles).
  final Color onSurface;

  /// Secondary content colour on [surface] (labels, hints).
  final Color onSurfaceVariant;

  /// Borders and dividers; at least 3:1 against [surface].
  final Color outline;

  /// Errors and invalid states.
  final Color error;

  /// Positive states (enrolled).
  final Color success;

  /// Cautions (code about to expire, integrity warnings).
  final Color warning;

  /// Style of one-time code digits.
  final TextStyle codeTextStyle;

  /// Style of titles such as an account's issuer.
  final TextStyle titleTextStyle;

  /// Style of body text and messages.
  final TextStyle bodyTextStyle;

  /// Style of small secondary text.
  final TextStyle labelTextStyle;

  /// Corner radius of boxes, in logical pixels.
  final double radius;

  /// Base spacing unit, in logical pixels.
  final double spacing;

  /// Minimum size of tap targets, in logical pixels (48 per Android and WCAG
  /// guidance; iOS recommends 44).
  final double minTapTarget;

  /// A copy with the given fields replaced.
  MfaThemeData copyWith({
    Brightness? brightness,
    Color? primary,
    Color? onPrimary,
    Color? surface,
    Color? onSurface,
    Color? onSurfaceVariant,
    Color? outline,
    Color? error,
    Color? success,
    Color? warning,
    TextStyle? codeTextStyle,
    TextStyle? titleTextStyle,
    TextStyle? bodyTextStyle,
    TextStyle? labelTextStyle,
    double? radius,
    double? spacing,
    double? minTapTarget,
  }) => MfaThemeData(
    brightness: brightness ?? this.brightness,
    primary: primary ?? this.primary,
    onPrimary: onPrimary ?? this.onPrimary,
    surface: surface ?? this.surface,
    onSurface: onSurface ?? this.onSurface,
    onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
    outline: outline ?? this.outline,
    error: error ?? this.error,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    codeTextStyle: codeTextStyle ?? this.codeTextStyle,
    titleTextStyle: titleTextStyle ?? this.titleTextStyle,
    bodyTextStyle: bodyTextStyle ?? this.bodyTextStyle,
    labelTextStyle: labelTextStyle ?? this.labelTextStyle,
    radius: radius ?? this.radius,
    spacing: spacing ?? this.spacing,
    minTapTarget: minTapTarget ?? this.minTapTarget,
  );

  @override
  bool operator ==(Object other) =>
      other is MfaThemeData &&
      other.brightness == brightness &&
      other.primary == primary &&
      other.onPrimary == onPrimary &&
      other.surface == surface &&
      other.onSurface == onSurface &&
      other.onSurfaceVariant == onSurfaceVariant &&
      other.outline == outline &&
      other.error == error &&
      other.success == success &&
      other.warning == warning &&
      other.codeTextStyle == codeTextStyle &&
      other.titleTextStyle == titleTextStyle &&
      other.bodyTextStyle == bodyTextStyle &&
      other.labelTextStyle == labelTextStyle &&
      other.radius == radius &&
      other.spacing == spacing &&
      other.minTapTarget == minTapTarget;

  @override
  int get hashCode => Object.hash(
    brightness,
    primary,
    onPrimary,
    surface,
    onSurface,
    onSurfaceVariant,
    outline,
    error,
    success,
    warning,
    codeTextStyle,
    titleTextStyle,
    bodyTextStyle,
    labelTextStyle,
    radius,
    spacing,
    minTapTarget,
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty<Brightness>('brightness', brightness))
      ..add(ColorProperty('primary', primary))
      ..add(ColorProperty('surface', surface))
      ..add(ColorProperty('onSurface', onSurface))
      ..add(DoubleProperty('radius', radius))
      ..add(DoubleProperty('minTapTarget', minTapTarget));
  }
}
