# 05 — Test Plan

## 1. Test pyramid and where each layer runs

| Layer | Tool | Packages | Runs on | Gate |
|---|---|---|---|---|
| Unit | `package:test` / `flutter_test` | all Dart | Linux CI, every PR | must pass |
| Known-answer (KAT) | unit tests on frozen vectors | core | Linux CI | must pass |
| Property / fuzz | `package:test` + seeded generators (`glados` optional) | core (base32, URI, OTP, backup) | Linux CI (10k cases PR, 200k nightly) | must pass |
| Widget | `flutter_test` | ui, qr, flutter_mfa (facade with InMemory platform) | Linux CI | must pass |
| Golden | `flutter_test` `matchesGoldenFile`, tag `golden` | ui | **one** pinned Linux image | must pass; update via `melos run goldens:update` only in a labelled PR |
| Accessibility | `meetsGuideline(...)` | ui | Linux CI | must pass |
| Native unit | JUnit + Robolectric (Android), XCTest (iOS) | flutter_mfa | Linux / macOS CI | must pass |
| Native instrumented | AndroidX test on emulator | flutter_mfa | Linux CI (KVM) API 24 + latest (36) | must pass |
| Integration (end-to-end) | `integration_test` | flutter_mfa/example | Android emulator, iOS simulator (macOS), Chrome (`flutter drive -d web-server` + chromedriver) | must pass on `main` and release; PR: Android + web, iOS on label `ci:ios` or nightly |
| Static | `dart analyze --fatal-infos`, `dart format --set-exit-if-changed`, custom `tool/` checks | all | every PR | must pass |
| Security static | gitleaks, osv-scanner, forbidden-API grep, license allowlist | repo | every PR | must pass |
| Dynamic security | manual (Frida, objection, backup extraction, clipboard, screenshot) | example app on physical devices | M4 | report reviewed |
| Manual a11y | TalkBack, VoiceOver, keyboard-only web | example | M2 + M4 | report reviewed |

## 2. Coverage gates (NFR-01/02)
- Collected with `dart test --coverage` (core) / `flutter test --coverage` (Flutter packages); branch coverage enabled where the toolchain supports it (verify `--branch-coverage` in Phase 0 and record the finding in ADR-0008).
- `tool/coverage_gate.dart <lcov> --lines 85 --branches 75` per package; core uses `--lines 95 --branches 90`.
- Exclusions allowed only for generated files (`*.g.dart`, `messages.g.dart`, l10n output) via `// coverage:ignore-file` in the generator config — not hand-written ignores. Any hand-written `coverage:ignore` requires a code-owner-approved comment.
- Uploaded to Codecov when a token exists, but **the gate is the local script**, so an outage cannot pass a PR.

## 3. Known-answer vectors (frozen; source: RFC text — verify against the RFC on first commit)

### 3.1 RFC 4226 Appendix D — HOTP, SHA-1, 6 digits
Secret ASCII `12345678901234567890` (hex `3132333435363738393031323334353637383930`)

| Counter | HOTP |
|---|---|
| 0 | 755224 |
| 1 | 287082 |
| 2 | 359152 |
| 3 | 969429 |
| 4 | 338314 |
| 5 | 254676 |
| 6 | 287922 |
| 7 | 162583 |
| 8 | 399871 |
| 9 | 520489 |

### 3.2 RFC 6238 Appendix B — TOTP, 8 digits, period 30, T0 0
Seeds differ per algorithm (the most common implementation bug is reusing the 20-byte seed):
- SHA-1: ASCII `12345678901234567890` (20 B)
- SHA-256: ASCII `12345678901234567890123456789012` (32 B)
- SHA-512: ASCII `1234567890123456789012345678901234567890123456789012345678901234` (64 B)

| Unix time | SHA-1 | SHA-256 | SHA-512 |
|---|---|---|---|
| 59 | 94287082 | 46119246 | 90693936 |
| 1111111109 | 07081804 | 68084774 | 25091201 |
| 1111111111 | 14050471 | 67062674 | 99943326 |
| 1234567890 | 89005924 | 91819424 | 93441116 |
| 2000000000 | 69279037 | 90698825 | 38618901 |
| 20000000000 | 65353130 | 77737706 | 47863826 |

(Values re-computed independently on 28 October 2026 and match the RFC tables. Note 20000000000 exceeds 32-bit time — test on web too.)

### 3.3 Base32 — RFC 4648 §10
`""→""`, `"f"→"MY======"`, `"fo"→"MZXQ===="`, `"foo"→"MZXW6==="`, `"foob"→"MZXW6YQ="`, `"fooba"→"MZXW6YTB"`, `"foobar"→"MZXW6YTBOI======"`. Plus otpauth sample: bytes `48 65 6C 6C 6F 21 DE AD BE EF` ↔ `JBSWY3DPEHPK3PXP`.

### 3.4 Backup v1 KAT
Generated once by `tool/gen_backup_kat.dart` with salt `00..0f`, nonce `00..0b`, passphrase `correct horse battery staple`, iterations 600000, one TOTP account (secret `JBSWY3DPEHPK3PXP`). The hex output is frozen in `test/vectors/backup_v1.json`. Cross-checked by a Python script using `cryptography` (`tool/crosscheck_backup.py`, not published) so the KAT is not self-referential.

## 4. Test matrix — by requirement
| Area | Must-have cases |
|---|---|
| HOTP/TOTP | All vectors; digits 6/7/8; invalid digits 5/9; period 15/30/60; T0 ≠ 0; step boundaries (t = 29.999, 30.000); negative/pre-T0 time rejected; large counters; web counter ceiling |
| Verifier | window 0/1/2; drift −1/+1 accepted, ±2 rejected at window 1; replay same step rejected; earlier step rejected; nextState monotonic; malformed inputs (letters, spaces, length 5/9, empty, unicode digits `٣`) → malformed; limiter consulted before HMAC (spy) |
| Limiter | N failures → limited; retryAfter grows exponentially and caps; success resets; lockout after threshold; window expiry with FakeClock; concurrent failures (Future.wait) don't lose counts in InMemory store |
| URI | Google example URIs; percent-encoded labels; issuer in label only / param only / both mismatched; hotp missing counter; lower-case secret with spaces; unknown params preserved; non-otpauth scheme; fuzz 10k |
| Vault (facade with InMemoryMfaPlatform) | enrol → list → code → remove; index persistence across client re-create; concurrent enrolments don't lose entries; corrupted index → VaultCorrupted surfaced and recoverable via wipe; each VaultException mapped |
| Android native | round-trip standard; StrongBox fallback; biometric path with Robolectric shadow (unit) + manual device; KeyPermanentlyInvalidated mapping; no file outside noBackupFilesDir |
| iOS native | round-trip; `ThisDeviceOnly` attribute asserted via `SecItemCopyMatching` attributes; SE unavailable on simulator → HardwareUnavailable; cancel mapping |
| Web vault | key non-extractable (`exportKey` rejects); insecure context error; round-trip; AAD swap detection |
| Backup | KAT; wrong passphrase; truncated file; flipped byte in header/ciphertext/tag; unsupported version; iterations below floor; armor round-trip; duplicate strategies; atomicity (failure mid-import leaves vault unchanged) |
| Logging | capture all `MfaLogger` output across full journey; assert no seed base32, no hex, no current code appears |
| UI | OtpCodeField: type, paste full code, paste with spaces, backspace, onCompleted once, RTL, error announce; OtpCodeDisplay grouping & hidden mode semantics; badge text+icon; goldens light/dark/ar-RTL/large-text (textScaler 2.0) |
| QR | non-otpauth ignored; debounce; permission states; web options default (no remote decoder) |
| Example integration | full journey: relying-party demo enrol → scan (injected URI on emulator) → code matches core-computed expected with fixed clock → export → wipe → import → codes identical |

## 5. Device matrix
| Platform | CI | Manual (M4) |
|---|---|---|
| Android | Emulator API 24 (x86_64) and latest stable API (36) | Pixel (StrongBox), Samsung (Knox quirks), one low-end device |
| iOS | Simulator latest iOS, minimum supported iOS | iPhone with Face ID, one with Touch ID |
| Web | Chrome stable (CI) | Chrome, Safari, Firefox (decoder opt-in path), Edge |

## 6. Definition of Done for any PR
1. Linked requirement IDs in the PR description.
2. Tests for every AC touched; coverage gate green.
3. `melos run verify` green locally (format, analyze, tests, custom checks).
4. Public API changes reflected in `03_API_SPEC.md` + CHANGELOG `Unreleased`.
5. No new dependency without an ADR note (licence, maintenance, size).
6. Docs/dartdoc updated; example still runs.
