# Website copy (0.2.0)

Every line matches the code on `main`; snippets come from the package READMEs. Apply on publish day, together with the live numbers from [04-live-metrics.md](04-live-metrics.md). Update `/llms.txt` and the open-source page too: they repeat the old description.

## Meta description (≤ 160 characters; also Open Graph, Twitter, llms.txt)

> Open-source TOTP/HOTP multi-factor authentication for Flutter: hardware-backed secret storage, biometric protection, QR enrolment and a Dart server verifier.

## Page description

> Flutter MFA is an open-source (MIT) toolkit for time-based and counter-based one-time passwords (TOTP/HOTP, RFC 6238 and 4226) in Flutter apps on Android, iOS and the web. It keeps secrets in the platform's secure hardware (Android Keystore and StrongBox, iOS Keychain and Secure Enclave, WebCrypto on the web), can require a fingerprint or face check for every code, scans otpauth:// QR codes, and backs up accounts with passphrase encryption. The same audited Dart code verifies codes on your server, with replay protection and attempt limiting. Built by BreaktroughF1 LLP with ARDC, CHRIST (Deemed to be University).

## Key features

- TOTP and HOTP, verified against every RFC test vector
- Secrets in hardware-backed storage, never in plain files
- Optional fingerprint or face check for every code
- Scan or type otpauth:// enrolments; show enrolment QR codes
- Encrypted backup and restore (PBKDF2 + AES-256-GCM)
- Server verifier with replay protection and attempt limits
- Accessible widgets in English, Hindi and Arabic (RTL)
- No network requests, no telemetry

## Requirements

- Flutter 3.35 or later, Dart 3.9 or later
- Android 7.0 (API 24) or later (biometric protection: Android 11+, Class 3 biometric)
- iOS 15 or later (biometric protection: add `NSFaceIDUsageDescription` to Info.plist)
- Web: HTTPS or localhost (secure context)
- Server verification: any Dart backend

## Installation tab

```sh
flutter pub add flutter_mfa flutter_mfa_ui   # app: secure vault, codes, widgets
flutter pub add flutter_mfa_qr              # optional QR scanner
dart pub add flutter_mfa_core               # Dart server: code verification
```

## Usage tab: in the app

```dart
import 'package:flutter_mfa/flutter_mfa.dart';

final client = await MfaClient.create();

// Add an account from a scanned otpauth:// URI.
final account = await client.enrollFromUri(otpauthUri);

// Live codes: now, every second, and at each change.
client.codeStream(account.id).listen(showCode);

// Copy to the sensitive clipboard (cleared after 30 s).
await client.copyCode(account.id);
```

## Usage tab: on your server

```dart
import 'package:flutter_mfa_core/flutter_mfa_core.dart';

final verifier = TotpVerifier(
  totp: Totp(OtpSecret.fromBytes(user.secretBytes)),
  limiter: AttemptLimiter(store: sharedAttemptStore),
);

final result = await verifier.verify(code,
    subject: user.id, lastUsedStep: user.lastStep);
if (result case Accepted(:final nextState)) {
  await users.saveLastStep(user.id, nextState);
}
```

## Packages

| Package | What it is |
|---|---|
| `flutter_mfa_core` | Pure Dart: OTP generation, verification with replay protection and throttling, otpauth URIs, Base32, encrypted backup format. Runs on servers |
| `flutter_mfa` | The Flutter plugin: `MfaClient`, secure vault (Keystore / Keychain / WebCrypto), biometric-bound protection, sensitive clipboard |
| `flutter_mfa_ui` | Widgets: code field, code display with countdown, account list, enrolment QR, status badges. Accessible and localised |
| `flutter_mfa_qr` | Optional camera scanner for `otpauth://` QR codes |
| `flutter_mfa_platform_interface` | Platform interface for vault implementations |

## Links

| Label | URL |
|---|---|
| View on pub.dev | https://pub.dev/packages/flutter_mfa |
| Source on GitHub | https://github.com/Breaktroughf1/flutter_mfa |
| API docs | https://pub.dev/documentation/flutter_mfa/latest/ |
| Example app | https://github.com/Breaktroughf1/flutter_mfa/tree/main/packages/flutter_mfa/example |
| Security policy | https://github.com/Breaktroughf1/flutter_mfa/blob/main/SECURITY.md |
| Docs | the docs section from [03-docs-section-plan.md](03-docs-section-plan.md) |

## Case study

- **Client:** Open source, with ARDC, CHRIST (Deemed to be University)
- **Licence:** MIT
- **Version:** live from pub.dev (0.2 at launch, first public release)

**The challenge.** Flutter apps that offer authenticator codes had to combine separate packages for code generation, secure storage, QR scanning and UI, each with its own security model, and then write their own server checks.

**Our approach.**
1. *One toolkit, one security model.* Five small packages: a pure-Dart core that also runs on your server, the plugin with hardware-backed storage, accessible widgets, an optional QR scanner and a platform interface.
2. *Secure by default.* Hardware-backed storage, optional biometric binding, replay protection and attempt limits, encrypted backups.
3. *Docs and examples.* Guides for authenticator apps, user enrolment and server verification, plus a full example app.

**The outcome.** Teams add authenticator codes to Flutter apps, and verify them on a Dart server, with one audited codebase.

**Security note (one line on the page).** On the web the vault is best-effort: script running in your own origin can use the key, so use a strict Content Security Policy and prefer the mobile apps for high-value accounts.

## JSON-LD `SoftwareApplication`

```json
{
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  "name": "Flutter MFA",
  "softwareVersion": "<live from pub.dev>",
  "operatingSystem": "Android, iOS, Web",
  "applicationCategory": "DeveloperApplication",
  "license": "https://opensource.org/licenses/MIT",
  "codeRepository": "https://github.com/Breaktroughf1/flutter_mfa",
  "programmingLanguage": "Dart",
  "offers": { "@type": "Offer", "price": "0", "priceCurrency": "USD" },
  "featureList": "TOTP and HOTP, hardware-backed secret storage, biometric protection, QR enrolment, encrypted backup, server verifier"
}
```

Do not add `aggregateRating`: pub.dev has no ratings to cite.

## Blog post: replacement for "How Flutter MFA will help"

> Flutter MFA puts the authenticator side of this article into one toolkit: TOTP and HOTP codes generated from secrets kept in the device's secure hardware, an optional fingerprint or face check for every code, QR enrolment, encrypted backups for moving to a new phone, and a Dart verifier with replay protection and attempt limits for your server. It is open source (MIT) and on pub.dev.
