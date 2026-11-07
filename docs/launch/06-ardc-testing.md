# Test phase at ARDC

This is the M4-11 work, done after the merge and before publishing. It covers the parts CI cannot: real biometric hardware, human accessibility checks and hands-on security testing.

## Build the example app

```bash
cd packages/flutter_mfa/example
flutter build apk --release          # Android: install with adb install -r build/app/outputs/flutter-apk/app-release.apk
flutter build web --wasm --release   # Web: serve build/web over HTTPS (or localhost)
```

iOS builds need a Mac with Xcode and a signing team (`flutter build ios --release`, then install from Xcode). CI already runs the iOS simulator, so on iOS only the real-device biometric checks below are new.

## 1. Real-device biometrics (release-blocking)

Use at least one Android 11+ phone with a strong (Class 3) fingerprint or face sensor, one Android phone below 11, and one iPhone with Face ID or Touch ID.

| # | Check | Expected |
|---|---|---|
| B1 | Settings → "Protection levels on this device" on each phone | Android 11+ with a strong biometric and secure key hardware lists all three levels. Android below 11 lists Standard only. An iPhone with Face ID or Touch ID lists all three |
| B2 | Add an account with "Fingerprint or face for every code"; open it | A biometric prompt appears for **every** code; Cancel shows "Authentication was cancelled." and no code |
| B3 | Same, with "Fingerprint or face, secure hardware" | As B2 |
| B4 | Enrol a new fingerprint or face in the phone's settings, then open the protected account | "Biometrics changed; re-add this account from its backup." The app offers restore or removal |
| B5 | Export an encrypted backup with a protected account; restore it on the same phone after removing the account | The account comes back with its protection level; reading it prompts |
| B6 | Remove all biometrics from the phone | Protected accounts cannot produce codes; Standard accounts still work |
| B7 | iPhone without `NSFaceIDUsageDescription` (temporarily remove it from the example's Info.plist) | Face ID cannot be used; record what the app shows |

## 2. Accessibility pass 2

Follow `docs/a11y-report.md` (pass 1 lists the method). Check TalkBack (Android), VoiceOver (iOS), keyboard-only use (web), 200 % text size, and Arabic (RTL). Record pass 2 in the same report.

## 3. Dynamic security test

Run tests D1–D8 in [../security/dynamic-test-guide.md](../security/dynamic-test-guide.md) (storage, backups, clipboard, screenshots, logs, crafted input, web). Use the severity scale in that guide. Write the results to `docs/security/dynamic-test-report.md`.

## Reporting findings

- **Security vulnerabilities:** private, through `SECURITY.md`. Never in a public issue.
- **Everything else:** one GitHub issue per finding, with the device, OS version, steps, expected and actual results. Never paste real secrets, otpauth URIs, codes or backup text; use the RFC test secret from the test vectors.
- **Triage:** each finding becomes a release blocker (fix before publishing), 0.2.1, or later. Record the decision on the issue and in `docs/STATUS.md`.
