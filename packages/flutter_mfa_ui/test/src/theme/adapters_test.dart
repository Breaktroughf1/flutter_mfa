import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mfa_ui/cupertino.dart';
import 'package:flutter_mfa_ui/flutter_mfa_ui.dart';
import 'package:flutter_mfa_ui/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Material adapter', () {
    for (final brightness in Brightness.values) {
      test('maps the ${brightness.name} colour scheme and text theme', () {
        final material = ThemeData(
          colorSchemeSeed: Colors.teal,
          brightness: brightness,
        );
        final theme = material.toMfaTheme();
        final scheme = material.colorScheme;
        expect(theme.brightness, brightness);
        expect(theme.primary, scheme.primary);
        expect(theme.onPrimary, scheme.onPrimary);
        expect(theme.surface, scheme.surface);
        expect(theme.onSurface, scheme.onSurface);
        expect(theme.onSurfaceVariant, scheme.onSurfaceVariant);
        expect(theme.outline, scheme.outline);
        expect(theme.error, scheme.error);
        final fallback = MfaThemeData.fallback(brightness);
        expect(theme.success, fallback.success);
        expect(theme.warning, fallback.warning);
        expect(theme.codeTextStyle.color, scheme.onSurface);
        expect(
          theme.codeTextStyle.fontFeatures,
          MfaThemeData.defaultCodeTextStyle.fontFeatures,
        );
        expect(
          theme.titleTextStyle.fontSize,
          material.textTheme.titleMedium!.fontSize,
        );
        expect(theme.labelTextStyle.color, scheme.onSurfaceVariant);
      });
    }
  });

  group('Cupertino adapter', () {
    test('resolves dynamic colours for the brightness', () {
      const cupertino = CupertinoThemeData(
        primaryColor: CupertinoColors.systemBlue,
      );
      final light = cupertino.toMfaTheme();
      final dark = cupertino.toMfaTheme(brightness: Brightness.dark);
      expect(light.brightness, Brightness.light);
      expect(light.primary, CupertinoColors.systemBlue.color);
      expect(dark.primary, CupertinoColors.systemBlue.darkColor);
      expect(light.onSurface, CupertinoColors.label.color);
      expect(dark.onSurface, CupertinoColors.label.darkColor);
      expect(light.labelTextStyle.color, CupertinoColors.secondaryLabel.color);
      expect(dark.surface, isNot(light.surface));
      expect(light.outline, MfaThemeData.light().outline);
      expect(dark.error, MfaThemeData.dark().error);
    });

    test("the theme's own brightness wins and plain colours pass through", () {
      const cupertino = CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: Color(0xFF123456),
      );
      final theme = cupertino.toMfaTheme(brightness: Brightness.light);
      expect(theme.brightness, Brightness.dark);
      expect(theme.primary, const Color(0xFF123456));
      expect(
        theme.bodyTextStyle.fontFamily,
        cupertino.textTheme.textStyle.fontFamily,
      );
    });
  });
}
