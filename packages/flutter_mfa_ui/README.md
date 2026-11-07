# flutter_mfa_ui

Widgets for [flutter_mfa](https://github.com/Breaktroughf1/flutter_mfa): OTP code field, code display with countdown, account list, enrolment QR and status badges. Built on the widgets layer, independent of Material or Cupertino, accessible and localisable.

> **Status:** in development towards v0.2.0. Not yet published. APIs may change.

Built and maintained by **BreaktroughF1 LLP** in collaboration with **ARDC, CHRIST (Deemed to be University)**. MIT licensed.

Security model and design: see the [project docs](https://github.com/Breaktroughf1/flutter_mfa/tree/main/docs).

<p>
  <img src="https://raw.githubusercontent.com/Breaktroughf1/flutter_mfa/main/packages/flutter_mfa_ui/test/goldens/images/gallery_light.png" width="260" alt="The widgets in the light theme">
  <img src="https://raw.githubusercontent.com/Breaktroughf1/flutter_mfa/main/packages/flutter_mfa_ui/test/goldens/images/gallery_dark.png" width="260" alt="The widgets in the dark theme">
  <img src="https://raw.githubusercontent.com/Breaktroughf1/flutter_mfa/main/packages/flutter_mfa_ui/test/goldens/images/gallery_ar_rtl.png" width="260" alt="The widgets in Arabic, right to left">
</p>

## Widgets

| Widget | What it does |
|---|---|
| `OtpCodeField` | Code entry drawn as digit boxes, exposed to assistive technology as one labelled text field. Accepts digits only (pasting `Code: 123 456` works), supports one-time-code autofill and the numeric keyboard, and announces errors. |
| `OtpCodeDisplay` | A code grouped for reading (`123 456`), read digit by digit by screen readers, with tap to copy and a hidden mode. |
| `OtpCountdownRing` | Time left until the code changes, as a ring and as text for screen readers. |
| `OtpAccountTile`, `OtpAccountList` | Accounts with live codes, driven by `MfaClient.watchAccounts()` and `MfaClient.codeStream`. |
| `EnrollmentQrView` | An enrolment QR code with the grouped setup key, an opt-in copy button and a privacy warning. |
| `MfaStatusBadge` | Enrolled, not enrolled, locked, needs re-enrolment or device-check warning, as icon and text (never colour alone). |

## Theming

The widgets use only the widgets layer, so they fit any design system. Pass an `MfaTheme`, or map your existing theme:

```dart
import 'package:flutter_mfa_ui/material.dart';   // ThemeData.toMfaTheme()
import 'package:flutter_mfa_ui/cupertino.dart';  // CupertinoThemeData.toMfaTheme()

MaterialApp(
  builder: (context, child) =>
      MfaTheme(data: Theme.of(context).toMfaTheme(), child: child!),
)
```

Without an `MfaTheme` the widgets use light or dark defaults that meet WCAG AA contrast.

## Localization and accessibility

- English, Hindi and Arabic (right to left). Add `MfaLocalizations.delegate` (or `MfaLocalizations.localizationsDelegates`); without it the widgets use English. `mfaStrings(context)` gives custom builders the same strings.
- Every interactive part has a label, a 48 dp tap target and its own semantics node. Codes are read digit by digit and errors are announced.
- Text scales to 200% without clipping. The golden tests cover light, dark, Arabic, Hindi and 200% text.

Guides: [Add an authenticator to your app](https://github.com/Breaktroughf1/flutter_mfa/blob/main/docs/cookbook/add-an-authenticator.md) · [Enrol users (relying party)](https://github.com/Breaktroughf1/flutter_mfa/blob/main/docs/cookbook/enrol-users.md).
