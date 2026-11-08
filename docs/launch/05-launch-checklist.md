# Launch checklist (0.2.0)

Order matters: test, then publish, then update the website the same day. Publishing and tagging are maintainer-only ([../07_RELEASE_RUNBOOK.md](../07_RELEASE_RUNBOOK.md)).

## Done (7 November 2026)

- [x] M0–M4 merged to `main` (PRs #6–#43, then #49). Superseded Dependabot PRs #1–#5 closed.
- [x] All five packages at **0.2.0**; CHANGELOGs have `## 0.2.0`; sibling constraints are `^0.2.0`.
- [x] `dart pub publish --dry-run`: 0 warnings for every package.
- [x] READMEs release-ready: status line, pub.dev badges, Install sections; `flutter_mfa_ui` declares pub.dev screenshots.
- [x] CI green on the merged code: Android API 24 and 36, iOS simulator, web, the Flutter 3.35.7 floor, coverage gates, goldens, security scan, licence allowlist.
- [x] Website audit, corrected copy, docs section plan and live-metrics plan written (this folder).

## 1. Test phase (ARDC)

- [ ] Run [06-ardc-testing.md](06-ardc-testing.md): real-device biometrics, accessibility pass 2, dynamic security test.
- [ ] Triage every finding: release blocker, 0.2.1, or later. Fix blockers before publishing.
- [ ] Record results in `docs/security/dynamic-test-report.md` and `docs/a11y-report.md`; tick M4-11 in `docs/06_BUILD_PLAN.md`; add a line to `docs/STATUS.md`.

## 2. Pre-flight (runbook §B)

- [ ] CI green on `main`, including iOS.
- [ ] Verified publisher `breaktroughf1.com` on pub.dev; the GitHub `pub.dev` environment requires a maintainer reviewer.
- [ ] `SECURITY.md` contact address receives mail.
- [ ] Do **not** run `melos version` for 0.2.0. The versions are already set; with no tags yet, it would propose 0.2.1.

## 3. Publish (runbook §C)

- [x] Add today's date to each `## 0.2.0` heading in the CHANGELOGs.
- [ ] Tag and publish in dependency order: `flutter_mfa_core` → `flutter_mfa_platform_interface` → `flutter_mfa` → `flutter_mfa_ui` → `flutter_mfa_qr`.
- [ ] After each package lands, run `pana` on the next one and fix findings before publishing it (the dependents can only be scored once their dependencies are on pub.dev).
- [ ] Check each pub.dev page: README, screenshots (ui), example tab, API docs link, platforms, 160/160 pub points.

## 4. Website, same day

- [ ] Apply [02-website-copy.md](02-website-copy.md) to the case study, the open-source page, `/llms.txt` and the JSON-LD.
- [ ] Switch every number to the live source ([04-live-metrics.md](04-live-metrics.md)).
- [ ] Fix the two broken links (API docs, example app).
- [ ] Replace the blog post's closing section.

## 5. Docs section

- [ ] Build the section from [03-docs-section-plan.md](03-docs-section-plan.md), starting with Overview, Getting started, the three guides and Changelog.
- [ ] Write the three new pages in `docs/cookbook/` (backup and restore, security model, FAQ), then publish them on the site.

## 6. Announce

- [ ] LinkedIn and X posts linking pub.dev and the docs.
- [ ] Add the pub.dev link to the GitHub repository's "About" box and topics (`flutter`, `dart`, `mfa`, `totp`, `authentication`, `security`).
