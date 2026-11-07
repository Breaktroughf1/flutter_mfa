# Website audit: breaktroughf1.com/projects/flutter-mfa

Reviewed on 7 November 2026: the served HTML of the case-study page, its embedded page data (Installation, Usage and Examples tabs), its schema.org JSON-LD, `/open-source`, `/llms.txt`, the sitemap, and the blog post *Designing multi-factor authentication users don't hate*. Every outbound link was requested, and every claim was compared with the code on `main`. Visual design and performance were not reviewed. The website's code is not in this repository; fixes are copy changes for the web team ([02-website-copy.md](02-website-copy.md)).

**Summary.** The page describes a different product from the one on `main`: passkeys, push approvals, backup codes, desktop, version 1.x, and an API that does not exist. For a security library, a page that over-promises costs trust as soon as a developer installs the package. Several numbers (stars, contributors, rating) do not match reality either.

## Feature and product claims

| Severity | Where | The page says | The package actually | Fix |
|---|---|---|---|---|
| Critical | Description, meta, Open Graph, JSON-LD, `llms.txt`, open-source page | Passkeys (FIDO2/WebAuthn) | No passkey or WebAuthn support | Remove, or list as roadmap only after a PRD change and an ADR |
| Critical | Same | Push approvals | No push. The packages make no network requests at all | Remove. "No network requests, no telemetry" is a real selling point |
| Critical | Same; "Key features"; "Secure by default" | Backup codes / backup code generation | **Encrypted account backup** (PBKDF2-HMAC-SHA256 + AES-256-GCM export and import). Recovery codes are out of scope (server guide checklist) | "Encrypted backup and restore of accounts" |
| Critical | Description; "Key features"; JSON-LD `operatingSystem: All` | All platforms: mobile, web, desktop | Android 7.0+ (API 24), iOS 15+, web (secure contexts), and Dart servers for verification. No desktop | List the four targets exactly |
| Critical | Usage tab | `FlutterMFA()`, `setupTOTP()`, `verifyTOTP()` on the device | The API is `MfaClient` (app) and `TotpVerifier` (server). Verification belongs on the server by design (ADR-0002): a device checking its own code is not a second factor | Use the snippets in [02-website-copy.md](02-website-copy.md) |
| Critical | Installation tab | `flutter_mfa: ^1.4.2` | The release is 0.2.0; `^1.4.2` cannot resolve | `flutter pub add flutter_mfa` |
| High | Requirements tab | Flutter 3.0+; "For WebAuthn: HTTPS" | Flutter 3.35+, Dart 3.9+, Android minSdk 24, iOS 15. The web vault needs HTTPS or localhost (no WebAuthn) | Requirements block in the copy file |
| High | Description | "OTP" (suggests SMS/email), "enterprise-grade security" | TOTP and HOTP (RFC 6238/4226) only. Security is verifiable, so state the evidence: RFC test vectors, MASVS checklist, published threat model, coverage gates | Replace adjectives with evidence |
| High | Blog post, "How Flutter MFA will help" | Bundles passkeys, biometrics, TOTP, OTP and backup codes behind one API | Biometric-bound protection of stored TOTP/HOTP secrets, plus encrypted backup | Rewrite that closing section once 0.2.0 is out. The general advice in the post is fine |
| Medium | Case study | No mention of ARDC | Every package README credits ARDC, CHRIST (Deemed to be University) | Add the collaboration credit |
| Medium | Case study | One package | Five: core (pure Dart, runs on servers), plugin, ui, qr, platform interface | Show the package table |
| Medium | Case study | No security caveats | The README says the web vault is best-effort: script running in your origin (XSS) can use the key | One honest line builds credibility with security reviewers |

## Numbers and status

| Severity | Where | The page says | Actual (7 Nov 2026) | Fix |
|---|---|---|---|---|
| Critical | Case study, open-source page, terminal demo | Version 1.0.0-b | 0.2.0, not yet on pub.dev | Live version from pub.dev ([04-live-metrics.md](04-live-metrics.md)) |
| Critical | Open-source page | 240 stars (430 across repositories), 12 contributors | 0 stars, 1 contributor (GitHub API) | Live from the GitHub API, or remove |
| Critical | Case study, open-source page | Rating 4.9, Downloads 3 / 3+ | Not published. pub.dev has no star ratings; it shows likes, pub points (out of 160) and downloads | Live pub points, likes and 30-day downloads |
| High | Repository card | Status "Stable" | First public release, 0.x (the API may change before 1.0) | "0.2 · first release" |

The JSON-LD carries no rating or download numbers today, which is correct: invented ratings in schema.org markup break Google's structured-data rules. Keep it that way.

## Links

| Result | Link | Detail | Fix |
|---|---|---|---|
| Broken | `https://breaktroughf1.github.io/flutter_mfa/docs/api` ("API docs") | GitHub Pages is not enabled on the repository (`has_pages: false`) | `https://pub.dev/documentation/flutter_mfa/latest/` (pub.dev builds it on publish) |
| Broken | `https://github.com/Breaktroughf1/flutter_mfa/tree/main/example` (Examples tab) | 404 | `https://github.com/Breaktroughf1/flutter_mfa/tree/main/packages/flutter_mfa/example` |
| Until publish | `https://pub.dev/packages/flutter_mfa` ("View on pub.dev") | 404 until the package is published | Works on publish day |
| OK | GitHub source link, Open Graph image, sitemap entry, canonical URL | 200 / present | None |
