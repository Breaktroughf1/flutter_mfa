import 'package:flutter/widgets.dart';

import 'generated/mfa_localizations.dart';

/// The flutter_mfa strings for [context], in English when the app has not
/// added [MfaLocalizations.delegate] or the locale is not supported, so the
/// widgets never fail for missing localizations.
MfaLocalizations mfaStrings(BuildContext context) =>
    MfaLocalizations.of(context) ?? _english;

final MfaLocalizations _english = lookupMfaLocalizations(const Locale('en'));
