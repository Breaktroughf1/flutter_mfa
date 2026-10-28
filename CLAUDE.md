# CLAUDE.md — flutter_mfa

You are building **flutter_mfa**, an open-source (MIT) multi-factor authentication toolkit for Flutter (Android, iOS, Web), maintained by BreaktroughF1 LLP in collaboration with ARDC, CHRIST (Deemed to be University). It will be published on pub.dev. Treat it as security-critical production software.

## Read first (in this order) before writing code
1. `docs/06_BUILD_PLAN.md` — what to do next. Work task by task, in order. Stop at every 🛑 checkpoint.
2. `docs/01_PRD.md` — requirement IDs and acceptance criteria. Every PR cites IDs.
3. `docs/02_ARCHITECTURE.md` and `docs/03_API_SPEC.md` — the contract. Do not invent public API outside it.
4. `docs/04_SECURITY_DESIGN.md` — non-negotiable security rules.
5. `docs/05_TEST_PLAN.md` — test vectors and gates.
6. `docs/adr/` — decisions already made. Don't relitigate them; propose a new ADR if you think one is wrong.
7. `docs/00_STUDY.md` — background on why the design differs from the original proposal.

Keep `docs/STATUS.md` updated after each task (task ID, status, PR/commit, notes, deviations).

## Repository
Dart pub workspace. Packages in `packages/`:
`flutter_mfa_core` (pure Dart — NO Flutter imports) · `flutter_mfa_platform_interface` · `flutter_mfa` (plugin: Kotlin, Swift, Web) · `flutter_mfa_ui` (widgets — NO Material/Cupertino imports except the two adapter files) · `flutter_mfa_qr`.

## Commands
```bash
dart pub get                     # resolves the whole workspace
melos run verify                 # format check + analyze + all tests + custom checks — run before every commit
melos run test                   # all unit/widget tests
melos run test:core              # fastest loop for core work
melos run coverage               # lcov per package + gate
melos run goldens:update         # only when a visual change is intended; say so in the PR
melos run analyze
cd packages/flutter_mfa/example && flutter test integration_test -d <device>
cd packages/flutter_mfa/example && flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart -d web-server
```

## Golden rules
1. **DRY is a review gate.** One implementation per rule: OTP truncation, base32, URI parsing, constant-time compare, error mapping, account serialisation, backup format, limiter logic. If you're about to write something similar twice, extract it into `flutter_mfa_core` (or the right shared `src/util/`). Native code is a thin byte vault — no OTP logic, no JSON, no validation in Kotlin/Swift/JS.
2. **Secrets are bytes.** `Uint8List`, never `String` (base32 strings only at the enrol/backup boundary, not retained). Never in `toString`, exceptions, logs, analytics, asserts, or test failure messages. Use `MfaLogger` only; `print`/`debugPrint`/`Log.d`/`NSLog` of values are forbidden.
3. **No weak crypto.** Only the primitives listed in `04_SECURITY_DESIGN.md §6`. `Random()` only in `testing.dart`. No custom crypto. No hard-coded keys/IVs outside test vectors.
4. **Fail closed.** Unknown platform state → typed `VaultException`, never a silent fallback to weaker protection. A weaker protection level is used only when the caller asked for it.
5. **Tests first for core.** Write vector/property tests before implementation in `flutter_mfa_core`. Every AC gets a test. Coverage gates are hard limits (core 95/90, others 85/75).
6. **No new dependencies** without noting licence (MIT/BSD/Apache-2.0 only), last release date, and size in the PR and, if lasting, an ADR line. Core may depend only on `crypto`, `meta`, `collection`, and the AEAD/KDF package chosen in ADR-0007.
7. **Public API = `03_API_SPEC.md`.** If implementation shows the spec is wrong, stop, explain, propose the change, update the spec in the same PR once approved.
8. **Every public member has dartdoc** with at least one sentence; security-relevant members say what they protect against and what they don't.
9. **Platform floors:** Dart >=3.9.0 <4.0.0, Flutter >=3.35.0, Android minSdk 23, iOS 13, web secure contexts. Code must compile to web JS and WASM (`package:web`, `dart:js_interop`; never `dart:html`).
10. **Never** commit real secrets/PII, never disable a lint to make CI pass without a comment and maintainer approval, never weaken a test to make it pass, never push tags or publish to pub.dev (maintainer does that).

## Style
- Strict lints from root `analysis_options.yaml`; `dart format` default.
- `final class` / `sealed class` / `interface class` modifiers used deliberately; immutable value types with `const` constructors.
- Files: `snake_case.dart`; one public type per file in `src/` where reasonable; libraries export via the package's top-level file only.
- Tests mirror `lib/src/` paths. Test names describe behaviour: `'rejects a code from an already-used step (replay)'`.
- Kotlin: official style, coroutines not required; Swift: Swift 5.9+, `final class`, no force unwraps in vault code.

## Commits and PRs
- Conventional Commits with task ID: `feat(core): add TOTP verifier with replay protection [M1-07]`. Scopes: core, platform, plugin, android, ios, web, ui, qr, example, ci, docs.
- DCO sign-off on every commit (`git commit -s`).
- PR description template: summary · requirement IDs · tests added · coverage numbers · security notes · API changes · screenshots (UI).
- Small PRs (< ~500 changed lines excluding generated/goldens).

## When unsure
Prefer asking the maintainer (Noeal, CTO, BreaktroughF1) over guessing on anything security-related, any public API change, any new dependency, or anything touching publishing. For everything else, choose the option most consistent with the docs and record it in `docs/STATUS.md`.

## Boundaries
This is a public repo. Do not reference or include any BreaktroughF1 internal/proprietary product code, names or client data. Only the open-source MFA toolkit lives here.
