# ADR-0008: CI quality gates are self-enforced; publishing uses pub.dev OIDC only

- Status: Accepted (28 October 2026); branch-coverage outcome recorded at M0-07

## Context
The proposal names Codecov and signed tags. A third-party coverage service outage or missing token must not let an under-tested PR merge. Long-lived pub.dev credentials in CI secrets are a known leak vector; pub.dev supports GitHub-signed OIDC tokens.

## Decision
- `tool/coverage_gate.dart` reads lcov and fails the job below thresholds (core 95/90, others 85/75). Codecov upload is informational.
- Branch coverage: use the toolchain's branch-coverage option if available for both `dart test` and `flutter test`; if not available for Flutter packages, gate lines and report branches. **Phase 0 result (M0-07, Flutter 3.47.8 / Dart 3.13.7):**
  - `--branch-coverage` is available and works for **both** `dart test` (with `--coverage-path`) and `flutter test --coverage`. Both package types are gated on lines **and** branches (core 95/90, others 85/75). No line-only fallback is needed.
  - The VM writes `BRDA` records but **no `BRF`/`BRH` totals**, so the scaffold gate would have silently skipped branches. `tool/coverage_gate.dart` now computes branch totals from `BRDA` records (deduplicated per file/line/block/branch), and fails on malformed records.
  - The VM instruments block entries (`if`/`else` bodies, loop bodies, `switch` cases), **not** conditional expressions (`?:`, `??`, `&&`/`||` short-circuits). Branch % is therefore an upper bound; reviewers should not treat a 100 % branch number as proof that every ternary arm ran. Tests for security-relevant expressions must assert both arms explicitly.
  - `flutter test --platform chrome --coverage` produces **no** lcov. Web-only libraries (`lib/src/web/**`, loaded only via conditional imports or the web plugin registrant) never appear in VM lcov; they are gated by mandatory browser tests in `test/web/**` (run by `tool/test.sh` in the `test` job; CI fails if Chrome is missing). The web vault (M1-14) keeps its logic (record format, AAD, error mapping) in VM-testable Dart, with a thin `dart:js_interop` layer, so most of it stays under the lcov gate.
- One test runner: `tool/test.sh` (`melos run test` / `melos run coverage` / CI) so local and CI gates cannot drift.
- Publishing: `.github/workflows/publish.yml` triggered only by tags `<package>-v<semver>`, `permissions: id-token: write`, environment `pub.dev` with required reviewer. No `PUB_CREDENTIALS` secret ever.
- All third-party Actions pinned by commit SHA (done at M0-07, not deferred to M4-04); Dependabot keeps them updated. Flutter is pinned in CI (`FLUTTER_VERSION`) so goldens and analyzer output are reproducible; a `min-sdk` job proves the floor (Flutter 3.35.7 + `pub downgrade`).
- Secret scanning uses the gitleaks **binary** (MIT, checksum-verified), not `gitleaks-action`, which needs a paid licence for organisation-owned repos.

## Consequences
+ Gates can't silently pass; no stored publishing credentials.
− First publish of each package is manual; tag order matters for dependents.
