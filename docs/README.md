# flutter_mfa — project docs

| File | Purpose | Read when |
|---|---|---|
| [00_STUDY.md](00_STUDY.md) | Analysis of the ARDC proposal: commitments, what changed since 2025, gaps, decisions, open questions | Background; before changing scope |
| [01_PRD.md](01_PRD.md) | Requirements with IDs and acceptance criteria | Every task |
| [02_ARCHITECTURE.md](02_ARCHITECTURE.md) | Packages, layering, platform vaults, error model, backup format | Every task |
| [03_API_SPEC.md](03_API_SPEC.md) | Public API contract | Any public API work |
| [04_SECURITY_DESIGN.md](04_SECURITY_DESIGN.md) | Threat model, MASVS v2 mapping, crypto inventory, secure coding rules | Any security-relevant work (most of it) |
| [05_TEST_PLAN.md](05_TEST_PLAN.md) | Test layers, gates, RFC vectors, device matrix, Definition of Done | Writing tests |
| [06_BUILD_PLAN.md](06_BUILD_PLAN.md) | Ordered tasks M0–M4 + Release with checkpoints | Choosing the next task |
| [07_RELEASE_RUNBOOK.md](07_RELEASE_RUNBOOK.md) | pub.dev setup, first publish, automated releases | M0 setup and Release |
| [STATUS.md](STATUS.md) | Live progress log | After every task |
| [DEVELOPMENT.md](DEVELOPMENT.md) | Workstation setup on Debian/Ubuntu: Flutter, Android, web and iOS testing, the CI checks locally | Setting up a machine |
| [launch/](launch/README.md) | 0.2.0 launch: website audit and copy, docs section plan, live pub.dev numbers, launch checklist, ARDC test phase | Release and website work |
| [adr/](adr/) | Architecture decision records 0001–0014 | Before revisiting a design choice |

Later additions (created during the build): `security/threat-model.md`, `security/masvs-checklist.md`, `security/dynamic-test-guide.md`, `security/dynamic-test-report.md`, `a11y-report.md`, `cookbook/*.md`.
