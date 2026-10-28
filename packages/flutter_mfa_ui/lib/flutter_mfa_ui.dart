/// Accessible widgets for multi-factor authentication, built on the Flutter
/// widgets layer.
///
/// Independent of Material and Cupertino (ADR-0006). Style them with
/// [MfaTheme]; adapters live in `package:flutter_mfa_ui/material.dart` and
/// `package:flutter_mfa_ui/cupertino.dart`.
///
/// Add [MfaLocalizations.delegate] to your app's `localizationsDelegates` for
/// Hindi and Arabic; without it the widgets use English.
library;

import 'src/l10n/generated/mfa_localizations.dart';
import 'src/theme/mfa_theme.dart';

export 'src/l10n/generated/mfa_localizations.dart';
export 'src/theme/mfa_theme.dart';
export 'src/theme/mfa_theme_data.dart';
