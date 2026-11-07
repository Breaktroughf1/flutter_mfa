# flutter_mfa_example

A small authenticator built only on the public APIs of `flutter_mfa`, `flutter_mfa_ui` and `flutter_mfa_qr`. It runs on Android, iOS and the web from one codebase (FR-EX-01, FR-EX-02).

- **Accounts:** live codes with a countdown (`OtpAccountList` over `MfaClient.codeStream`); tap a code to copy it to the clipboard marked sensitive, cleared after 30 s.
- **Add an account:** scan its QR code (`OtpQrScanner`) or type the setup key, time-based (TOTP) or counter-based (HOTP).
- **Account detail:** the code with its countdown, rename, remove. Counter-based codes are generated only on request, because each one uses up a counter value.
- **Relying-party demo:** plays the service side. It generates a secret with `MfaClient.createEnrollment`, shows it with `EnrollmentQrView` (the setup key is copied sensitively), and confirms the first code typed into `OtpCodeField` with the returned `TotpVerifier`. "Or add it to this app" lets you try the whole loop on one device. In production the secret and the check live on your server.
- Errors come from the typed `MfaException` hierarchy and are shown as messages (`lib/src/error_text.dart`). The widgets follow the Material theme through `toMfaTheme()` and are localized in English, Hindi and Arabic.

- **Protection:** when adding an account, by scanning or by typing the setup key, choose how it is protected; only the levels this device offers (`capabilities.supportedLevels`) are listed, and a device with only standard storage is not asked. If biometrics change and a protected account's key is invalidated, its page explains why and offers restore from backup or removal.
- **Settings:** the device's protection (hardware backing, biometrics, levels), encrypted backup export (passphrase twice, then armoured text to copy) and restore (paste, passphrase, what to do with accounts already here), and the integrity verdict from `MfaClient.checkIntegrity` (this example plugs in no detector, so it shows "Not checked").

Camera and Face ID: iOS needs the `NSCameraUsageDescription` and `NSFaceIDUsageDescription` already in `ios/Runner/Info.plist`. On the web, scanning needs HTTPS (or localhost) and, by default, a browser with a native QR decoder (see the `flutter_mfa_qr` README).

## Run

```bash
flutter run                    # Android or iOS device/simulator
flutter run -d chrome          # web (needs a secure context: localhost or HTTPS)
```

## Test

```bash
flutter test                                        # widget tests (in-memory vault)
flutter test integration_test -d <device>           # real vault on Android/iOS (touches only its own test account)
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/app_test.dart -d web-server   # real vault on the web
```

The examples use the RFC 4226/6238 test secret `GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ`. Never use it for a real account.
