# Changelog

All notable changes to this package are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this package uses
[Semantic Versioning](https://semver.org) (0.x: a minor bump may break).

## Unreleased

- `MfaClient.setScreenCaptureProtection`: hides the app from screenshots and
  the recent-apps preview on Android (`FLAG_SECURE`); no-op on iOS and the
  web, as `capabilities.screenCaptureProtection` reports (FR-FAC-06).

- Device integrity hook: `DeviceIntegrityCheck`, `NoopIntegrityCheck`,
  `IntegrityReport`, `IntegrityVerdict`, `IntegrityPolicy` and
  `MfaClient.checkIntegrity`; `create` applies the policy (FR-FAC-03).

- iOS: `biometric` (Keychain item with `.biometryCurrentSet`) and
  `hardwareBound` (Secure Enclave key wrapping the secret) protection; saving
  never prompts, re-enrolment gives `VaultKeyInvalidated` (FR-VLT-05/06).
  Apps need `NSFaceIDUsageDescription`.

- Android: `biometric` and `hardwareBound` protection (API 30+): per-account
  Keystore keys unlocked by a strong biometric through `BiometricPrompt` and
  a `CryptoObject` for every read; StrongBox for `hardwareBound` when present;
  new biometric enrolments invalidate the keys (`VaultKeyInvalidated`). Works
  with any host activity (FR-VLT-05/06).

- `MfaClient.exportEncrypted` / `importEncrypted` with `DuplicateStrategy`
  and `ImportReport`: encrypted backups (format v1), all-or-nothing import,
  key derivation off the UI thread (FR-BAK-03).

- `MfaClient.codeStream` (live TOTP codes, secret read once per subscription),
  `copyCode` and `copySensitive` (sensitive clipboard with expiry). All live
  streams of a client share one timer.
- `MfaClient.createEnrollment` returns a `RelyingPartyEnrollment`: a new
  secret, its `otpauth://` URI and a `TotpVerifier` for confirming the
  user's first code.

- iOS: the vault is wiped on the first launch after an install, so a
  reinstalled app does not regain an earlier installation's accounts
  (ADR-0012). **Upgrade note:** builds taken from git before this change
  have no install marker, so their first launch on this version also wipes
  the vault. No published version is affected; the first release ships
  with the marker.

## 0.1.0-dev.1

- Initial package skeleton (not yet published).
