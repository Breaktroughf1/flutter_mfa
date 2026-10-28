# ADR-0008: CI quality gates are self-enforced; publishing uses pub.dev OIDC only

- Status: Accepted; branch-coverage detail to be completed at M0-07 (28 October 2026)

## Context
The proposal names Codecov and signed tags. A third-party coverage service outage or missing token must not let an under-tested PR merge. Long-lived pub.dev credentials in CI secrets are a known leak vector; pub.dev supports GitHub-signed OIDC tokens.

## Decision
- `tool/coverage_gate.dart` reads lcov and fails the job below thresholds (core 95/90, others 85/75). Codecov upload is informational.
- Branch coverage: use the toolchain's branch-coverage option if available for both `dart test` and `flutter test`; if not available for Flutter packages, gate lines and report branches. **Phase 0 result:** _(fill in)_
- Publishing: `.github/workflows/publish.yml` triggered only by tags `<package>-v<semver>`, `permissions: id-token: write`, environment `pub.dev` with required reviewer. No `PUB_CREDENTIALS` secret ever.
- All third-party Actions pinned by commit SHA; Dependabot keeps them updated.

## Consequences
+ Gates can't silently pass; no stored publishing credentials.
− First publish of each package is manual; tag order matters for dependents.
