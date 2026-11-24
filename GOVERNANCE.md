# Governance

flutter_mfa is an open-source (MIT) project published by **BreaktroughF1 LLP** in collaboration with **ARDC, CHRIST (Deemed to be University)**. This document says who decides what, and how.

## Roles
- **Maintainers** (listed in [AUTHORS.md](AUTHORS.md) and [CODEOWNERS](.github/CODEOWNERS)) review and merge changes, decide on the roadmap and public API, publish releases to pub.dev, and handle security reports.
- **Code owners** must approve changes to the paths CODEOWNERS assigns them (security-critical code: OTP, verification, backup, the platform vaults, CI and ADRs).
- **Contributors** propose changes through issues and pull requests under [CONTRIBUTING.md](CONTRIBUTING.md) and the [Code of Conduct](CODE_OF_CONDUCT.md).

## How decisions are made
- Day-to-day changes: a pull request with green CI and a maintainer's approval.
- Design decisions (public API, security model, dependencies, platform floors): an Architecture Decision Record in [docs/adr/](docs/adr/), proposed in a pull request and accepted by a maintainer. Accepted ADRs are not relitigated; a later ADR supersedes an earlier one.
- Security: reports go through [SECURITY.md](SECURITY.md); maintainers coordinate fixes and disclosure privately.
- Disagreements are discussed on the pull request or issue; the lead maintainer decides when consensus is not reached.

## Releases
Maintainers publish from release tags through GitHub Actions with OIDC and a protected `pub.dev` environment ([docs/07_RELEASE_RUNBOOK.md](docs/07_RELEASE_RUNBOOK.md)). Only maintainers can create release tags.

## Becoming a maintainer
A contributor with a record of reviewed, merged contributions (including tests and documentation) can be invited by the existing maintainers. New maintainers are added to AUTHORS.md and CODEOWNERS, and as pub.dev publisher members with 2-step verification.

## Continuity
The project keeps at least two people with admin access to the GitHub organisation and to the `breaktroughf1.com` pub.dev publisher (both with 2-step verification), so releases and security fixes can continue if one maintainer is unavailable.
