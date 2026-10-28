# 01 — Product Requirements (v0.2.0)

Every requirement has an ID. Commits, PRs, tests and the release checklist reference these IDs. A requirement is **done** only when every acceptance criterion (AC) has a passing automated test, unless the AC says "manual".

Priority: **M** = must ship in 0.2.0 · **S** = should (ship if green by M4) · **C** = could (post-0.2).

---

## 1. Users and use cases

| Persona | Wants | Primary package |
|---|---|---|
| **App developer — authenticator** | Add a built-in authenticator to their app (store seeds, show rolling codes, scan QR) | `flutter_mfa` + `flutter_mfa_ui` + `flutter_mfa_qr` |
| **App developer — relying party** | Enrol users into TOTP: generate secret, show QR, confirm first code | `flutter_mfa_core` (client) + server |
| **Backend developer (Dart)** | Verify codes server-side with replay protection and throttling | `flutter_mfa_core` only |
| **End user** | Fast, accessible code entry; never lose their factors; nothing leaks | Example app |

Core use cases: UC1 enrol by scanning QR · UC2 enrol by manual entry · UC3 view/copy current code · UC4 relying-party enrolment (generate secret + QR + confirm) · UC5 verify a submitted code (server) · UC6 encrypted backup & restore · UC7 biometric-protected account · UC8 remove account.

---

## 2. Functional requirements

### 2.1 OTP engine — `flutter_mfa_core`

| ID | P | Requirement | Acceptance criteria |
|---|---|---|---|
| FR-OTP-01 | M | HOTP per RFC 4226 (HMAC + dynamic truncation) | AC1 All 10 RFC 4226 Appendix D vectors pass. AC2 Digits 6, 7, 8 supported; others rejected with `ArgumentError`. AC3 Counter is a 64-bit unsigned big-endian value; counters up to 2^53−1 supported on web (JS number limit) with documented ceiling. |
| FR-OTP-02 | M | TOTP per RFC 6238 | AC1 All 18 RFC 6238 Appendix B vectors pass (SHA1/256/512 × 6 times) using the RFC's per-algorithm seed lengths. AC2 `T0` and `period` configurable; default T0 = 0, period = 30 s. AC3 Time source injectable (`Clock`). |
| FR-OTP-03 | M | Algorithms SHA-1, SHA-256, SHA-512 | AC1 Enum `OtpAlgorithm`; default SHA-1 for compatibility. |
| FR-OTP-04 | M | Base32 (RFC 4648) codec | AC1 RFC 4648 §10 test vectors pass. AC2 Decoder accepts lower case, ignores spaces/hyphens, accepts missing padding. AC3 Encoder emits upper case, **no** padding (otpauth convention). AC4 Invalid characters throw `FormatException` with position. |
| FR-OTP-05 | M | Secret generation | AC1 Uses `Random.secure()` only. AC2 Default 20 bytes (160 bits); minimum 16 bytes (RFC 4226 R6); requests below 16 throw. AC3 Per-algorithm recommended defaults: SHA-1 20 B, SHA-256 32 B, SHA-512 64 B. |
| FR-OTP-06 | M | Remaining-time and progress helpers | AC1 `secondsRemaining(now)` and `progress(now)` ∈ [0,1) correct at boundaries 0, 29, 30. |

### 2.2 Verifier — `flutter_mfa_core`

| ID | P | Requirement | Acceptance criteria |
|---|---|---|---|
| FR-VER-01 | M | TOTP verification with configurable drift window | AC1 Default window ±1 step. AC2 Returns `VerificationResult` with matched step offset. AC3 Window > 10 rejected. |
| FR-VER-02 | M | Replay protection (RFC 6238 §5.2) | AC1 Verifier accepts `lastUsedStep`; a code for a step ≤ lastUsedStep is rejected as `replayed`. AC2 Successful result returns the new `lastUsedStep` for the caller to persist. |
| FR-VER-03 | M | HOTP verification with look-ahead and resync (RFC 4226 §7.4) | AC1 Look-ahead window configurable (default 10). AC2 Success returns next counter. AC3 Resync with two consecutive codes supported. |
| FR-VER-04 | M | Constant-time code comparison | AC1 Comparison iterates full length regardless of mismatch position (unit test inspects the helper; reviewed in security review). |
| FR-VER-05 | M | Attempt limiter (RFC 4226 §7.3 throttling) | AC1 `AttemptLimiter` interface + `InMemoryAttemptLimiter`. AC2 Policies: max attempts per window, exponential back-off, hard lockout. AC3 Store abstraction (`AttemptStore`) so servers can persist. AC4 Verifier consults the limiter **before** computing codes. |
| FR-VER-06 | M | Input normalisation | AC1 Strips spaces; rejects non-digits and wrong length as `malformed` without touching the limiter's success path (still counts as an attempt). |

### 2.3 otpauth URI — `flutter_mfa_core`

| ID | P | Requirement | Acceptance criteria |
|---|---|---|---|
| FR-URI-01 | M | Parse `otpauth://totp|hotp/<label>?…` | AC1 Label `Issuer:account` and percent-decoding. AC2 `secret` required; `counter` required for hotp. AC3 `issuer` param wins over label prefix if both present and differ → warning flag on result. AC4 Unknown params preserved in `extras`. AC5 Fuzz test: 10 000 random inputs never throw anything other than `FormatException`. |
| FR-URI-02 | M | Generate URIs | AC1 Round-trip parse(generate(x)) == x for all valid configs. AC2 Non-default algorithm/digits/period produce `compatibilityWarnings`. |
| FR-URI-03 | S | `otpauth-migration://` import (Google Authenticator export) | C-priority unless trivial; protobuf decode. Deferred by default. |

### 2.4 Secure storage (vault) — platform_interface + `flutter_mfa`

| ID | P | Requirement | Acceptance criteria |
|---|---|---|---|
| FR-VLT-01 | M | Store/read/list/delete OTP accounts | AC1 Secret bytes never cross into Dart as `String`; `Uint8List` only, zeroed after use where the API allows. AC2 Metadata (issuer, label, algorithm, digits, period, counter, created-at, protection level) stored separately from the secret. |
| FR-VLT-02 | M | Android: Keystore AES-256-GCM key; ciphertext in `noBackupFilesDir` | AC1 StrongBox used when available, fallback logged at debug. AC2 Data excluded from backup by location. AC3 Instrumented test proves round-trip on emulator API 23 and latest. |
| FR-VLT-03 | M | iOS: Keychain generic password, `WhenUnlockedThisDeviceOnly`, `kSecAttrSynchronizable = false` | AC1 XCTest round-trip on simulator. AC2 Optional SE envelope when `ProtectionLevel.hardwareBound` and device supports SE; simulator falls back with explicit `HardwareUnavailable` reason. |
| FR-VLT-04 | M | Web: non-extractable AES-GCM `CryptoKey` in IndexedDB; ciphertext in IndexedDB | AC1 Key generated with `extractable: false`. AC2 Throws `VaultUnavailable(insecureContext)` outside HTTPS/localhost. AC3 Browser test (Chrome) round-trip. AC4 README documents web threat limits. |
| FR-VLT-05 | M | Protection levels | `standard`, `biometric`, `hardwareBound` (`biometric` + hardware where possible). AC1 Capability query `vault.capabilities()` reports what is achievable on this device. |
| FR-VLT-06 | M | Biometric gating bound to crypto | AC1 Android: key with user-auth-required, unlocked via BiometricPrompt + CryptoObject. AC2 iOS: SecAccessControl `.biometryCurrentSet`. AC3 New biometric enrolment invalidates protected entries → surfaced as `KeyInvalidated` with recovery guidance. AC4 No public API returns a bare "authenticated" boolean. |
| FR-VLT-07 | M | Typed errors | Sealed `VaultException` hierarchy: `NotFound`, `UserCancelled`, `KeyInvalidated`, `HardwareUnavailable`, `VaultUnavailable`, `Corrupted`, `Unknown`. |

### 2.5 Facade — `flutter_mfa`

| ID | P | Requirement | Acceptance criteria |
|---|---|---|---|
| FR-FAC-01 | M | `MfaClient` high-level API: `enrollFromUri`, `enrollManual`, `accounts`, `currentCode`, `codeStream`, `remove`, `exportEncrypted`, `importEncrypted` | AC1 Example app uses only this API. AC2 Every method documented with a runnable snippet. |
| FR-FAC-02 | M | `codeStream(accountId)` emits code + remaining seconds every second and on step change | AC1 Fake clock test proves exactly one emission per step boundary plus ticks. AC2 Stream cancels its timer on cancel. |
| FR-FAC-03 | M | Integrity hooks | AC1 `DeviceIntegrityCheck` interface; default `NoopIntegrityCheck`; result passed to an app-supplied policy callback. AC2 Documented as MAS-R hook, not a guarantee. |
| FR-FAC-04 | M | Logging policy | AC1 Package logger never logs secrets, codes or URIs; a test greps captured logs for seeded secrets/codes and fails if found. |
| FR-FAC-05 | M | Sensitive clipboard | AC1 `copyCode` marks the clip sensitive (Android 13+ `EXTRA_IS_SENSITIVE`; iOS `localOnly` + expiration) and clears after expiry (default 30 s). |
| FR-FAC-06 | S | Screen-capture protection | AC1 `setScreenCaptureProtection(true)` sets `FLAG_SECURE` on Android; reported as unsupported elsewhere via capabilities. |
| FR-FAC-07 | M | Relying-party enrolment helper | AC1 `MfaClient.createEnrollment` returns secret + otpauth URI + a `TotpVerifier` for the confirm-first-code step; example demonstrates it. |

### 2.6 Backup — `flutter_mfa_core` (format) + facade

| ID | P | Requirement | Acceptance criteria |
|---|---|---|---|
| FR-BAK-01 | M | Encrypted export, format v1 (`02_ARCHITECTURE.md §7`) | AC1 Known-answer test with fixed salt/nonce. AC2 No plaintext export API exists. |
| FR-BAK-02 | M | Passphrase policy | AC1 Minimum 12 chars; zxcvbn-style scorer not required — length + character-class + common-list check (top 10k) bundled. |
| FR-BAK-03 | M | Import is atomic and validating | AC1 Wrong passphrase → `BackupDecryptFailed`; tampered byte → same; no partial writes. AC2 Duplicate accounts handled by strategy enum (`skip`, `replace`, `keepBoth`). |

### 2.7 UI — `flutter_mfa_ui`

| ID | P | Requirement | Acceptance criteria |
|---|---|---|---|
| FR-UI-01 | M | `OtpCodeField` — 6–8 digit entry | AC1 One semantic text field (single screen-reader focus) with segmented visuals. AC2 Paste of full code fills all. AC3 `AutofillHints.oneTimeCode`. AC4 Numeric keyboard. AC5 `onCompleted` fires once. AC6 Error state + message announced via `SemanticsService`. |
| FR-UI-02 | M | `OtpCodeDisplay` — shows current code with countdown ring | AC1 Grouping (123 456 / 1234 5678). AC2 Tap-to-copy with optional clipboard auto-clear (default 30 s). AC3 Hide/reveal mode. |
| FR-UI-03 | M | `MfaStatusBadge` — enrolled / not enrolled / locked / key invalidated | AC1 Not colour-only (icon + text). |
| FR-UI-04 | M | `OtpAccountTile` and `OtpAccountList` | AC1 Works with `MfaClient.accounts` stream. |
| FR-UI-05 | M | `EnrollmentQrView` — renders an otpauth URI as QR plus manual-entry secret (grouped base32) | AC1 Secret shown with copy; warning text about screenshots. |
| FR-UI-06 | M | Theming independent of Material | AC1 `MfaTheme` InheritedWidget + `MfaThemeData`; Material and Cupertino adapters `MfaThemeData.fromMaterial(ThemeData)`/`fromCupertino`. AC2 Core widgets import only `package:flutter/widgets.dart` (lint rule). |
| FR-UI-07 | M | i18n | AC1 All strings via `MfaLocalizations` (ARB, gen-l10n). AC2 English complete; `hi` and `ar` files present (may be partial); RTL golden for `ar`. |
| FR-UI-08 | M | Accessibility | AC1 Flutter `meetsGuideline` tests: tap targets, labelled tap targets, text contrast for both themes. AC2 Manual TalkBack + VoiceOver pass recorded in `docs/a11y-report.md`. |

### 2.8 QR — `flutter_mfa_qr`

| ID | P | Requirement | Acceptance criteria |
|---|---|---|---|
| FR-QR-01 | M | `OtpQrScanner` widget wrapping `mobile_scanner`, emits parsed `OtpAuthUri` | AC1 Only `otpauth://` payloads accepted; others ignored with optional callback. AC2 Duplicate detections debounced. |
| FR-QR-02 | M | Permission UX | AC1 States: requesting, denied, permanently denied (with "open settings" callback), unavailable (no camera / insecure context). |
| FR-QR-03 | M | Web loading policy | AC1 Default backend = native BarcodeDetector; zxing fallback only if `allowRemoteDecoder: true` or a self-hosted `decoderScriptUrl` is supplied. AC2 Documented CSP. |
| FR-QR-04 | S | Scan from image (gallery) | Uses `analyzeImage`. |

### 2.9 Example app — `flutter_mfa/example`

| ID | P | Requirement |
|---|---|---|
| FR-EX-01 | M | Runs on Android, iOS, Web from one codebase |
| FR-EX-02 | M | Screens: account list, scan, manual add, account detail (code), relying-party demo (generate secret → show QR → confirm code), backup/restore, settings (protection level, integrity status) |
| FR-EX-03 | M | Integration tests drive the full enrol → code → verify → backup → wipe → restore journey |
| FR-EX-04 | M | Uses only public APIs; no `src/` imports |

---

## 3. Non-functional requirements

| ID | Requirement | Measure |
|---|---|---|
| NFR-01 | Line coverage per Dart package | ≥ 85 % (core target ≥ 95 %) |
| NFR-02 | Branch coverage per Dart package | ≥ 75 % (if Flutter branch coverage is unavailable for widget packages, report and gate lines only — decided in Phase 0, recorded in ADR-0008) |
| NFR-03 | Static analysis | `dart analyze --fatal-infos` clean with the repo's strict lint set |
| NFR-04 | pub.dev score | 160/160 pub points for every package at release |
| NFR-05 | Dependencies | Core: `crypto`, `meta`, `collection` only, plus the chosen AEAD/KDF package (ADR-0007). All deps MIT/BSD/Apache-2.0. `dart pub outdated` clean of security advisories. |
| NFR-06 | Performance | TOTP generation < 1 ms on mid-range Android; PBKDF2 600k export key derivation runs off the UI isolate (`Isolate.run`) |
| NFR-07 | Platform floors | Dart ≥ 3.9, Flutter ≥ 3.35, Android minSdk 23 / target latest, iOS 13, Web secure context; WASM-compatible web build |
| NFR-08 | API docs | 100 % public API documented (`public_member_api_docs` lint on) |
| NFR-09 | No secrets in repo | gitleaks in CI; test vectors only |
| NFR-10 | Supply chain | Actions pinned by SHA; Dependabot for pub + actions; OIDC publishing only |
| NFR-11 | Semantic versioning | 0.x rules: minor = breaking; CHANGELOG per package (Keep a Changelog) |
| NFR-12 | Security mapping | Every MASVS v2 control in scope has evidence in `docs/security/masvs-checklist.md` |

---

## 4. Explicitly out of scope for 0.2.0

Push MFA backend · WebAuthn/passkeys (POC may live in a branch) · device attestation (Play Integrity / App Attest) · cloud sync · desktop platforms (macOS/Windows/Linux — architecture must not block them) · SMS/email OTP delivery · `otpauth-migration` import (unless trivial).
