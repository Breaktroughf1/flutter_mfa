# 02 — Architecture

## 1. Principles

1. **One implementation of every rule.** OTP maths, URI handling, validation, error mapping, backup format and limiter logic live once in `flutter_mfa_core` and are reused by the client, the UI, the example app and any Dart server. Native code is a thin byte vault — no OTP logic, no validation, no JSON in Kotlin/Swift/JS. (DRY is a review gate, see `CLAUDE.md`.)
2. **Smallest possible native surface.** Native code does only what Dart cannot: hardware-backed key handling, biometric-bound decryption, OS clipboard flags, screen-capture flags.
3. **Secrets are bytes, never strings.** `Uint8List` end to end; base32 strings exist only at the enrol/backup boundary and are not retained.
4. **Pure Dart core.** `flutter_mfa_core` must compile with `dart compile exe` and has no `package:flutter` import — enforced by CI.
5. **Ports and adapters.** Every external effect (clock, randomness, storage, attempt store, integrity check, logger) is an interface with an in-memory fake in `testing/` libraries so tests never need a device unless they are testing the device.

## 2. Repository layout

```
flutter_mfa/                       ← git root, Dart pub workspace root (publish_to: none)
├── CLAUDE.md                      ← build rules for Claude Code
├── pubspec.yaml                   ← workspace + melos scripts
├── analysis_options.yaml          ← shared strict lints (packages include it)
├── packages/
│   ├── flutter_mfa_core/          ← pure Dart: OTP, base32, otpauth, verifier, limiter, backup format, models, errors
│   │   ├── lib/flutter_mfa_core.dart
│   │   ├── lib/testing.dart       ← fakes: FakeClock, SeededRandom, InMemoryAttemptStore
│   │   ├── lib/src/{otp,codec,uri,verify,limit,backup,model,errors,util}/
│   │   ├── test/  (incl. test/vectors/)
│   │   ├── example/main.dart      ← CLI example (server verify)
│   │   └── tool/                  ← known-answer generators (not published: .pubignore)
│   ├── flutter_mfa_platform_interface/
│   │   ├── lib/flutter_mfa_platform_interface.dart
│   │   ├── lib/testing.dart       ← InMemoryMfaPlatform
│   │   └── lib/src/{platform,method_channel,messages.g.dart}
│   ├── flutter_mfa/               ← app-facing plugin: MfaClient + Android/iOS/Web impls
│   │   ├── lib/flutter_mfa.dart   ← re-exports core public API (single import for apps)
│   │   ├── lib/src/{client,account_repository,code_ticker,clipboard,integrity,logging}/
│   │   ├── lib/src/web/           ← WebVault (package:web + dart:js_interop)
│   │   ├── android/src/main/kotlin/dev/breaktroughf1/flutter_mfa/
│   │   ├── android/src/test/ + androidTest/
│   │   ├── ios/flutter_mfa/Sources/flutter_mfa/   ← Swift Package Manager layout (+ podspec)
│   │   ├── ios/flutter_mfa/Tests/
│   │   └── example/               ← THE example app (Android/iOS/Web) + integration_test/
│   ├── flutter_mfa_ui/            ← widgets on `widgets` layer, MfaTheme, l10n (ARB)
│   │   ├── lib/l10n/{app_en.arb,app_hi.arb,app_ar.arb}
│   │   ├── test/goldens/
│   │   └── example/               ← widget gallery
│   └── flutter_mfa_qr/            ← OtpQrScanner (mobile_scanner)
│       └── example/
├── tool/
│   ├── pigeon/                    ← Pigeon schema + generator runner (not a workspace member)
│   ├── test.sh                    ← every test run (VM + Chrome), optional coverage gates
│   ├── coverage_gate.dart         ← parses lcov (BRDA), enforces thresholds per package
│   ├── forbidden_apis.sh          ← security grep (Random(), print, weak crypto, native logging)
│   ├── check_no_flutter_in_core.sh
│   └── check_no_material_in_ui.sh
├── docs/                          ← this pack + adr/ + security/ + cookbook/
└── .github/                       ← workflows, templates, CODEOWNERS, dependabot
```

## 3. Package dependency graph

```
                    flutter_mfa_core   (pure Dart)
                    ▲      ▲       ▲
                    │      │       │
flutter_mfa_platform_interface     │
                    ▲      │       │
                    │      │       │
                  flutter_mfa      │
                    ▲              │
                    │        flutter_mfa_ui  ──► (flutter widgets only)
                    │              ▲
                    │              │
                  example ─────────┼──────► flutter_mfa_qr ──► mobile_scanner
                                   └──────────────┘ (qr depends on core + ui)
```

Rules (CI-checked with `tool/` scripts):
- `flutter_mfa_core` → no Flutter.
- `flutter_mfa_ui` → depends on `flutter_mfa_core` only (not on the plugin). Widgets receive data and callbacks; they never call platform code. This keeps UI testable with no channels and reusable with any storage.
- `flutter_mfa_qr` → depends on `flutter_mfa_core` + `flutter_mfa_ui` (for theme/l10n) + `mobile_scanner`.
- Publish order follows the graph: core → platform_interface → flutter_mfa → ui → qr.

## 4. Layering inside `flutter_mfa`

```
MfaClient (facade, public)
 ├─ AccountRepository      ← metadata index + secret records; owns the index AsyncMutex
 │    └─ MfaPlatform       ← platform_interface (Pigeon on mobile, WebVault on web); throws VaultException only
 │                           (M1-11: the planned MfaVault layer was dropped — error mapping moved into
 │                            MethodChannelMfaPlatform at M1-10, the mutex lives in AccountRepository)
 ├─ CodeTicker             ← codeStream; uses core Totp + Clock
 ├─ SensitiveClipboard     ← MfaPlatform.copySensitive
 ├─ IntegrityGate          ← DeviceIntegrityCheck + app policy
 └─ BackupService          ← core BackupCodec + passphrase policy + AccountRepository
```

### 4.1 The single storage primitive (DRY)
Native code implements **one** thing: a protected byte map.

| Operation | Notes |
|---|---|
| `capabilities()` | hardware-backed? StrongBox/SE present? biometrics enrolled? secure context (web)? |
| `write(key, bytes, protection)` | protection ∈ standard / biometric / hardwareBound |
| `read(key, prompt?)` | prompt shown only for biometric-protected entries |
| `delete(key)`, `keys()`, `wipe()` | `keys()` returns only this plugin's namespace |

Everything else is Dart:
- **Account index** = a JSON document stored under key `__index_v1__` at `standard` protection; it holds non-secret metadata (`AccountMeta`).
- **Account secret** = raw seed bytes stored under key `acct_<uuid>` at the account's protection level.
- **HOTP counter / TOTP lastUsedStep** live in the index (not secret; integrity protected by AEAD on every platform).
- Index writes are serialised through one async lock (`package:synchronized`-style mutex implemented in core `util/`) to prevent lost updates.

### 4.2 Platform implementations

**Android (Kotlin)**
- Pigeon `MfaHostApi` implementation, `ActivityAware` for BiometricPrompt.
- Keys: `flutter_mfa.master.v1` (AES-256-GCM, no user auth) for standard; per-entry `flutter_mfa.bio.<key>` with `setUserAuthenticationRequired(true)`, `setInvalidatedByBiometricEnrollment(true)`, auth type `BIOMETRIC_STRONG`. `setIsStrongBoxBacked(true)` attempted first for hardwareBound, then standard TEE.
- Ciphertext files (as built, M1-12): `context.noBackupFilesDir/flutter_mfa/<hex(utf8(key))>.bin` = `version(1) ‖ protection(1) ‖ nonce(12) ‖ ciphertext ‖ tag(16)`; AAD = `"flutter_mfa.v1:" ‖ header ‖ key name` (prevents swapping files between keys or relabelling the protection level). Hex instead of SHA-256 so `keys()` can list key names (they are not secret). Writes are atomic (temp file + rename). The master key requires an unlocked device (API 28+, mirroring iOS `WhenUnlocked`), is created with StrongBox when present and falls back to the TEE for `standard`. `biometric`/`hardwareBound` are refused with `unsupportedOnPlatform` until M3-05 (fail closed). Native errors carry only a `VaultErrorCode` (sent as its Dart enum name).
- Biometric read: `Cipher.init(DECRYPT, key, GCMParameterSpec)` → `BiometricPrompt.authenticate(promptInfo, CryptoObject(cipher))` → decrypt in callback. Requires host `MainActivity` to extend `FlutterFragmentActivity` — documented in README; plugin returns `VaultUnavailable(hostActivityNotFragmentActivity)` otherwise.
- `KeyPermanentlyInvalidatedException` → `KeyInvalidated`.
- Sensitive clipboard: `ClipDescription.EXTRA_IS_SENSITIVE` (API 33+), plus timed clear.
- Optional `FLAG_SECURE` toggle.

**iOS (Swift, SPM + CocoaPods)**
- Keychain `kSecClassGenericPassword`, service `com.breaktroughf1.flutter_mfa` (org decision at M0), account = key, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, `kSecAttrSynchronizable: false`, `kSecAttrGeneric` = `version ‖ protection` (as built, M1-13). `biometric`/`hardwareBound` are refused with `unsupportedOnPlatform` until M3-06 (fail closed). Error codes are sent as the `VaultErrorCode` case name. Note: iOS keeps Keychain items after uninstall, so a reinstall sees earlier accounts (Android deletes app data) — maintainer decision pending.
- biometric: `SecAccessControlCreateWithFlags(.., kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .biometryCurrentSet)`; read with `LAContext.localizedReason`.
- hardwareBound: Secure-Enclave P-256 key (`kSecAttrTokenIDSecureEnclave`) wraps the seed with `ECIESEncryptionCofactorVariableIVX963SHA256AESGCM`; Keychain stores the ciphertext. Simulator → `HardwareUnavailable`.
- `errSecItemNotFound` → NotFound; `errSecUserCanceled`/`LAError.userCancel` → UserCancelled; access-control failure after enrolment change → KeyInvalidated.
- Sensitive clipboard: `UIPasteboard.general.setItems(_, options: [.localOnly: true, .expirationDate: …])` — no read-back needed.

**Web (Dart, `package:web` + `dart:js_interop`; WASM-compatible)**
- Requires `window.isSecureContext`; otherwise `VaultUnavailable(insecureContext)`.
- IndexedDB database `flutter_mfa_v1`, stores `keys` and `records`.
- Master key: `crypto.subtle.generateKey({name:'AES-GCM', length:256}, extractable:false, ['encrypt','decrypt'])`, persisted as a `CryptoKey` object in IndexedDB (structured clone keeps it non-extractable).
- Records: `nonce ‖ ciphertext` with AAD = key name.
- `biometric` / `hardwareBound` → reported unsupported by `capabilities()`; requesting them throws `HardwareUnavailable` (WebAuthn-PRF-based gating is a post-0.2 candidate).
- Calls `navigator.storage.persist()` once and exposes the result in capabilities (eviction risk).
- Clipboard: `navigator.clipboard.writeText` + timed clear best-effort.

## 5. Public API shape
Full signatures in `03_API_SPEC.md`. Entry points:
- Server / pure Dart: `import 'package:flutter_mfa_core/flutter_mfa_core.dart';` → `Totp`, `Hotp`, `OtpAuthUri`, `Base32`, `OtpSecret`, `TotpVerifier`, `HotpVerifier`, `AttemptLimiter`, `BackupCodec`.
- Apps: `import 'package:flutter_mfa/flutter_mfa.dart';` → `MfaClient` + re-exports of core.
- Widgets: `import 'package:flutter_mfa_ui/flutter_mfa_ui.dart';`
- Scanner: `import 'package:flutter_mfa_qr/flutter_mfa_qr.dart';`

## 6. Error model
Single sealed hierarchy rooted in core (`MfaException`) so every package and the example map errors once:
```
MfaException (sealed)
├── OtpConfigException          (bad digits/period/secret length)
├── OtpAuthUriException         (parse failure, with field + reason)
├── VerificationRateLimited     (retryAfter)
├── VaultException (sealed)
│   ├── VaultNotFound · VaultUserCancelled · VaultKeyInvalidated
│   ├── VaultHardwareUnavailable(reason) · VaultUnavailable(reason)
│   └── VaultCorrupted · VaultUnknown(platformCode)
└── BackupException (sealed)
    ├── BackupDecryptFailed · BackupUnsupportedVersion · BackupWeakPassphrase
```
Verification *outcomes* are values, not exceptions: `VerificationResult = accepted(step|counter) | rejected(reason: invalid|replayed|malformed)`; only rate-limiting throws.
Platform error codes are defined once in the Pigeon schema as an enum (`VaultErrorCode`), mapped once in `MethodChannelMfaPlatform` (M1-10), so every `MfaPlatform` — channel or web — throws only `VaultException`.

## 7. Backup container format v1 (`.fmfa`)

```
offset  size  field
0       4     magic "FMFA" (0x46 0x4D 0x46 0x41)
4       1     format version = 0x01
5       1     kdf id = 0x01 (PBKDF2-HMAC-SHA256)
6       4     iterations, uint32 big-endian (writer: 600000; reader: reject < 210000)
10      16    salt (random)
26      12    nonce (random)
38      n     AES-256-GCM ciphertext ‖ 16-byte tag
AAD = bytes[0..38)  (entire header)
```
Plaintext = UTF-8 JSON:
```json
{
  "format": "flutter_mfa.backup",
  "version": 1,
  "createdAt": "2026-11-20T10:00:00Z",
  "accounts": [
    {"type":"totp","issuer":"Example","label":"alice@example.com",
     "algorithm":"SHA1","digits":6,"period":30,"counter":null,
     "secret":"JBSWY3DPEHPK3PXP","createdAt":"…"}
  ]
}
```
- Encoding of the file: raw bytes; optional ASCII armour (`-----BEGIN FLUTTER MFA BACKUP-----` + base64, 64-col) for copy/paste.
- KDF runs in `Isolate.run` on Flutter, directly on server.
- Readers reject unknown versions with `BackupUnsupportedVersion`; future versions may add Argon2id (kdf id 0x02).
- Known-answer test fixture lives in `packages/flutter_mfa_core/test/vectors/backup_v1.json` (generated once by `tool/gen_backup_kat.dart` with fixed salt/nonce, then frozen).

## 8. Concurrency and lifecycle
- `MfaClient` is a plain object created by the app (no global singleton); `MfaClient.create()` async factory performs capability probing and index migration.
- `codeStream` uses one shared `CodeTicker` per client (one `Timer.periodic`, fan-out to listeners) — not one timer per tile.
- All index mutations go through `AccountRepository`, which serialises them with one `AsyncMutex`; secrets are written before and deleted before their index entry, and orphans are swept on first load.
- Index schema version stored in the index; migrations are pure Dart functions in core with tests.

## 9. Extensibility (post-0.2, not built now)
- Desktop vaults (macOS Keychain shares Swift code; Windows DPAPI/Credential Locker; Linux libsecret) slot in behind `MfaPlatform`.
- WebAuthn PRF for web biometric gating.
- Push approval channel as a separate `flutter_mfa_push` package.
