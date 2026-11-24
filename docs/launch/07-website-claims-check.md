# Website claims check (24 November 2026)

Every claim on breaktroughf1.com about Flutter MFA (case study `/projects/flutter-mfa`, `/open-source`, `/llms.txt`, the JSON-LD and the blog post *Designing multi-factor authentication users don't hate*), checked against the code on `main` after the 0.3.0 changes. "True" means the packages do it today. "Fix copy" means no code change can make the sentence true, so the website wording has to change; the replacement text is given.

## Already true (keep)

| Claim | Evidence |
|---|---|
| TOTP and HOTP (RFC 6238 / 4226) with `otpauth://` enrolment | `flutter_mfa_core` HOTP/TOTP with every RFC test vector; `OtpAuthUri` |
| Optional biometric-bound protection: no code without a fresh biometric check | Android 11+: per-entry Keystore RSA key that needs a Class 3 biometric for every use (`setUserAuthenticationParameters(0, BIOMETRIC_STRONG)`). iOS: Keychain item with `biometryCurrentSet`, optional Secure Enclave wrap. Not available on the web (and the site does not claim it there) |
| Server-side verification with replay protection and attempt limiting | `TotpVerifier`, `HotpVerifier`, `AttemptLimiter`, `AtomicAttemptStore` (ADR-0014) |
| Encrypted backup export and import (AES-256-GCM, PBKDF2) | `BackupCodec` v1: PBKDF2-HMAC-SHA256 600 000 iterations, AES-256-GCM, frozen known-answer fixture |
| Accessible, design-system independent widgets with Hindi and Arabic translations | `flutter_mfa_ui`; WCAG checks and goldens. The Hindi and Arabic strings are first drafts awaiting native-speaker review (STATUS M2-02); fine to list, but say "Hindi and Arabic" rather than "fully translated" |
| Five packages on pub.dev under the verified `breaktroughf1.com` publisher, MIT | pub.dev |
| Android API 24+, biometric levels on API 30+; iOS 15+ with `NSFaceIDUsageDescription`; web in a secure context | Package READMEs and platform code |
| Threat model, ADRs, cookbook guides and an example app in the repository | `docs/security/threat-model.md`, `docs/adr/`, `docs/cookbook/`, `packages/flutter_mfa/example/` |
| QR scanner: no remote decoder on the web unless you opt in | `OtpQrWebOptions` (`allowRemoteDecoder`, `decoderScriptUrl`) |
| Version, downloads, pub points, GitHub stars | Pulled live, as planned in [04-live-metrics.md](04-live-metrics.md) |

## Made true by this release (0.3.0)

| Claim | What changed |
|---|---|
| "Each package scores 150 to 160 of 160 pub points" | `flutter_mfa_ui` was 140/160 on Flutter 3.50. 0.3.0 fixes both findings (`qr` 4; `material_ui`/`cupertino_ui`), confirmed by a local pana run (50/50 analysis, 40/40 dependencies). After publishing, use the live numbers and say "160/160" only while they show it. |
| "Releases ship from GitHub Actions" | Only `flutter_mfa` published from Actions. `publish.yml` now publishes all five packages from their tags. Each package's pub.dev Admin tab still needs automated publishing enabled (runbook §D, 0.3.0). |

## Fix copy

| Where | Current text | Problem | Replacement |
|---|---|---|---|
| Description (case study, open-source card, plugin card, JSON-LD, `llms.txt`) | "secrets kept in hardware-backed platform vaults (Android Keystore, iOS Keychain, WebCrypto)" | WebCrypto keys are not hardware-backed (the web vault keeps a non-extractable key in IndexedDB) | "secrets kept in the platform's secure storage (Android Keystore and iOS Keychain, hardware-backed; a non-extractable WebCrypto key on the web)" |
| Key features | "Secrets in Android Keystore (StrongBox), iOS Keychain (Secure Enclave) and non-extractable WebCrypto keys" | StrongBox is used only where the device has it; the Secure Enclave is used for hardware-bound accounts, not every account | "Secrets in Android Keystore (StrongBox where available), the iOS Keychain (Secure Enclave for hardware-bound accounts) and non-extractable WebCrypto keys on the web" |
| Our approach 02 | "…are excluded from backups, and can be bound to biometrics…" | True on Android and iOS; the web has neither | "…are excluded from device backups on Android and iOS, and can be bound to biometrics there…" |
| Our approach 01 | "One audited core, used on both sides" | No third-party audit has been completed (the ARDC dynamic test is pending) | "One core, used on both sides" (say "audited" only after an external audit report is published) |
| Key features; The outcome | "No network requests and no telemetry" / "The packages make no network requests and collect no telemetry." | True for core, platform interface, plugin and UI. The optional QR scanner uses Google ML Kit on Android, which can send usage and performance metrics to Google (stated in the `flutter_mfa_qr` README), and loads a web decoder from a CDN if the app opts in | "The core, plugin and UI packages make no network requests and collect no telemetry. The optional QR scanner uses Google's on-device ML Kit on Android." |
| Requirements | "Dart 3.9 and Flutter 3.35 or later" | 0.3.0 requires Dart 3.13 / Flutter 3.47 (ADR-0015) | "Dart 3.13 and Flutter 3.47 or later" (on 0.3.0 publish day) |
| JSON-LD | `"operatingSystem": "All"` | Desktop is not supported | `"operatingSystem": "Android, iOS, Web"` |
| Blog post, "How Flutter MFA will help" | "…bundle passkeys, biometrics, TOTP, OTP and backup codes behind one API…" and "one API for every second factor" | Passkeys, SMS/email OTP and backup (recovery) codes are not in any package | Use the replacement paragraph in [02-website-copy.md](02-website-copy.md#blog-post-replacement-for-how-flutter-mfa-will-help), and change the callout to "Flutter MFA: authenticator codes, kept in the device's secure hardware" |

## Not in the packages (keep off the website unless built)

Passkeys (FIDO2/WebAuthn), push approvals, SMS or email one-time codes, backup/recovery codes, and desktop support. Each would be a new feature with its own requirements, security design and ADR. Recovery codes are the smallest (pure Dart, server side, in `flutter_mfa_core`) and the most useful next step for "design recovery like a first-class flow", which the blog post recommends. Passkeys need native platform work on Android, iOS and the web.
