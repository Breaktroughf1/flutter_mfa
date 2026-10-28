# 04 — Security Design, Threat Model and MASVS v2 Mapping

## 1. Security goals
1. An OTP seed stored by `flutter_mfa` cannot be recovered from a backup, a copied app-data directory, or another app on the same device.
2. When an account is biometric-protected, no code can be produced without a fresh biometric event that the OS ties to a key operation.
3. Verification (server or local) resists brute force and replay.
4. The library never emits secrets or codes through logs, crash reports, analytics, exceptions, `toString()` or the persistent clipboard.
5. Integrators get safe defaults and cannot reach an insecure mode without an explicit, named opt-in.

## 2. Assets
| Asset | Sensitivity | Where it lives |
|---|---|---|
| A1 OTP seed | Critical — equals the second factor | Vault (protected), RAM briefly, backup file (encrypted) |
| A2 Current code | High for ≤ 30–90 s | RAM, UI, clipboard (sensitive, expiring) |
| A3 Account metadata (issuer, label) | Low–medium (reveals which services user has) | Vault index |
| A4 Backup passphrase | Critical | RAM only, never stored |
| A5 Limiter state | Integrity-relevant | Server store / local index |
| A6 Release pipeline (pub.dev publish rights) | Critical — supply chain to every integrator | GitHub + pub.dev |

## 3. Adversaries
| ID | Adversary | Capability |
|---|---|---|
| T1 | Remote attacker with stolen password | Can submit codes to the verifier |
| T2 | Malicious app on same device (no root) | Clipboard read, overlay, accessibility abuse, screenshot via screen-record on some OEMs |
| T3 | Attacker with app-data/backup copy | Has `adb backup`/iCloud/Google Drive backup or a filesystem image, not the unlocked device |
| T4 | Attacker with the unlocked device briefly | Can open the app |
| T5 | Attacker with root/jailbreak + Frida | Can hook process memory and native calls |
| T6 | Web attacker with XSS on the host origin | Full JS execution in the page origin |
| T7 | Supply-chain attacker | Compromised dependency, GitHub Action, maintainer account or CDN |

## 4. Threats and mitigations (STRIDE-oriented)

| # | Threat | Adversary | Mitigation | Residual |
|---|---|---|---|---|
| S1 | Brute-forcing 6-digit codes at the verifier | T1 | `AttemptLimiter` checked before HMAC; back-off + lockout; docs require server-side verify | Integrator must persist limiter state server-side |
| S2 | Replay of an observed code within its window | T1 | `lastUsedStep` replay protection (RFC 6238 §5.2) returned by verifier | Integrator must persist `nextState` |
| S3 | Seed extracted from device backup | T3 | Android `noBackupFilesDir` + Keystore-wrapped ciphertext; iOS `ThisDeviceOnly`, non-synchronizable | None known |
| S4 | Seed extracted from filesystem image | T3 | Ciphertext only on disk; key non-exportable in TEE/StrongBox/Keychain | Keychain items readable on a jailbroken unlocked device (T5) |
| S5 | Biometric bypass by hooking a boolean | T5 | No boolean API; key usable only after BiometricPrompt `CryptoObject` / Keychain access control | Hardware-level attacks out of scope |
| S6 | Code read from clipboard by other apps / synced to other devices | T2 | Sensitive flag, `localOnly`, expiry/auto-clear; copy is explicit user action | Pre-Android-13 apps can still read clipboard while present |
| S7 | Code visible in screenshots / app switcher | T2, T4 | Optional `FLAG_SECURE`; `hidden` display mode; docs for iOS snapshot blurring in host app | iOS cannot block screenshots |
| S8 | Secrets in logs, exceptions, crash reports | all | Redacting `toString`, no-secret logging rule, log-capture test (FR-FAC-04), lint banning `print` | Integrator's own logging |
| S9 | Weak or timing-leaky comparison | T1 | Constant-time compare helper, single implementation | — |
| S10 | Weak backup encryption / passphrase guessing | T3 | PBKDF2-SHA256 600k, AES-256-GCM, header as AAD, passphrase policy, min-iteration floor on read | Offline guessing of weak-but-policy-passing passphrases |
| S11 | Malformed otpauth URI / QR crashes or injects | T2 | Strict parser, fuzz test, scanner accepts only `otpauth://` | — |
| S12 | Web: XSS reads codes | T6 | Non-extractable key prevents key *export*, but script can still call decrypt — **documented as unmitigable**; recommend strict CSP, Trusted Types. Also (found at M1-14): browsers keep non-extractable key material in the profile's IndexedDB files, so disk access to the browser profile recovers secrets; the web has no hardware binding | Web is best-effort; README says so in bold |
| S13 | Web: storage eviction loses factors | — | `storage.persist()`, capability flag, prompt to back up | Browser policy |
| S14 | Web QR decoder loaded from CDN | T7 | Native BarcodeDetector default; remote decoder opt-in or self-hosted | Firefox users need opt-in |
| S15 | Compromised dependency | T7 | Minimal deps, pinned lockfile in example, Dependabot, `osv-scanner` in CI, license allowlist | — |
| S16 | Compromised CI / publish | T7 | OIDC publish only, required `pub.dev` GitHub environment with reviewer, tag protection, Actions pinned by SHA, least-privilege `permissions:` | Maintainer account takeover → 2FA mandatory for all maintainers |
| S17 | Index tampering (e.g. reset HOTP counter / lastUsedStep) | T3/T5 | Index is AEAD-encrypted in vault (tamper = `VaultCorrupted`) | Root attacker can roll back whole vault |
| S18 | Rooted/jailbroken device | T5 | `DeviceIntegrityCheck` hook + app policy; docs explain it is detection, not prevention (MAS-R) | Bypassable by design |

## 5. MASVS v2 control mapping (MAS-L1 testing profile)

Evidence column names the test or document that proves it. This table is copied into `docs/security/masvs-checklist.md` and ticked at M4.

| Control | Applies? | How flutter_mfa addresses it | Evidence |
|---|---|---|---|
| MASVS-STORAGE-1 (sensitive data stored securely) | Yes | Vault: Keystore/Keychain/WebCrypto-wrapped ciphertext only | FR-VLT-02/03/04 tests; manual filesystem inspection |
| MASVS-STORAGE-2 (prevent leakage) | Yes | No-backup location, ThisDeviceOnly, redacted logs, sensitive clipboard | FR-FAC-04/05 tests; backup extraction test (manual) |
| MASVS-CRYPTO-1 (strong, current crypto) | Yes | HMAC-SHA1/256/512 per RFC; AES-256-GCM; PBKDF2-SHA256 600k; no custom crypto | Crypto inventory §6; KAT tests |
| MASVS-CRYPTO-2 (key management) | Yes | Platform-generated non-exportable keys, per-purpose aliases, invalidation on biometric change | Native tests; review |
| MASVS-AUTH-1 (secure auth protocols) | Partially (library) | Verifier design; docs require server-side verification | Cookbook "server verification" |
| MASVS-AUTH-2 (local auth per platform best practice) | Yes | Crypto-bound biometrics (CryptoObject / SecAccessControl) | FR-VLT-06 tests; Frida bypass attempt (ARDC security track, manual) |
| MASVS-AUTH-3 (extra auth for sensitive ops) | Yes | Biometric/hardwareBound protection levels; export requires passphrase | Tests |
| MASVS-NETWORK-1/2 | N/A | Library performs no network I/O (scanner web decoder aside — S14) | CI check: no `dart:io` HttpClient / `package:http` in packages |
| MASVS-PLATFORM-1 (IPC) | N/A | No exported components, no URL schemes registered by plugin | Manifest review |
| MASVS-PLATFORM-2 (WebViews) | N/A | None | — |
| MASVS-PLATFORM-3 (UI leakage) | Yes | Hidden mode, FLAG_SECURE option, sensitive clipboard, no codes in semantics labels when hidden | Widget tests |
| MASVS-CODE-1 (up-to-date platform) | Yes | Target latest Android API; SDK floors documented | CI matrix |
| MASVS-CODE-2 (update mechanism) | Integrator | Docs | — |
| MASVS-CODE-3 (no known-vulnerable deps) | Yes | osv-scanner + Dependabot | CI job |
| MASVS-CODE-4 (input validation) | Yes | Strict URI/base32/code parsing, fuzz tests | Fuzz suites |
| MASVS-RESILIENCE-1..4 | Hook only (MAS-R) | `DeviceIntegrityCheck` interface + no-op default; docs | — |
| MASVS-PRIVACY-1..4 | Yes | No telemetry, no PII collection, metadata stays local, clear data-handling statement in README | README "Privacy" section |

## 6. Cryptographic inventory
| Use | Primitive | Parameters | Implementation |
|---|---|---|---|
| OTP | HMAC-SHA1/256/512 | RFC 4226/6238 | `package:crypto` |
| Seed generation | CSPRNG | ≥ 16 B, default 20 B | `Random.secure()` |
| Vault (Android) | AES-256-GCM | 96-bit random nonce, 128-bit tag, AAD = key name | Android Keystore |
| Vault (iOS) | Keychain; optional ECIES P-256 + AES-GCM (Secure Enclave) | — | Security.framework |
| Vault (Web) | AES-256-GCM | non-extractable CryptoKey | WebCrypto |
| Backup KDF | PBKDF2-HMAC-SHA256 | 600 000 iter, 16 B salt; read floor 210 000 | AEAD/KDF package per ADR-0007 |
| Backup AEAD | AES-256-GCM | 12 B nonce, header AAD | same |
| Compare | constant-time | full-length XOR accumulate | core `util/` |

Forbidden: ECB, CBC without MAC, MD5, custom ciphers, `Random()` (non-secure) anywhere outside `testing.dart`, hard-coded keys/IVs outside test vectors. CI greps for these.

## 7. Secure coding rules (enforced in review — repeated in CLAUDE.md)
- Seeds: `Uint8List`, never `String`, never in `toString`, `==` on `OtpSecret` is constant-time.
- Zero buffers we own after use (`fillRange(0, len, 0)`) where the API gives us ownership; document that Dart GC prevents guarantees.
- No `print`/`debugPrint` in `lib/` (lint `avoid_print`); logging only through `MfaLogger` which redacts.
- Native: no `Log.d`/`NSLog` of values; release builds strip debug logging.
- Exceptions carry field names and reasons, never values.

## 8. Vulnerability disclosure
`SECURITY.md`: private reporting via GitHub Security Advisories (preferred) or `security@breaktroughf1.com` (decision D6); acknowledge within 3 business days, fix target 30 days for high/critical, coordinated disclosure ≤ 90 days, credit reporters. Supported versions: latest minor only during 0.x.

## 9. Security review gates
| Gate | When | Who |
|---|---|---|
| Threat model v1 review | End of M3 | BF1 + ARDC security track |
| Crypto/vault code review | Each vault PR | BF1 code owner (mandatory) |
| Dynamic testing (Frida, backup extraction, clipboard, screenshots) | M4 | ARDC security track on physical devices; results in `docs/security/dynamic-test-report.md` |
| Release sign-off | Before tag | BF1 |
