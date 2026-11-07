# flutter_mfa threat model, v1 (as built at M3)

Status: v1, 7 November 2026. It covers `flutter_mfa_core`, `flutter_mfa_platform_interface`, `flutter_mfa` (Android, iOS, web), `flutter_mfa_ui` and `flutter_mfa_qr` as built through milestone M3. Derived from [`04_SECURITY_DESIGN.md`](../04_SECURITY_DESIGN.md), which keeps the goals, the MASVS mapping and the cryptographic inventory. This document records what the code actually does, the risks found while building it, and what remains. The physical-device checks it relies on are in [`05_TEST_PLAN.md` §5.1](../05_TEST_PLAN.md).

Report vulnerabilities as described in [`SECURITY.md`](../../SECURITY.md), not in public issues.

## 1. What is protected

| Asset | Why it matters | Where it lives (as built) |
|---|---|---|
| A1 OTP seed | It *is* the second factor | Platform vault (§3). In memory while a code is computed, a backup is made or restored, and during enrolment: in the parsed `OtpAuthUri`, and on the relying-party side in `RelyingPartyEnrollment` and on screen as the QR code or setup key (`EnrollmentQrView`) until setup is confirmed. Encrypted in backups |
| A2 Current code | TOTP: usable for its period plus the verifier's drift window (30–90 s with the defaults; `TotpConfig.period` can be longer). HOTP: valid until used or a later code is accepted | Memory and screen; clipboard only on an explicit copy (sensitive flag, expires) |
| A3 Account metadata (issuer, name, counter, last used step) | Reveals which services a user has; counter and step protect against reuse | The vault index, encrypted like a seed at `standard` level |
| A4 Backup passphrase | Unlocks every seed in a backup | Typed by the user; held in memory for one export or import; never stored |
| A5 Attempt-limiter state | Stops guessing at the verifier | The integrator's server (`AttemptStore`) |
| A6 Release pipeline | Reaches every app that depends on the packages | GitHub Actions and pub.dev (ADR-0008) |

## 2. Trust boundaries and data flows

```
 ┌──────────── app process ────────────────────────────────────────┐
 │  app code ──► MfaClient ──► AccountRepository ──► MfaPlatform ──┼──► OS vault
 │     ▲            │  (Dart: OTP, URI, backup format, policy)     │    Keystore / Keychain /
 │     │            ├──► codes on screen / clipboard (sensitive)  │    Secure Enclave / IndexedDB
 │     │            └──► backup bytes (encrypted) ────────────────┼──► wherever the user puts them
 │  DeviceIntegrityCheck (app-supplied) ─► IntegrityPolicy         │
 └─────────────────────────────────────────────────────────────────┘
 Relying party (server): TotpVerifier + AttemptLimiter + its own AttemptStore
```

Boundaries that matter:
1. **Dart ↔ native vault.** Native code is a byte vault: it never parses OTP data. Errors cross as a `VaultErrorCode` only, with no message or value (Pigeon `FlutterError` code; Dart maps it once in `MethodChannelMfaPlatform`).
2. **Device ↔ backup storage.** A backup leaves the device only as AES-256-GCM ciphertext under a passphrase-derived key.
3. **Authenticator ↔ relying party.** Verification belongs on the server (ADR-0002). `MfaClient.createEnrollment` only helps a service enrol users; it stores nothing.
4. **Page ↔ any script in the origin (web).** There is no boundary here: see S12.

## 3. Storage as built

| Platform, level | Seed at rest | Unlock | Notes |
|---|---|---|---|
| Android `standard` | AES-256-GCM under the Keystore master key `flutter_mfa.master.v1` (StrongBox when present, else TEE; unlocked device required on API 28+); file in `noBackupFilesDir`; AAD = version ‖ level ‖ key name | none | Atomic writes; files cannot be moved between keys or relabelled |
| Android `biometric` / `hardwareBound` (API 30+) | AES-256-GCM under a random per-write data key; the data key is wrapped with RSA-OAEP by a per-entry Keystore RSA-2048 key | Class 3 biometric for **every** use, through `BiometricPrompt` + `CryptoObject` | Key invalidated by any new enrolment; StrongBox tried first for `hardwareBound`; software-only keys refused; aliases are random ids |
| iOS `standard` | Keychain generic password, `WhenUnlockedThisDeviceOnly`, never synchronizable | device unlocked | Leftovers from an earlier installation are wiped before first use (ADR-0012) |
| iOS `biometric` | Keychain item with `SecAccessControl(.biometryCurrentSet)`, `WhenPasscodeSetThisDeviceOnly` | Face ID / Touch ID, no passcode fallback | Re-enrolment makes the item unreadable |
| iOS `hardwareBound` | ECIES (P-256, cofactor X9.63 SHA-256, AES-GCM) under a per-entry Secure Enclave key with `.biometryCurrentSet`; plaintext bound to the key name | Face ID / Touch ID | No Secure Enclave on the simulator → refused |
| Web `standard` | AES-256-GCM under a non-extractable WebCrypto key in IndexedDB; AAD binds header and key name | none | Secure contexts only; `biometric`/`hardwareBound` refused (never downgraded) |

A level the device cannot provide is **never** silently replaced by a weaker one. `capabilities().supportedLevels` lists only what can be provided now, and writes at any other level throw `VaultHardwareUnavailable`.

## 4. Adversaries

| ID | Adversary | Capability |
|---|---|---|
| T1 | Remote attacker with the user's password | Submits codes to the verifier |
| T2 | Malicious app on the same device, no root | Clipboard reads, overlays, accessibility abuse, screen recording on some devices |
| T3 | Attacker with a backup or a disk image | Has an OS backup, a copied app-data directory or a filesystem image, not the unlocked device |
| T4 | Attacker holding the unlocked device briefly | Can open the app |
| T5 | Attacker with root or jailbreak and hooking tools | Can read process memory and hook native calls |
| T6 | Script running in the web app's origin | XSS, a compromised dependency, a malicious extension |
| T7 | Supply-chain attacker | A compromised dependency, Action, maintainer account or CDN |
| T8 | Attacker who can hand the user a crafted file or QR code | Malicious backup file, malicious QR code |

## 5. Threats, mitigations and residual risk

S1 to S18 are carried over from 04 §4 and updated to match the code. S19 onwards were found during M1–M3.

| # | Threat | Adv. | Mitigation as built | Residual risk |
|---|---|---|---|---|
| S1 | Guessing codes at the verifier | T1 | `AttemptLimiter` is consulted before any HMAC; exponential back-off and lockout; cookbook shows a shared store | Integrators must keep limiter state on the server and implement `AtomicAttemptStore.update` atomically (ADR-0014; cookbook shows Redis and SQL); a plain `AttemptStore` is last-writer-wins across processes |
| S2 | Replaying a seen code | T1 | `TotpVerifier` rejects steps at or before `lastUsedStep` and returns the next state; cookbook uses compare-and-set | Integrators must persist the new state atomically |
| S3 | Seed from an OS backup | T3 | Android `noBackupFilesDir`; iOS `ThisDeviceOnly`, not synchronizable | None known |
| S4 | Seed from a disk image | T3 | Only ciphertext on disk; keys non-exportable (TEE/StrongBox/Keychain/Secure Enclave) | On a jailbroken, unlocked iPhone, `standard` Keychain items are readable (T5) |
| S5 | Bypassing biometrics by hooking a boolean | T5 | No boolean anywhere: Android decrypts only with a `CryptoObject` cipher unlocked by the prompt; iOS releases data or uses the enclave key only after the OS check | Hardware attacks out of scope; on Android below API 30 the protected levels are not offered at all |
| S6 | Code read from the clipboard | T2 | Copy only on user action; Android 13+ sensitive flag; iOS local-only with expiry; clipboard cleared after `clipboardExpiry` | Android 12 and older let other apps read it until cleared; the web clears only when allowed without a prompt |
| S7 | Code visible in screenshots or the app switcher | T2, T4 | `FLAG_SECURE` on request (Android); hidden display mode | iOS cannot block screenshots; the host app must blur its snapshot |
| S8 | Secrets in logs, exceptions or `toString` | all | `MfaLogger` receives event names and account ids only; secrets are `Uint8List`; `toString` of `OtpSecret`, `BackupEntry`, `RelyingPartyEnrollment` and reports is redacted; native errors carry no message; CI bans `print`/`Log.*`/`NSLog` | The integrator's own logging |
| S9 | Timing leaks in comparison | T1 | One constant-time compare in core | — |
| S10 | Guessing a backup passphrase offline | T3 | PBKDF2-HMAC-SHA256 600 000 iterations, AES-256-GCM, header authenticated, policy (12+ characters, not in the top 10 000, varied) | A long-but-guessable passphrase that passes the policy |
| S11 | Malformed `otpauth://` or QR payload | T8 | Strict parser with fuzz tests; scanner accepts only `otpauth://`; payloads never logged | — |
| S12 | Script in the web origin reads codes | T6 | Non-extractable key stops key export only; documented in bold as a hard limit; CSP and Trusted Types recommended | **Unmitigable inside a page**: script can call decrypt; browser-profile files on disk also expose the key (M1-14) |
| S13 | Browser storage evicted | — | `storage.persist()` requested; `capabilities.persistentStorage` reported; README tells apps to prompt for a backup | Browser policy |
| S14 | Remote QR decoder | T7 | Native `BarcodeDetector` by default; a self-hosted decoder with a pinned SHA-256 or an explicit remote opt-in | Firefox users need an opt-in to scan |
| S15 | Compromised dependency | T7 | Few dependencies with licence checks; `osv-scanner` and gitleaks in CI; Dependabot; core is limited to an allowlist enforced by a script | `cryptography` is near the 12-month maintenance line (ADR-0007): two standard primitives behind an internal interface, pinned by a known-answer test |
| S16 | Compromised CI or publishing | T7 | OIDC publishing from a protected environment, Actions pinned by SHA, least-privilege permissions (ADR-0008) | Maintainer account takeover; 2FA required |
| S17 | Rolling back the index (HOTP counter, last used step) | T3/T5 | The index is authenticated ciphertext; tampering is `VaultCorrupted` | Root can restore an entire older vault |
| S18 | Rooted or jailbroken device | T5 | `DeviceIntegrityCheck` hook, app-supplied policy, run at `create` and on demand; documented as detection, not prevention (M3-08) | Bypassable by design |
| S19 | Crafted backup that hangs or crashes the import | T8 | Readers check magic, version, KDF id and **iterations in 210 000 … 10 000 000** before deriving any key; every content error is `BackupDecryptFailed`; the whole backup is validated before anything is stored | A 10 M-iteration file costs about 45 s of CPU before it is rejected or opened |
| S20 | Partial or misleading import | T8 | `importEncrypted` is all-or-nothing for the index: secrets are written under unused keys and the index is saved once under the vault lock; on failure the written secrets are deleted (best effort) and the original error is reported; a failed clean-up after the commit is not reported as a failed import | Rollback or post-commit deletes can themselves fail, and a crash can interrupt them: either leaves orphan secrets with no index entry. They are unreachable through the API and swept on the next first load |
| S21 | Duplicates hidden or merged wrongly on import | T8 | Duplicates are matched on id, or on type + issuer + name; `replace` stores under a new id so the old entry survives until the commit; `skip` is the default | Secrets are not compared (that would need a prompt per protected account), so two different seeds with the same labels count as duplicates |
| S22 | Seed copies the library cannot wipe | T5 | Dart buffers are zeroed after use where Dart allows (keys, plaintext, data keys on Android) | Export copies `BackupEntry` objects to a background isolate, and Base32 strings pass through the backup JSON; neither can be wiped. Garbage-collected memory is not zeroed |
| S23 | Losing protected accounts after a biometric change | T4 (and accidents) | By design (`.biometryCurrentSet`, `setInvalidatedByBiometricEnrollment`) keys die on re-enrolment; reads report `VaultKeyInvalidated`, iOS before any prompt; the example shows a recovery card (restore or remove) | Users without a backup must re-enrol the account with the service |
| S24 | iOS `biometric` item lost during an overwrite | — | An access-controlled item cannot be updated without authenticating, so it is replaced by delete + add | If the add fails, the old value is gone. The facade only overwrites the index (`standard`), and accounts are written under new keys, so normal use is not affected |
| S25 | A prompt shown at the wrong time (listing accounts) | T4 (UX) | Listing keys and reading headers on iOS use a non-interactive `LAContext`; saving never prompts on any platform | — |
| S26 | Weak passphrase via the example UI | user | Policy failures are explained in plain words; passphrase fields disable autocorrect, suggestions and personalised learning; controllers are cleared | The example copies the armoured backup to the general clipboard (it is ciphertext) |

## 6. Assumptions

- The OS, its keystore and its biometric stack behave as documented. Hardware attacks on the TEE, StrongBox or Secure Enclave are out of scope.
- Integrators verify codes on their server with a persistent limiter and replay state, and do not log codes or secrets.
- Apps that want biometric protection on iOS add `NSFaceIDUsageDescription`, and on Android run on API 30 or later.
- Users keep the backup passphrase separately from the backup.

## 7. Open items before 1.0

1. **Manual device pass** ([05 §5.1](../05_TEST_PLAN.md)). This covers the prompt itself, cancel and lockout mapping, invalidation after a new enrolment, StrongBox, the Secure Enclave, and API ≤ 29 behaviour. Emulators and simulators cannot exercise these.
2. **Dynamic testing** (ARDC security track, M4). This covers a Frida attempt at S5, backup extraction (S3), clipboard and screenshot checks (S6, S7), and checking that MASVS evidence is ticked in `masvs-checklist.md`.
3. ~~Atomic `AttemptStore.update`~~ Done at M4: `AtomicAttemptStore` (ADR-0014).
4. **Optional downgrade on import** (S20/S23). An account whose level the new device lacks fails the whole import. Maintainer decision at the M3 checkpoint: keep failing closed; add an explicit opt-in only if integrators ask for it.
