# Developer docs on breaktroughf1.com

**Decision (7 Nov 2026):** the docs live in a section of breaktroughf1.com, not on GitHub Pages. Search ranking stays on the company domain and visitors stay on the marketing site.

## URL

`https://breaktroughf1.com/projects/flutter-mfa/docs/<page>`. It sits under the case study, so the breadcrumb reads Work › Flutter MFA › Docs. `/docs/flutter-mfa/<page>` works too if the site later hosts docs for several projects. Pick one and redirect the other.

## One source of truth

The Markdown in this repository is the source. The website renders it; nobody edits docs in two places.

- At build time, fetch the files from a **release tag** (for example `flutter_mfa-v0.2.0`), not from `main`, so the docs always match the published version. Use `https://raw.githubusercontent.com/Breaktroughf1/flutter_mfa/<tag>/<path>` or a git submodule pinned to the tag.
- Rewrite relative links: `../adr/0002-...md` becomes a GitHub link, a link to another docs page becomes the site route, `packages/...` becomes the GitHub tree URL.
- Render fenced Dart code with syntax highlighting. Keep the tables (the guides use them).
- Each page gets an "Edit on GitHub" link and a "Docs for version x.y.z" label from pub.dev ([04-live-metrics.md](04-live-metrics.md)).
- Rebuild on each release (a webhook on tag push, or the site's normal deploy).

## Pages

| # | Page (route) | Covers | Source in this repo | Work |
|---|---|---|---|---|
| 1 | Overview (`/docs`) | What it is, the five packages, platform support, security model in one paragraph | Root `README.md` | Exists |
| 2 | Getting started (`/docs/getting-started`) | Install, platform setup (Android minSdk, iOS `NSFaceIDUsageDescription`, web HTTPS), first account | `packages/flutter_mfa/README.md` (Install, Quick start, Platform notes) | Exists |
| 3 | Add an authenticator (`/docs/authenticator`) | Scan or type enrolments, live codes, copy, protection levels | `docs/cookbook/add-an-authenticator.md` | Exists |
| 4 | Enrol users (`/docs/enrol-users`) | Relying party: show the QR code, confirm the first code | `docs/cookbook/enrol-users.md` | Exists |
| 5 | Verify on a Dart server (`/docs/server`) | Replay protection, shared attempt limits (Redis, SQL), checklist | `docs/cookbook/verify-on-a-dart-server.md` | Exists |
| 6 | Backup and restore (`/docs/backup`) | Encrypted export and import, passphrase rules, duplicates, new phone | flutter_mfa README, `docs/03_API_SPEC.md` §3, example backup screens | **Write**: `docs/cookbook/backup-and-restore.md` |
| 7 | Widgets (`/docs/widgets`) | Each widget with a screenshot, theming, localisation (en, hi, ar) | `packages/flutter_mfa_ui/README.md`, `packages/flutter_mfa_ui/doc/screenshots/` | Exists; add per-widget images later |
| 8 | QR scanning (`/docs/qr`) | Camera permissions, web BarcodeDetector, CSP | `packages/flutter_mfa_qr/README.md`, ADR-0005 | Exists |
| 9 | Security model (`/docs/security`) | Who verifies, storage per platform, web limits, what it does and does not protect against, how to report a vulnerability | `docs/04_SECURITY_DESIGN.md`, `docs/security/threat-model.md`, `docs/security/masvs-checklist.md`, `SECURITY.md` | **Write**: a developer-facing summary, `docs/cookbook/security-model.md`, linking to the full documents |
| 10 | Accessibility (`/docs/accessibility`) | Screen readers, keyboard, large text, RTL | `docs/a11y-report.md` | Exists; update after pass 2 |
| 11 | FAQ and troubleshooting (`/docs/faq`) | Key invalidated after a new fingerprint; codes rejected (clock drift); web over plain HTTP; uninstall removes accounts; HOTP counter out of sync | Error messages, platform notes | **Write**: `docs/cookbook/faq.md` |
| 12 | Changelog (`/docs/changelog`) | Release notes per package | `packages/*/CHANGELOG.md` | Exists |
| 13 | API reference (external) | Every public type and member | pub.dev dartdoc | Link only: `https://pub.dev/documentation/<package>/latest/` |
| 14 | Contributing (`/docs/contributing`) | How to contribute, DCO, security reports | `CONTRIBUTING.md`, `SECURITY.md` | Exists |

Pages 6, 9 and 11 are the only new writing. They go into `docs/cookbook/` here first, so pub.dev users and GitHub readers get them too.

## Navigation

Sidebar groups: **Start** (1–2) · **Guides** (3–8) · **Reference** (9–13) · **Project** (14). Put a version selector in the header once 0.3 exists; until then, show the live version label.

## Nice to have, later

- **Live web demo** of the example app at `/projects/flutter-mfa/demo`: the output of `flutter build web --wasm`, served over HTTPS with a strict CSP. Label it a demo, because the web vault is best-effort.
- **Screenshots and a short video** on the case study, using the real widget images (light, dark, Arabic RTL, large text) instead of a generic graphic.
- A blog post: **"Why we verify codes on the server"**. It is the design's main difference from other packages (ADR-0002).
