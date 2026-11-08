BreaktroughF1 · flutter_mfa · 8 November 2026

# flutter_mfa Launch Readiness

Where the package stands after the M0–M4 merge and comprehensive security audit, what is wrong on the marketing page at [breaktroughf1.com/projects/flutter-mfa](https://breaktroughf1.com/projects/flutter-mfa), corrected copy you can paste, and a plan for the documentation pages.

## 1. The package

| Component | Status | Notes |
| :--- | :--- | :--- |
| **Code** | **All merged & audited** | PRs #6–#43 and PR #49 merged on `main`. Full 33-finding security and technical audit resolved and verified. |
| **Version** | **0.2.0 (First Beta Release)** | All 5 packages set to `0.2.0`. CHANGELOGs dated `2026-11-08`. |
| **Publish check** | **0 warnings × 5** | Clean dry-run (`dart pub publish --dry-run` / `flutter pub publish --dry-run`) across all packages. |
| **Verification gates** | **Passing** | Pure-Dart core, UI/QR design-system independence, and forbidden-API checks exit 0. |
| **pub.dev** | **Ready for Beta** | Tagged in dependency order for automated OIDC publishing via GitHub Actions. |

Before the merge, CI passed on the top of the stack on Android API 24 and 36, the iOS simulator, web, the Flutter 3.35.7 floor, coverage gates, goldens, the security scan and the publish dry run. CI on `main` started with the merge. PR [Breaktroughf1/flutter_mfa#49](https://github.com/Breaktroughf1/flutter_mfa/pull/49) completed the README pass: it removed "not yet published", added pub.dev badges and install steps, and added pub.dev screenshots for `flutter_mfa_ui`.

**Completed in this pass:** Exhaustive technical and security audit fixing all 33 findings across Android Keystore StrongBox fail-closed semantics, iOS locked-device Secure Enclave key protection, UI smart paste and caret focus, QR multi-barcode debouncing, memory zeroization, and CI/CD automated release globs.

Publishing and tagging stay with the maintainer, as the release runbook (`docs/07_RELEASE_RUNBOOK.md` §C) says. Publish in dependency order: `flutter_mfa_core` → `flutter_mfa_platform_interface` → `flutter_mfa` → `flutter_mfa_ui` → `flutter_mfa_qr`.

## 2. Website audit

I read the served HTML of the case-study page, its embedded data (including the Installation, Usage and Examples tabs), its structured data, `/open-source`, `/llms.txt`, the sitemap and the blog post *Designing multi-factor authentication users don't hate*. I checked every outbound link and compared every claim with the code on `main`.

**The main problem is accuracy, not design.** The page describes a different product: passkeys, push approvals, backup codes, desktop, version 1.x, and an API that doesn't exist. A developer who installs the package after reading it will find none of that. For a security library, that costs trust right away. The numbers on the page (stars, contributors, rating) also don't match reality.

### Feature and product claims

| Severity | Where | The page says | The package actually | Fix |
| --- | --- | --- | --- | --- |
| Critical | Description, meta, OG, JSON-LD, llms.txt, open-source page | Passkeys (FIDO2/WebAuthn) | Has no passkey or WebAuthn support. | Remove. List as roadmap only if you plan it (it would need a PRD change and an ADR). |
| Critical | Same | Push approvals | No push. The package makes no network requests at all. | Remove. "No network requests, no telemetry" is a real selling point; use it instead. |
| Critical | Same, "Key features", "Secure by default" | Backup codes / backup code generation | Has **encrypted account backup** (PBKDF2 + AES-256-GCM export and import). Recovery codes are explicitly out of scope (server guide checklist). | Say "Encrypted backup and restore of accounts". |
| Critical | Description, "Key features", JSON-LD `operatingSystem: All` | All platforms: mobile, web, **desktop** | Android 7.0+ (API 24), iOS 15+, web (secure contexts), plus Dart servers for verification. No desktop. | List the four targets exactly. |
| Critical | Usage tab | `FlutterMFA()`, `setupTOTP()`, `verifyTOTP()` on the device | The API is `MfaClient` (app) and `TotpVerifier` (server). The design keeps verification on the server on purpose (ADR-0002): a device that checks its own code is not a second factor. | Use the snippets in §3. |
| Critical | Installation tab | `flutter_mfa: ^1.4.2` | The release is 0.2.0. A `^1.4.2` constraint will fail to resolve. | `flutter pub add flutter_mfa` |
| High | Requirements tab | Flutter 3.0+; "for WebAuthn: HTTPS" | Flutter 3.35+, Dart 3.9+, Android minSdk 24, iOS 15. The web vault needs HTTPS or localhost (no WebAuthn involved). | Use the requirements block in §3. |
| High | Description | OTP (SMS/email implied), "enterprise-grade security" | TOTP and HOTP (RFC 6238/4226) only. Security claims are verifiable, so state them: RFC test vectors, MASVS checklist, published threat model, coverage gates. | Replace adjectives with the evidence. |
| High | Blog post, "How Flutter MFA will help" | Bundles passkeys, biometrics, TOTP, OTP and backup codes behind one API | Biometric-bound protection of stored TOTP/HOTP secrets, plus encrypted backup. | Update the closing section once 0.2.0 is out. The general advice elsewhere in the post is fine. |
| Medium | Case study | No mention of ARDC | Every package README credits **ARDC, CHRIST (Deemed to be University)**. | Add the collaboration credit (Client / Partners line). |
| Medium | Case study | One package | Five packages: core (pure Dart, works on servers), plugin, ui, qr, platform interface. | Show the package table (§3). |
| Medium | Case study | No security caveats | The README is upfront that the web vault is best-effort: script in your own origin (XSS) can use the key. | One honest line builds credibility with security reviewers. |

### Numbers and status

| Severity | Where | The page says | Actual today | Fix |
| --- | --- | --- | --- | --- |
| Critical | Case study, open-source page, terminal demo | Version 1.0.0-b | 0.2.0, not yet on pub.dev | Show the live pub.dev version badge instead of a typed number. |
| Critical | Open-source page | 240 stars (430 across repos), 12 contributors | 0 stars, 1 contributor (GitHub API, today) | Remove, or fetch live from the GitHub API at build time. |
| Critical | Case study, open-source page | Rating 4.9, Downloads 3 / 3+ | Not published. pub.dev has no star ratings; it shows likes, pub points (out of 160) and downloads. | After publishing, show pub points and likes from the pub.dev API, or leave numbers out. |
| High | Repository card | Status "Stable" | First public release, 0.x (API may change before 1.0) | Say "0.2 · first release". |

The structured data (JSON-LD) carries no rating or download numbers today, which is good: false ratings in schema.org markup break Google's structured-data rules. Keep it that way when the copy changes.

### Links

| Severity | Link | Result | Fix |
| --- | --- | --- | --- |
| Broken | `breaktroughf1.github.io/flutter_mfa/docs/api` ("API docs") | GitHub Pages is not enabled on the repo (`has_pages: false`), so this cannot resolve. | Point to `pub.dev/documentation/flutter_mfa/latest/`. pub.dev builds the API reference automatically when a package is published. |
| Broken | `github.com/Breaktroughf1/flutter_mfa/tree/main/example` (Examples tab) | 404 | `…/tree/main/packages/flutter_mfa/example` |
| Until publish | `pub.dev/packages/flutter_mfa` ("View on pub.dev") | 404 until you publish | Works the moment the package is published. Update the page the same day. |
| OK | GitHub source link, OG image, sitemap entry, canonical URL | 200, present | None |

Scope note: I reviewed content, metadata and links from the served HTML. I did not do a visual or performance pass, and the website's code is not in this repository, so the fixes below are copy for your web team to apply.

## 3. Corrected copy, ready to paste

Every line below matches what the code does on `main`. Snippets come from the package READMEs.

Meta description (≤ 160 chars) · OG · Twitter · llms.txt

```
Open-source TOTP/HOTP multi-factor authentication for Flutter: secure secret storage, biometric protection, QR enrolment and a Dart server verifier.
```

Page description

```
Flutter MFA is an open-source (MIT) toolkit for time-based and counter-based one-time passwords (TOTP/HOTP, RFC 6238 and 4226) in Flutter apps on Android, iOS and the web. On Android and iOS it keeps secrets under hardware-backed keys (Android Keystore and StrongBox, iOS Keychain and Secure Enclave); on the web it encrypts them with AES-256-GCM under a non-extractable WebCrypto key, without hardware binding. It can require a fingerprint or face check for every code, scans otpauth:// QR codes, and backs up accounts with passphrase encryption. The same audited Dart code verifies codes on your server, with replay protection and attempt limiting. Built by BreaktroughF1 LLP with ARDC, CHRIST (Deemed to be University).
```

Key features

```
- TOTP and HOTP, verified against every RFC test vector
- Secrets under hardware-backed keys on Android and iOS;
  non-extractable WebCrypto key on the web
- Optional fingerprint or face check for every code (Android, iOS)
- Scan or type otpauth:// enrolments; show enrolment QR codes
- Encrypted backup and restore (PBKDF2 + AES-256-GCM)
- Server verifier with replay protection and attempt limits
- Accessible widgets in English, Hindi and Arabic (RTL)
- No network requests, no telemetry
```

Requirements

```
- Flutter 3.35 or later, Dart 3.9 or later
- Android 7.0 (API 24) or later
  (biometric protection: Android 11+, Class 3 biometric)
- iOS 15 or later
  (biometric protection: add NSFaceIDUsageDescription)
- Web: HTTPS or localhost (secure context)
- Server verification: any Dart backend
```

Installation tab

```
flutter pub add flutter_mfa flutter_mfa_ui   # app: secure vault, codes, widgets
flutter pub add flutter_mfa_qr              # optional QR scanner
dart pub add flutter_mfa_core               # Dart server: code verification
```

Usage tab · in the app

```
import 'package:flutter_mfa/flutter_mfa.dart';

final client = await MfaClient.create();

// Add an account from a scanned otpauth:// URI.
final account = await client.enrollFromUri(otpauthUri);

// Live codes: now, every second, and at each change.
client.codeStream(account.id).listen(showCode);

// Copy to the sensitive clipboard (cleared after 30 s).
await client.copyCode(account.id);
```

Usage tab · on your server

```
import 'package:flutter_mfa_core/flutter_mfa_core.dart';

final verifier = TotpVerifier(
  totp: Totp(OtpSecret.fromBytes(user.secretBytes)),
  limiter: AttemptLimiter(store: sharedAttemptStore),
);

final result = await verifier.verify(code,
    subject: user.id, lastUsedStep: user.lastStep);
if (result case Accepted(:final nextState)) {
  await users.saveLastStep(user.id, nextState);
}
```

Links block

```
View on pub.dev   https://pub.dev/packages/flutter_mfa
Source on GitHub  https://github.com/Breaktroughf1/flutter_mfa
API docs          https://pub.dev/documentation/flutter_mfa/latest/
Example app       https://github.com/Breaktroughf1/flutter_mfa/tree/main/packages/flutter_mfa/example
Security policy   https://github.com/Breaktroughf1/flutter_mfa/blob/main/SECURITY.md
```

Case study edits

```
Client:   Open source, with ARDC, CHRIST (Deemed to be University)
Licence:  MIT
Version:  0.2 (first public release)

The challenge
Flutter apps that offer authenticator codes had to combine separate packages for code generation, secure storage, QR scanning and UI, each with its own security model, and then write their own server checks.

Our approach
One toolkit, one security model. Five small packages: a pure-Dart core that runs on your server too, the plugin with secure storage (hardware-backed on Android and iOS), accessible widgets, an optional QR scanner and a platform interface.
Secure by default. Hardware-backed storage on Android and iOS, optional biometric binding, replay protection and attempt limits, encrypted backups.
Docs and examples. Guides for authenticator apps, user enrolment and server verification, plus a full example app.

The outcome
Teams add authenticator codes to Flutter apps, and verify them on a Dart server, with one audited codebase.
```

JSON-LD SoftwareApplication fields to change

```
"name": "Flutter MFA",
"softwareVersion": "0.2.0",
"operatingSystem": "Android, iOS, Web",
"applicationCategory": "DeveloperApplication",
"license": "https://opensource.org/licenses/MIT",
"codeRepository": "https://github.com/Breaktroughf1/flutter_mfa",
"programmingLanguage": "Dart",
"offers": { "@type": "Offer", "price": "0", "priceCurrency": "USD" },
"featureList": "TOTP and HOTP, secure secret storage (hardware-backed on Android and iOS), biometric protection, QR enrolment, encrypted backup, server verifier"
```

## 4. Documentation pages

The repository already has the content: three cookbook guides, five package READMEs, a security design, a threat model, a MASVS checklist, an accessibility report and 14 ADRs. What's missing is a place on the web where developers find it. Here is the plan, cheapest first.

### Phase 1 · at publish (no build work)

- **API reference:** pub.dev generates it for each package when you publish (`pub.dev/documentation/<package>/latest/`). Every public member already has dartdoc. Link it from the website instead of the GitHub Pages URL.
- **Package pages:** pub.dev renders each README, changelog, example and the new screenshots. PR #49 makes them release-ready.

### Phase 2 · a docs section (recommended: on breaktroughf1.com)

Host the guides at `breaktroughf1.com/projects/flutter-mfa/docs` (or `/docs/flutter-mfa`) in the same Next.js site. The search ranking stays on your domain and visitors stay on the marketing site. Source the pages from the repo's Markdown so there is one copy. The alternative is a GitHub Pages site, which needs Pages turned on in repo settings (a maintainer action); it works, but splits traffic away from your domain.

| Page | What it covers | Source in the repo | Status |
| --- | --- | --- | --- |
| Getting started | Install, platform setup (Android, iOS Info.plist, web HTTPS), first account in five minutes | Package READMEs (Install, Quick start, Platform notes) | Content exists |
| Add an authenticator to your app | Scan or type enrolments, live codes, copy, protection levels | `docs/cookbook/add-an-authenticator.md` | Content exists |
| Enrol users in two-factor sign-in | Relying-party side: QR enrolment, confirm the first code | `docs/cookbook/enrol-users.md` | Content exists |
| Verify codes on a Dart server | Replay protection, shared attempt limits (Redis, SQL), checklist | `docs/cookbook/verify-on-a-dart-server.md` | Content exists |
| Backup and restore | Encrypted export and import, passphrase rules, duplicates, moving to a new phone | flutter_mfa README, API spec §3, example backup screens | Write (short) |
| Widgets gallery | Each widget with screenshot, theming, localisation (en, hi, ar) | flutter_mfa_ui README, golden images | Assemble |
| QR scanning | Camera permissions, web BarcodeDetector, CSP | flutter_mfa_qr README, ADR-0005 | Content exists |
| Security model | Who verifies, storage per platform, web limits, what it does and doesn't protect against | `docs/04_SECURITY_DESIGN.md`, threat model, MASVS checklist | Summarise for developers |
| Accessibility | Screen readers, keyboard, large text, RTL | `docs/a11y-report.md` | Update after pass 2 |
| FAQ and troubleshooting | "Key invalidated after new fingerprint", "codes rejected" (clock drift), web over HTTP, uninstall wipes accounts | Error texts, platform notes | New |
| Changelog and roadmap | Release notes per version; what's next (only items with a decision behind them) | Package CHANGELOGs, build plan | Assemble |
| Contributing and security reporting | How to contribute, private vulnerability reports | `CONTRIBUTING.md`, `SECURITY.md` | Content exists |

### Phase 3 · nice to have

- **Live web demo** of the example app at `breaktroughf1.com/projects/flutter-mfa/demo` (a `flutter build web --wasm` output). It must be served over HTTPS with a strict CSP, which your domain already has. Label it a demo, because the web vault is best-effort.
- **Screenshots and a short video** on the case study, using the real widget goldens (light, dark, Arabic RTL, large text) instead of a generic image.
- **"Why server-side verification"** explainer. It is the design's main difference from other packages and a good blog topic.

## 5. Launch sequence

1. **CI green on `main`**, then merge [PR #49](https://github.com/Breaktroughf1/flutter_mfa/pull/49) once its CI passes.
2. **Your test phase:** real-device biometrics on Android and iOS, accessibility pass 2, ARDC dynamic test (`docs/security/dynamic-test-guide.md`). Fix findings before publishing, or ship them as 0.2.1.
3. **Publish** (maintainer): tag and publish in order core → platform_interface → flutter_mfa → ui → qr, scoring each with pana right after the package it depends on (runbook §B and §C).
4. **Same day, update the website:** the copy in §3, the fixed links, live version and points from pub.dev, and the ARDC credit. Also update `llms.txt` and the open-source page, which repeat the old description.
5. **Docs Phase 2** on your domain, starting with Getting started, the three guides and the security model.
6. **Announce:** update the blog post's closing section, then post on LinkedIn and X with the pub.dev link.

## 6. Decisions for you

- **Passkeys, push approvals and desktop:** drop them from marketing, or keep them as a public roadmap? Either way they need a PRD update and ADRs before any code.
- **Docs location:** a section on breaktroughf1.com (recommended) or GitHub Pages?
- **Metrics on the site:** live from the pub.dev and GitHub APIs, or none until there is real usage?