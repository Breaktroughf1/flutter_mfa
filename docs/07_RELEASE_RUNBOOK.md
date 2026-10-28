# 07 — Release Runbook (pub.dev)

## A. One-time setup (do during M0 — some steps take a day)
1. **Verified publisher** `breaktroughf1.com` on pub.dev: sign in with the BF1 Google account → *Create publisher* → verify domain via Google Search Console (DNS TXT record on breaktroughf1.com). Add Noeal and Alfred as publisher admins. Both accounts must have 2-step verification on.
2. **GitHub repo** (decision D4): public, `main` protected — require PR, 1 code-owner review, required status checks (CI jobs `verify`, `test`, `min-sdk`, `goldens`, `web`, `android (API 24)`, `android (API 36)`, `security`, `publish-dry-run`; `ios` runs on main/nightly/`ci:ios`), linear history, signed commits optional, no force-push. Enable secret scanning + push protection, Dependabot alerts, private vulnerability reporting.
3. **Tag protection / rulesets**: only maintainers can create tags matching `*-v*`.
4. **GitHub Environment** `pub.dev`: required reviewer = maintainer; deployment branches/tags limited to `*-v*` tags.
5. **Signing**: maintainers configure SSH or GPG signing for tags (`git tag -s`).

## B. Pre-flight checklist (Checkpoint M4)
- [ ] All Release-blocking requirements (P = M) have passing tests; `docs/STATUS.md` shows every M task done
- [ ] CI green on `main`, including iOS and web integration
- [ ] Coverage gates met; numbers recorded in release notes
- [ ] `pana` 160/160 for all five packages (run locally with current stable Flutter)
- [ ] `dart pub publish --dry-run` clean in dependency order: core → platform_interface → flutter_mfa → ui → qr
- [ ] Every package: README (badges, platform table, install, quick start, security notes, web limitations), CHANGELOG `## 0.2.0`, LICENSE, `example/`, `topics:` (`mfa`, `totp`, `authentication`, `security`, `otp`), `repository:`, `issue_tracker:`, `screenshots:` (ui/qr)
- [ ] Inter-package constraints use caret ranges on the just-released versions (`flutter_mfa_core: ^0.2.0`)
- [ ] MASVS checklist complete; dynamic test report triaged
- [ ] SECURITY.md contact live (D6)
- [ ] AUTHORS.md + credit wording approved (D3)
- [ ] No `dependency_overrides` in any published pubspec

## C. First publish (manual, maintainer) — only for the very first version of each package
pub.dev requires a package to exist before automated publishing can be configured.
```bash
cd packages/flutter_mfa_core && dart pub publish            # pure Dart
cd ../flutter_mfa_platform_interface && flutter pub publish
cd ../flutter_mfa && flutter pub publish
cd ../flutter_mfa_ui && flutter pub publish
cd ../flutter_mfa_qr && flutter pub publish
```
After each: pub.dev → package → **Admin** → *Transfer to publisher* `breaktroughf1.com`.
Then **Admin → Automated publishing → Enable publishing from GitHub Actions**:
- Repository: `Breaktroughf1/flutter_mfa`
- Tag pattern: `<package_name>-v{{version}}` (e.g. `flutter_mfa_core-v{{version}}`)
- Require GitHub Actions environment: `pub.dev`

(If the 0.2.0 versions are what you publish manually, automation starts at 0.2.1.)

## D. Subsequent releases (automated)
1. `melos version --no-git-tag-version` (or manual bumps) on a release PR; update CHANGELOGs; merge.
2. Maintainer creates signed tags in dependency order, one push per package:
   `git tag -s flutter_mfa_core-v0.2.1 -m "flutter_mfa_core 0.2.1" && git push origin flutter_mfa_core-v0.2.1`
3. `publish.yml` runs for that tag, waits for `pub.dev` environment approval, publishes with OIDC.
4. Wait for the package to appear on pub.dev before tagging dependents.

## E. Post-release
- GitHub Release per tag (notes from CHANGELOG), pinned "v0.2.0" umbrella release on the repo.
- Verify pub.dev pages render, scores computed, example tab correct, platform badges (Android, iOS, Web).
- Announcement: BF1 channels + ARDC (credit line: "BreaktroughF1 LLP in collaboration with ARDC, CHRIST (Deemed to be University)").
- Retraction policy: if a release has a security defect, publish a fixed patch immediately and **retract** the bad version on pub.dev (allowed within 7 days of publishing); file a GitHub Security Advisory.
