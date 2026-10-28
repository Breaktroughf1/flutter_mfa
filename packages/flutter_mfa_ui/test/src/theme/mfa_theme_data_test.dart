import 'package:flutter/widgets.dart';
import 'package:flutter_mfa_ui/flutter_mfa_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/contrast.dart';

void main() {
  for (final theme in [MfaThemeData.light(), MfaThemeData.dark()]) {
    group('${theme.brightness.name} defaults meet WCAG AA (FR-UI-08)', () {
      final textColours = {
        'onSurface': theme.onSurface,
        'onSurfaceVariant': theme.onSurfaceVariant,
        'primary': theme.primary,
        'error': theme.error,
        'success': theme.success,
        'warning': theme.warning,
      };
      for (final MapEntry(:key, :value) in textColours.entries) {
        test('$key has at least 4.5:1 contrast on surface', () {
          expect(
            contrastRatio(value, theme.surface),
            greaterThanOrEqualTo(4.5),
          );
        });
      }
      test('onPrimary has at least 4.5:1 contrast on primary', () {
        expect(
          contrastRatio(theme.onPrimary, theme.primary),
          greaterThanOrEqualTo(4.5),
        );
      });
      test('outline has at least 3:1 contrast on surface', () {
        expect(
          contrastRatio(theme.outline, theme.surface),
          greaterThanOrEqualTo(3),
        );
      });
      test('text styles use the theme colours', () {
        expect(theme.codeTextStyle.color, theme.onSurface);
        expect(theme.titleTextStyle.color, theme.onSurface);
        expect(theme.bodyTextStyle.color, theme.onSurface);
        expect(theme.labelTextStyle.color, theme.onSurfaceVariant);
        expect(theme.codeTextStyle.fontFeatures, isNotEmpty);
      });
    });
  }

  test('fallback picks the palette for the brightness', () {
    expect(MfaThemeData.fallback(Brightness.dark), MfaThemeData.dark());
    expect(MfaThemeData.fallback(Brightness.light), MfaThemeData.light());
    expect(MfaThemeData.light(), isNot(MfaThemeData.dark()));
  });

  test('metrics default to accessible sizes', () {
    final theme = MfaThemeData.light();
    expect(theme.minTapTarget, 48);
    expect(theme.radius, 12);
    expect(theme.spacing, 8);
  });

  test('copyWith replaces each field and keeps the rest', () {
    final base = MfaThemeData.light();
    expect(base.copyWith(), base);
    expect(base.copyWith().hashCode, base.hashCode);
    const red = Color(0xFFFF0000);
    const style = TextStyle(fontSize: 1);
    final changed = [
      base.copyWith(brightness: Brightness.dark),
      base.copyWith(primary: red),
      base.copyWith(onPrimary: red),
      base.copyWith(surface: red),
      base.copyWith(onSurface: red),
      base.copyWith(onSurfaceVariant: red),
      base.copyWith(outline: red),
      base.copyWith(error: red),
      base.copyWith(success: red),
      base.copyWith(warning: red),
      base.copyWith(codeTextStyle: style),
      base.copyWith(titleTextStyle: style),
      base.copyWith(bodyTextStyle: style),
      base.copyWith(labelTextStyle: style),
      base.copyWith(radius: 1),
      base.copyWith(spacing: 1),
      base.copyWith(minTapTarget: 1),
    ];
    for (final theme in changed) {
      expect(theme, isNot(base));
    }
    expect(changed.toSet(), hasLength(changed.length));
  });

  test('describes itself for the widget inspector', () {
    final description = MfaThemeData.light().toString();
    expect(description, contains('brightness: light'));
    expect(description, contains('minTapTarget: 48.0'));
  });
}
