# Enrol users in two-factor sign-in (relying party)

You run a service and want your users to turn on authenticator codes. The flow:

1. Your **server** generates a secret and its `otpauth://` URI.
2. Your **app** shows the URI as a QR code, with the setup key for typing.
3. The user scans it with any authenticator app (Google Authenticator, Microsoft Authenticator, 1Password, or one built with flutter_mfa).
4. The user types the first code. Your **server** checks it, and only then turns two-factor sign-in on.

The secret and the check stay on the server ([Verify on a Dart server](verify-on-a-dart-server.md)); the app only displays what the server sends.

## Show the QR code

```dart
import 'package:flutter_mfa/flutter_mfa.dart';
import 'package:flutter_mfa_ui/flutter_mfa_ui.dart';

// The URI string your server returned over TLS.
final uri = OtpAuthUri.parse(uriFromServer);

EnrollmentQrView(
  uri: uri,
  // Optional: offer copying the setup key, marked sensitive and cleared
  // after a while.
  onCopySecret: client.copySensitive,
)
```

`EnrollmentQrView` draws the code dark on light with the quiet zone scanners need, shows the setup key in groups of four, and always shows a privacy warning. The copy button appears only when you pass `onCopySecret`, because the widget can't mark the clipboard sensitive by itself. Consider blocking screenshots of this screen (for example Android's `FLAG_SECURE`).

## Confirm the first code

```dart
OtpCodeField(
  onCompleted: (code) async {
    final ok = await api.confirmEnrolment(code); // your server checks it
    setState(() => error = ok ? null : 'That code is not right. Check the time on your device.');
  },
  errorText: error,
)
```

`OtpCodeField` accepts digits only, supports paste and one-time-code autofill, opens the numeric keyboard, and announces errors to screen readers.

## Interoperability

- Keep the defaults: SHA-1, 6 digits, 30 seconds. Other values produce `OtpAuthUri.compatibilityWarnings`, because several popular apps silently ignore them and then show wrong codes.
- The issuer (your service name) must not contain a colon.
- Generated secrets are 20 bytes (32 Base32 characters), long enough for every app.

## Try it without a server

`MfaClient.createEnrollment(issuer: …, accountName: …)` performs the server's step on the device and returns the URI with a `TotpVerifier`. It is meant for demos and tests: a check on the user's own device is not a second factor. The example app's **relying-party demo** screen walks through the whole flow with it.
