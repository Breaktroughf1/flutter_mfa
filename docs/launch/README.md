# Launch (0.2.0)

Everything needed to take flutter_mfa from "merged on `main`" to "published and documented". Status on 7 November 2026: all M0–M4 work is on `main`, every package is at 0.2.0, and `dart pub publish --dry-run` passes with 0 warnings for all five packages. Nothing is tagged or published yet.

| File | What it is | Owner |
|---|---|---|
| [01-website-audit.md](01-website-audit.md) | What the marketing page at breaktroughf1.com/projects/flutter-mfa says today, compared with the code | Web team |
| [02-website-copy.md](02-website-copy.md) | Corrected copy, install and usage snippets, links and structured data, ready to paste | Web team |
| [03-docs-section-plan.md](03-docs-section-plan.md) | The developer docs section on breaktroughf1.com: pages, sources, how to keep them in sync with this repo | Web team + maintainer |
| [04-live-metrics.md](04-live-metrics.md) | Pulling version, pub points, likes and downloads live from pub.dev (and stars from GitHub) | Web team |
| [05-launch-checklist.md](05-launch-checklist.md) | The order of operations, from testing to publish to announcement | Maintainer |
| [06-ardc-testing.md](06-ardc-testing.md) | The test phase at ARDC: what to run, on which devices, and how to report findings | Maintainer + ARDC |

Decisions taken (7 November 2026, maintainer):
- The developer docs live in a section on **breaktroughf1.com**, not on GitHub Pages.
- Numbers on the website are **pulled live from pub.dev** (and GitHub), never typed in.
- The maintainer updates the website copy. The people tests (real-device biometrics, accessibility pass 2, ARDC dynamic test) happen after the merge, at ARDC.
- Development continues on a Debian laptop: see [../DEVELOPMENT.md](../DEVELOPMENT.md).

Open decision: whether passkeys, push approvals or desktop support go on a public roadmap. They are not in 0.2.0. Any of them needs a PRD change and an ADR before code (see [01-website-audit.md](01-website-audit.md)).
