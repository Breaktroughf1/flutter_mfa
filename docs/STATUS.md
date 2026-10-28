# Build status

Updated by Claude Code after every task. Newest at the bottom.

| Date | Task | Status | Commit / PR | Coverage | Notes / deviations |
|---|---|---|---|---|---|
| 28 Oct 2026 | — | Docs pack created | — | — | Baseline docs, ADR-0001..0008, CI scaffold |
| 28 Oct 2026 | M0-01 | Done | see git log | — | Toolchain verified; Android SDK + Xcode unavailable locally (CI only) |
| 28 Oct 2026 | M0-02 | Done | see git log | — | All 5 names unclaimed; D1 confirmed by maintainer |
| 28 Oct 2026 | M0-03 | Done | see git log | — | Melos 8.10 (scripts follow 8.x `exec` rules); lints/recommended base kept; `formatter.trailing_commas: preserve` added (maintainer-approved) so `require_trailing_commas` and tall-style format agree; root `pubspec.lock` committed (single workspace lockfile, S15); fixed `.gitignore` inline-comment bug that left golden `failures/` un-ignored; `test` no longer runs core tests twice |
| 28 Oct 2026 | M0-04 | Done | see git log | — | Five packages + 3 example apps, all `resolution: workspace`, version `0.1.0-dev.1`, MIT LICENSE, README, CHANGELOG. **Deviation:** `flutter_mfa_platform_interface` uses `flutter create -t package`, not `dart create` (it extends `PlatformInterface`, which needs Flutter). Template Dart code (duplicate method channel / platform interface, `getPlatformVersion`) removed here instead of M0-05 so `melos run analyze` passes. Org `com.breaktroughf1` (maintainer decision). Core example lives at `example/main.dart` (02 §2). |
| 28 Oct 2026 | M0-05 | Done (web) / CI-only (android, ios) | see git log | — | SDK constraints Dart `>=3.9.0 <4.0.0`, Flutter `>=3.35.0`. **Deviation: Android minSdk 24 and iOS 15**, not 23/13. Flutter 3.47 rejects minSdk ≤ 23 (`gradle_utils.dart` treats it as too old) and its minimum iOS deployment target is 15.0 (`ios_deployment_target_migration.dart`). CLAUDE.md, 00 G15, PRD NFR-07/FR-VLT-02, 05 and 06 updated. SPM `Package.swift` (iOS 15, privacy manifest processed) is the primary iOS integration; podspec kept with real metadata, Swift 5.9, privacy bundle. Example `flutter build web` and `flutter build web --wasm` pass locally. `flutter build apk`: no Android SDK in this container (dl.google.com blocked), so verified by CI. iOS: no macOS, so CI only. `dart pub publish --dry-run`: 0 warnings for all 5 packages on a clean tree. |
| 28 Oct 2026 | M0-06 | Done | see git log | — | `tool/test.sh` is the single test runner (VM, Chrome for `test/web/**`, examples) used by `melos test`, `melos coverage`, `verify` and CI. `coverage_gate.dart` counts `BRDA` records because the Dart VM emits no BRF/BRH. Guards hardened: core bans `dart:io/isolate/ffi/mirrors` plus a dependency allowlist; the Material ban now covers qr too; forbidden_apis adds seeded `Random(n)`, console logging, `fetch`, and all native logging (Kotlin `println`, `System.out`, `os_log`, `Logger`); comment lines ignored. Each guard red-teamed with injected violations (all caught). PRD FR-VLT-02 AC1 no longer asks for a native debug log (gap 13). |
| 28 Oct 2026 | M0-07 | Done locally; CI result in the PR | see git log | — | `ci.yml` rewritten. Jobs: verify, test (VM + Chrome + coverage gates), min-sdk (Flutter 3.35.7 + `pub downgrade`, **passed locally**), goldens, web (WASM build + `flutter drive`), android (API 24/36: APK build, JVM unit tests, emulator instrumented + integration), ios (macOS 15, SPM build, XCTest, integration; main/nightly/`ci:ios`), security (gitleaks binary v8.30.1 checksum-verified, **no leaks in history**; osv-scanner v2.7.0; forbidden APIs), publish-dry-run. All actions pinned by SHA (also in publish.yml); Flutter pinned to 3.47.8. Shared setup is a composite action (DRY). Fixed an emulator-runner bug (each script line runs in its own shell, so `cd` was lost). **ADR-0008 outcome:** branch coverage works for dart and flutter test but emits only BRDA records; web coverage is unsupported, so browser tests gate web-only code. Not runnable here: android/ios jobs (no SDK/macOS); actionlint was blocked by the sandbox, workflows checked with a YAML parse instead. |
| 28 Oct 2026 | M0-08 | Done | see git log | — | Full Contributor Covenant 2.1 text from the official repo (contact: conduct@breaktroughf1.com, **needs confirming**). README: CI/licence badges, platform table, bold web/XSS warning (S12), docs links. CONTRIBUTING: real setup (`flutter pub get`, Melos 8, Chrome), test layout, commit scopes. CODEOWNERS covers `/tool/`. Dependabot adds the root workspace, examples, the composite action and the example Gradle project. All relative markdown links checked: 0 broken. |
| 28 Oct 2026 | M0-09 | Done | see git log | — | STATUS finalised for the M0 checkpoint (decisions, placeholders, open gaps below). |
| 28 Oct 2026 | M1-01 | Done | see git log | core 100 % / 100 % | Sealed `MfaException` hierarchy with value equality and redacting `toString`; `OtpAuthUriException` also implements `FormatException` (resolves FR-URI-01 AC5 vs spec); reason enums for hardware/vault-unavailable errors; `PassphraseCheck` enum created early because `BackupWeakPassphrase` carries it. `constantTimeEquals`/`constantTimeStringEquals` (full-length XOR, tested by counting element reads); `AsyncMutex` (FIFO, releases on sync/async throw). Spec §1.9/§1.11 and PRD FR-OTP-01 AC2 updated. New core dep: `meta` (BSD-3, Dart team, already allowed). |
| 28 Oct 2026 | M1-02 | Done | see git log | core 100 % / 100 % | `Base32` (RFC 4648 §10 vectors, otpauth sample, lenient case/space/hyphen/missing padding, strict padding/length). **Spec deviation:** `FormatException.source` is always `null` (spec showed `source`), because the input is a secret and `FormatException.toString` prints it. Fuzz: round-trip and garbage input (`FMFA_FUZZ_RUNS`, default 10k). Trailing non-zero pad bits are accepted (interop; harmless). |
| 28 Oct 2026 | M1-03 | Done | see git log | core 100 % / 100 % | `computeOtp` is the single HMAC + truncation implementation (arithmetic counter encoding, exact on VM/JS/WASM); `Hotp`, `Totp`, configs (validated on use; const constructors per spec), `Clock`/`SystemClock`, `OtpSecret` (defensive copies, redacted, constant-time `==`, length-only `hashCode`, wipes temporary key copies). **Decision (gap 17):** import accepts 10–256 B and `meetsRfcMinimum` flags < 16 B; generation is 16–256 B. **Decision:** counter ceiling 2^53−1 on every platform (uniform behaviour). Large-counter expectations computed independently with Python `hmac`. PRD FR-OTP-05/06 and spec §1.1/§1.3 updated. New core dep: `crypto` (BSD-3, Dart team; allowed). |

## Environment (M0-01)
Verified 28 Oct 2026 in the Claude Code cloud container (Ubuntu 24.04, x86_64). Sources: Flutter release manifest, pub.dev API, developer.android.com.

| Tool | Version found | Notes |
|---|---|---|
| Flutter | **3.47.8** stable (rev 737ba8f885, 22 Oct 2026) | Installed from the official archive, SHA-256 verified. The scaffold's "3.38.6" was stale. |
| Dart | **3.13.7** (bundled with Flutter) | Workspace floor stays `>=3.9.0 <4.0.0` (Flutter 3.35.7 ships Dart 3.9.2) |
| Melos | **8.10.0** (latest; 7.x line ends at 7.8.2) | Scaffold pinned `^7.0.0`; moved to 8.x (M0-03) |
| lints | 6.1.0 | `^6.0.0` already correct |
| coverage / test | 1.16.0 / 1.33.0 | |
| Java / Gradle | OpenJDK 21.0.12, Gradle 8.14.3 | |
| Android SDK / emulator | **Not available** | `dl.google.com` blocked by the container's network policy, so the SDK can't be installed; `maven.google.com` works. Android builds and tests run only in GitHub CI. Latest stable platform: **API 36** (Android 16). |
| Xcode / simulator | **Not available** (Linux) | iOS validated only in CI (`macos-latest`) and on maintainer devices |
| Chrome | Playwright Chromium (`CHROME_EXECUTABLE=/opt/pw-browsers/chromium-1243/chrome-linux64/chrome`) | Web tests and `--wasm` builds run locally |
## Package name availability (M0-02)
Checked 28 Oct 2026 against `https://pub.dev/api/packages/<name>` (404 = no package with that name exists) and pub.dev search (no confusingly similar `flutter_mfa*` packages found). A name can't be reserved without publishing, so these stay free only until someone claims them. Plan: publish `flutter_mfa_core 0.1.0-dev.1` as soon as M1 is green (G14).

| Package | Available on pub.dev? |
|---|---|
| flutter_mfa_core | Yes (404) |
| flutter_mfa_platform_interface | Yes (404) |
| flutter_mfa | Yes (404) |
| flutter_mfa_ui | Yes (404) |
| flutter_mfa_qr | Yes (404) |

## Open decisions
See docs/00_STUDY.md §7.

| ID | Outcome |
|---|---|
| D1 | **Confirmed `flutter_mfa*`** (maintainer, 28 Oct 2026). All five names unclaimed on pub.dev. |
| D2 | Open (study §4 recommendation: reviewers / security testers / docs + translations) |
| D3 | Open: AUTHORS.md draft wording stands until R-01 |
| D4 | `Breaktroughf1/flutter_mfa`, CODEOWNERS `@NoealRajeev` |
| D5 | Open: verified publisher `breaktroughf1.com` (DNS TXT) blocks the first publish only |
| D6 | Open: `security@breaktroughf1.com` is in SECURITY.md and the podspec author field but is unconfirmed |
| D7 | DCO |
| D8 | Public |
| D9 | Open (default: English + hi/ar scaffolding) |

## Maintainer decisions taken at M0 (28 Oct 2026)
- Commits carry the maintainer identity (author + DCO sign-off: Noeal Rajeev).
- Android/iOS bundle prefix **`com.breaktroughf1`** (not `dev.breaktroughf1`). Android namespace `com.breaktroughf1.flutter_mfa`. **02_ARCHITECTURE §4.2's Keychain service `dev.breaktroughf1.flutter_mfa` becomes `com.breaktroughf1.flutter_mfa` in M1-13.**
- `formatter.trailing_commas: preserve` added so `require_trailing_commas` stays.
- Coverage gates are hard 85/75 (core 95/90) from day one: no staged 70 % threshold at M1.
- Branch: the session's designated branch `claude/determined-wright-aqfz9k` is used instead of `chore/M0-setup` (the harness only permits pushes there).

## Placeholders still open (need maintainer input)
| Where | Placeholder |
|---|---|
| `SECURITY.md`, `ios/flutter_mfa.podspec` author | `security@breaktroughf1.com` (D6) |
| `CODE_OF_CONDUCT.md` | enforcement contact `conduct@breaktroughf1.com` |
| `AUTHORS.md` | contributor list + AI-assisted wording (D3, R-01) |
| pub.dev | verified publisher (D5) |

## Known gaps carried into M1+ (from the kickoff review)
- ~~**Secret length (before M1-03):**~~ resolved at M1-03 — API says `OtpSecret.fromBytes` needs ≥ 16 B, but the docs' sample/KAT secret `JBSWY3DPEHPK3PXP` is 10 B and many real issuers use 80-bit secrets. Decision to take in M1-03 (default plan: ≥ 16 B for generation and relying-party enrolment; authenticator import accepts ≥ 10 B with a compatibility warning; recorded in the spec).
- **PRD ↔ API mismatches to reconcile in M1:** FR-OTP-01 (`ArgumentError` vs `OtpConfigException`), FR-OTP-06 (`secondsRemaining` vs `remaining`), FR-URI-01 AC5 (`FormatException` vs `OtpAuthUriException`), FR-VER-05 (`InMemoryAttemptLimiter` vs `InMemoryAttemptStore`, and which library exports it), FR-UI-04 (`accounts` vs `watchAccounts`), undefined types (`RelyingPartyEnrollment`, `ImportReport`, `DuplicateStrategy`, `IntegrityReport`, `NoopIntegrityCheck`, `MfaLogger`, `AttemptState`, `PassphraseCheck`, `CompatibilityWarning`), and `VaultCapabilities` having no screen-capture flag.
- **`hardwareBound` semantics (M3):** Android StrongBox → TEE fallback vs iOS fail-closed. Plan: fail closed on every platform; report the obtained backing in capabilities.
- **Web backup KDF (M3):** `Isolate.run` doesn't exist on web; PBKDF2 at 600k iterations in pure Dart would block the UI thread. Needs an ADR (WebCrypto PBKDF2 or a worker).
- **Passphrase policy vs KAT passphrase** (`correct horse battery staple`, all lower-case) at M3-02/03.
