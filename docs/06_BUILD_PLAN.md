# 06 — Build Plan (Claude Code execution order)

Milestone names match the ARDC proposal (M0–M4, Release) so institutional paperwork lines up. Each task has an ID used in branch names (`feat/M1-03-totp`), commits (`feat(core): totp generator [M1-03]`) and PRs.

**Working rhythm for Claude Code**
1. Pick the next unchecked task in order (dependencies are listed).
2. Branch → implement → tests → `melos run verify` → open PR (or commit to the milestone branch if PRs aren't set up yet).
3. At every 🛑 **checkpoint**, stop and report to the maintainer: what was built, test/coverage numbers, anything that deviated from the spec, and questions. Do not start the next milestone without a go-ahead.
4. Update the checkbox here and `docs/STATUS.md` (one line per task: done / PR link / notes).

Estimated calendar (Claude Code implementing, BF1 reviewing within 1 working day): **M0 2–3 days · M1 1 week · M2 1.5 weeks · M3 1.5 weeks · M4 1 week · Release 2–3 days ≈ 6–7 weeks.**

---

## M0 — Kickoff & setup

| ✓ | ID | Task | Depends | Done when |
|---|---|---|---|---|
| ✅ | M0-01 | Verify environment: Flutter stable version, Dart version, `melos`, Xcode/Android SDK availability in the dev environment; record in `docs/STATUS.md` | — | Versions recorded; gaps flagged to maintainer |
| ✅ | M0-02 | Check pub.dev name availability for all 5 package names (decision D1); report | — | Report in STATUS.md |
| ✅ | M0-03 | Create workspace root `pubspec.yaml` (publish_to: none, `workspace:` list, melos scripts — see scaffold) and `analysis_options.yaml` | — | `dart pub get` resolves |
| ✅ | M0-04 | Create the five packages (`dart create -t package` for core/platform_interface; `flutter create --template=plugin --platforms=android,ios,web --org dev.breaktroughf1 -a kotlin -i swift` for flutter_mfa; `flutter create -t package` for ui/qr), each with `resolution: workspace`, MIT LICENSE, README stub, CHANGELOG, `example/` | M0-03 | `melos run analyze` passes on empty packages |
| ✅ | M0-05 | Remove template boilerplate; set SDK constraints (Dart `>=3.9.0 <4.0.0`, Flutter `>=3.35.0`); Android minSdk 24; iOS 15 (raised from 23/13, see STATUS M0-05); SPM + podspec | M0-04 | Example app builds for android, ios (if macOS available), web |
| ✅ | M0-06 | `tool/coverage_gate.dart`, `tool/check_no_flutter_in_core.sh`, `tool/check_no_material_in_ui.sh`, `tool/forbidden_apis.sh` | M0-03 | Scripts run in `melos run verify` |
| ✅ | M0-07 | CI workflow (`.github/workflows/ci.yml` from scaffold) — adapt and make green; confirm branch coverage flag behaviour; write ADR-0008 outcome | M0-06 | CI green on a dummy PR |
| ✅ | M0-08 | Community files finalised: README (root), CONTRIBUTING (DCO), SECURITY, CODE_OF_CONDUCT (Contributor Covenant 2.1 full text), AUTHORS, CODEOWNERS, PR/issue templates, dependabot | — | Files present, links valid |
| ✅ | M0-09 | `docs/STATUS.md` created (already existed; finalised) | — | — |

🛑 **Checkpoint M0** — report env, name availability, CI status. Maintainer confirms D1, D4, D5.

---

## M1 — Core OTP + storage (proposal weeks 1–2)

| ✓ | ID | Task | Req | Depends |
|---|---|---|---|---|
| ✅ | M1-01 | `errors/` sealed hierarchy; `util/constant_time.dart`; `util/mutex.dart` | §6 arch, FR-VER-04 | M0 |
| ✅ | M1-02 | `codec/base32.dart` + RFC 4648 tests + fuzz | FR-OTP-04 | M1-01 |
| ☐ | M1-03 | `otp/otp_core.dart` (single HMAC+truncation fn), `Hotp`, `Totp`, configs, `Clock`, `OtpSecret` | FR-OTP-01..06 | M1-02 |
| ☐ | M1-04 | `test/vectors/` RFC 4226 + RFC 6238 vector files and tests (verify values against RFC text) | FR-OTP-01/02 | M1-03 |
| ☐ | M1-05 | `uri/otpauth_uri.dart` parse/generate + compatibility warnings + fuzz | FR-URI-01/02 | M1-02 |
| ☐ | M1-06 | `limit/` AttemptLimiter, policy, InMemoryAttemptStore | FR-VER-05 | M1-01 |
| ☐ | M1-07 | `verify/` TotpVerifier, HotpVerifier (+resync), input normalisation | FR-VER-01..06 | M1-03, M1-06 |
| ☐ | M1-08 | `model/` OtpAccount, ProtectionLevel; `testing.dart` fakes | §1.7 API | M1-03 |
| ☐ | M1-09 | Core `example/main.dart` (server-style verify) + README for core | FR-EX doc | M1-07 |
| ☐ | M1-10 | Platform interface: `MfaPlatform`, capabilities, `InMemoryMfaPlatform`, Pigeon schema + generated code | §2 API | M1-08 |
| ☐ | M1-11 | `flutter_mfa`: `MfaVault` (error mapping), `AccountRepository` (index), `MfaClient` enrol/list/currentCode/remove on InMemory platform | FR-VLT-01, FR-FAC-01 | M1-10 |
| ☐ | M1-12 | Android vault — standard protection (Keystore AES-GCM, noBackupFilesDir), JUnit + instrumented tests | FR-VLT-02 | M1-10 |
| ☐ | M1-13 | iOS vault — standard protection (Keychain ThisDeviceOnly), XCTest | FR-VLT-03 | M1-10 |
| ☐ | M1-14 | Web vault — IndexedDB + non-extractable key, browser tests (`flutter test --platform chrome`) | FR-VLT-04 | M1-10 |
| ☐ | M1-15 | Example boots on all three platforms: manual-add + code list | FR-EX-01 | M1-11..14 |

Exit: core coverage ≥ 95 % lines; other packages ≥ 70 % (proposal M1 target); API for core + platform interface **frozen** (changes now need ADR).

🛑 **Checkpoint M1** — demo, numbers, frozen API review. Optional: publish `flutter_mfa_core 0.1.0-dev.1` manually to hold the name (D1).

---

## M2 — QR + widgets (weeks 3–4)

| ✓ | ID | Task | Req |
|---|---|---|---|
| ☐ | M2-01 | `flutter_mfa_ui`: `MfaTheme`, `MfaThemeData`, Material/Cupertino adapters | FR-UI-06 |
| ☐ | M2-02 | l10n setup (gen-l10n, ARB en/hi/ar), `MfaLocalizations` | FR-UI-07 |
| ☐ | M2-03 | `OtpCodeField` (single semantic field, segmented paint, paste, autofill) | FR-UI-01 |
| ☐ | M2-04 | `OtpCodeDisplay`, `OtpCountdownRing`, `MfaStatusBadge` | FR-UI-02/03 |
| ☐ | M2-05 | `OtpAccountTile`, `OtpAccountList` | FR-UI-04 |
| ☐ | M2-06 | `EnrollmentQrView` (pure-Dart `qr` + CustomPainter) | FR-UI-05 |
| ☐ | M2-07 | Golden suite (light/dark/RTL/large text) + `meetsGuideline` a11y tests | FR-UI-08 |
| ☐ | M2-08 | `CodeTicker` + `MfaClient.codeStream`, `copyCode` + `copySensitive` native (Android/iOS/web) | FR-FAC-02, FR-FAC-05 |
| ☐ | M2-09 | `flutter_mfa_qr`: `OtpQrScanner`, permission states, web options | FR-QR-01..03 |
| ☐ | M2-10 | Example: scan screen, account detail, relying-party demo (`createEnrollment` → QR → confirm with `OtpCodeField`) | FR-EX-02, FR-FAC-07 |
| ☐ | M2-11 | Docs baseline: package READMEs with screenshots (from goldens), cookbook pages: "Add an authenticator", "Enrol users (relying party)", "Verify on a Dart server" | P-Q6 |
| ☐ | M2-12 | Manual a11y pass #1 → `docs/a11y-report.md` | FR-UI-08 AC2 |

🛑 **Checkpoint M2** — screen recording of example on Android/iOS/web; goldens attached to PR.

---

## M3 — Backup / biometrics / threat model (weeks 5–6)

| ✓ | ID | Task | Req |
|---|---|---|---|
| ☐ | M3-01 | ADR-0007 finalised: choose AEAD/KDF package after licence + maintenance check; add dependency | FR-BAK-01 |
| ☐ | M3-02 | `backup/` BackupCodec v1, armour, PassphrasePolicy (+ bundled common-password list, compressed) | FR-BAK-01/02 |
| ☐ | M3-03 | Backup KAT generator + Python cross-check + frozen fixture | §3.4 test plan |
| ☐ | M3-04 | `MfaClient.exportEncrypted/importEncrypted` (isolate KDF, atomic import, duplicate strategies) | FR-BAK-03 |
| ☐ | M3-05 | Android biometric + hardwareBound (per-entry keys, BiometricPrompt+CryptoObject, StrongBox, invalidation) | FR-VLT-05/06 |
| ☐ | M3-06 | iOS biometric + hardwareBound (SecAccessControl, SE envelope) | FR-VLT-05/06 |
| ☐ | M3-07 | Web: capabilities report biometric unsupported; clear errors | FR-VLT-05 |
| ☐ | M3-08 | Integrity hook: `DeviceIntegrityCheck`, `IntegrityPolicy`, example settings screen | FR-FAC-03 |
| ☐ | M3-09 | Example: backup/restore screens, protection-level picker, key-invalidated recovery flow | FR-EX-02 |
| ☐ | M3-10 | Threat model v1 published as `docs/security/threat-model.md` (from `04_SECURITY_DESIGN.md`, updated with as-built details) | P-F6 |

🛑 **Checkpoint M3** — threat model review with ARDC security track; biometric demo on physical devices (maintainer runs).

---

## M4 — Hardening & CI gates (weeks 7–8)

| ✓ | ID | Task | Req |
|---|---|---|---|
| ☐ | M4-01 | Coverage to ≥ 85/75 everywhere; core ≥ 95/90 | NFR-01/02 |
| ☐ | M4-02 | Logging-leak test across the full journey | FR-FAC-04 |
| ☐ | M4-03 | Integration tests for full journey on Android, iOS, web in CI | FR-EX-03 |
| ☐ | M4-04 | Security CI: gitleaks, osv-scanner, forbidden-API grep, license allowlist, Actions pinned by SHA | NFR-09/10 |
| ☐ | M4-05 | `FLAG_SECURE` option | FR-FAC-06 |
| ☐ | M4-06 | MASVS checklist completed with evidence links `docs/security/masvs-checklist.md` | NFR-12 |
| ☐ | M4-07 | Dynamic test support: write `docs/security/dynamic-test-guide.md` for ARDC testers (what to attack, how to report) | §9 security |
| ☐ | M4-08 | `pana` locally for every package → 160/160; fix findings | NFR-04 |
| ☐ | M4-09 | Dartdoc completeness (`public_member_api_docs`), API reference review | NFR-08 |
| ☐ | M4-10 | CHANGELOGs → 0.2.0 sections; versions bumped; `melos version` dry run | NFR-11 |
| ☐ | M4-11 | Manual a11y pass #2; dynamic security report triaged; all high findings fixed | §9 |

🛑 **Checkpoint M4** — release readiness review against `07_RELEASE_RUNBOOK.md` pre-flight list.

---

## Release — v0.2.0 (weeks 9–10 in proposal; ~2–3 days here)
Follow `07_RELEASE_RUNBOOK.md` exactly. Claude Code prepares everything up to the tag; **the maintainer performs first-time manual publishes and pushes signed tags.**

| ✓ | ID | Task |
|---|---|---|
| ☐ | R-01 | Final AUTHORS.md / README credits per decision D3 |
| ☐ | R-02 | `dart pub publish --dry-run` clean for all packages in order |
| ☐ | R-03 | Maintainer: manual first publish of each package (dependency order) under verified publisher |
| ☐ | R-04 | Maintainer: enable automated publishing per package (tag pattern + `pub.dev` environment) |
| ☐ | R-05 | GitHub release notes; announcement draft for BF1 + ARDC |
| ☐ | R-06 | Post-mortem notes template filled with data (CI stats, issues found, lessons) for the ARDC × BF1 session |
