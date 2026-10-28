# 00 — Study of the ARDC × BreaktroughF1 Flutter MFA Proposal

| | |
|---|---|
| Source document | "ARDC × BreaktroughF1 – Flutter MFA Internship Proposal", dated 24 September 2025 |
| Study prepared | 28 October 2026 |
| Prepared for | BreaktroughF1 LLP (product owner / maintainer) and Claude Code (implementer) |
| Status | Baseline for build. Supersedes the proposal where this study says so (see §6). |

---

## 1. What the proposal commits us to

### 1.1 The product
`flutter_mfa` — an open-source, MIT-licensed Multi-Factor Authentication plugin for Flutter covering Android, iOS and Web, published on pub.dev by BreaktroughF1 LLP "in collaboration with ARDC, CHRIST (Deemed to be University)".

### 1.2 MVP feature commitments (proposal §5.1)
| # | Commitment | Source |
|---|---|---|
| P-F1 | TOTP and HOTP enrollment and verification per RFC 6238 / RFC 4226 | §1, §5.1 |
| P-F2 | Secure storage bindings: Android Keystore, iOS Keychain / Secure Enclave, WebCrypto / IndexedDB | §5.1 |
| P-F3 | QR enrollment: parse and display `otpauth://` URIs; camera scanner with permission UX | §5.1 |
| P-F4 | UI widgets: 6–8 digit code input, status badges, accessibility and i18n scaffolding | §5.1 |
| P-F5 | Example apps on Android, iOS, Web demonstrating enroll / verify | §5.1 |
| P-F6 | Backup export/import; biometrics wrapper; threat model v1 | §7 (M3) |
| P-F7 | Rate-limit / lockout patterns; root/jailbreak check hooks | §3.2, §5.2, §7 (M4) |

### 1.3 Quality commitments (proposal §3.2, §5.2, Annex E)
| # | Commitment |
|---|---|
| P-Q1 | Coverage ≥ 85 % lines and ≥ 75 % branches across core and widgets |
| P-Q2 | Unit, widget/golden and integration tests; integration on an Android/iOS/Web matrix via CI |
| P-Q3 | "MASVS-L1-aligned" checklist satisfied; no hard-coded secrets |
| P-Q4 | CI gates: format, lint, tests, coverage (Codecov); protected `main`; CODEOWNERS; required checks |
| P-Q5 | Conventional commits, semantic versioning, signed tags, CHANGELOG |
| P-Q6 | Docs: README, API docs, cookbooks, CONTRIBUTING, SECURITY, AUTHORS, CODE_OF_CONDUCT; ADRs in `/docs/decisions` |
| P-Q7 | Static analysis, dependency audits, SAST, dependency pinning and vulnerability scans |
| P-Q8 | Accessibility (TalkBack/VoiceOver, focus order, contrast); i18n scaffolding (English first, Hindi/Arabic ready) |

### 1.4 Release and governance commitments
| # | Commitment |
|---|---|
| P-R1 | Public **v0.2** on pub.dev with documentation and credits |
| P-R2 | Suggested packages: `flutter_mfa_core`, `flutter_mfa_ui`, `flutter_mfa_platform`, `flutter_mfa_examples` |
| P-R3 | MIT licence; contributions via DCO or lightweight CLA |
| P-R4 | Attribution in AUTHORS.md, README "Contributors", pub.dev publisher credit line |
| P-R5 | Privacy: no real secrets or PII; test keys only; no sensitive logs |
| P-R6 | Disclosure policy email maintained by BF1 |
| P-R7 | Acceptance: all planned PRs merged with green CI and code-owner approval, tag + release, credits, certificates, post-mortem |

### 1.5 Explicitly out of scope for MVP (proposal §5.3)
Push-based MFA backend, WebAuthn/Passkeys beyond a minimal POC, device attestation integrations.

---

## 2. What has changed since the proposal was written (Sep 2025 → Oct 2026)

The proposal is thirteen months old. Several things it names have moved:

1. **OWASP MASVS no longer has "L1".** MASVS v2.0.0 (April 2023) removed the L1/L2/R verification levels from the standard itself; they now exist as the **MAS-L1, MAS-L2 and MAS-R testing profiles** in the companion guides (MASTG/MASWE). "MASVS-L1-aligned" should be restated as *"MASVS v2 controls, verified against the MAS-L1 testing profile"*. Root/jailbreak detection belongs to MAS-R (resilience), not L1 — it stays a *hook*, not a claim. We also map MASVS-PRIVACY (added in v2.1.0).
2. **Flutter/Dart versions.** Current stable is Flutter 3.47.x with Dart 3.13 (August 2026). Flutter 3.50 is scheduled for November 2026 and is where the Material and Cupertino libraries are formally deprecated out of the core SDK into standalone packages. → `flutter_mfa_ui` must not hard-depend on Material (see ADR-0006).
3. **Monorepo tooling.** Dart pub workspaces (Dart ≥ 3.6) are now the native way to run a multi-package repo; Melos 7 sits on top of them. Workspace globs arrive in Dart 3.11.
4. **pub.dev publishing.** Automated publishing from GitHub Actions via OIDC (no stored credentials) is the recommended route, with per-package tag patterns and an optional required GitHub Environment. It can only be enabled on a package **after** it exists on pub.dev, so every package's first version is published manually.
5. **Web secure storage in the ecosystem is weak.** `flutter_secure_storage`'s web implementation is still labelled experimental and keeps its key material in LocalStorage. That does not meet the proposal's "WebCrypto/IndexedDB" commitment — we write our own web vault (ADR-0003).
6. **Web QR scanning loads code from a CDN.** `mobile_scanner` on web falls back to a ~2 MB zxing-wasm binary pulled from jsDelivr at runtime when the browser has no native `BarcodeDetector` (Firefox). For a security library this is a supply-chain and CSP concern → default to the native detector, document a self-hosted script URL, and keep the scanner in a separate optional package (ADR-0005).

---

## 3. Gaps and problems found in the proposal

Ranked by impact on the build.

### 3.1 Critical — must be resolved in the design

**G1. The authenticator role and the verifier role are conflated.** The proposal says "enrollment & verification" without saying *who* verifies. In real MFA:
- the **authenticator** (the user's device) holds the secret and *generates* codes;
- the **verifier** (the relying party's server) holds a copy of the secret and *checks* codes, enforcing replay protection and throttling.

A client-side "verify" that unlocks something on the same device as the secret adds no second factor. Client-side rate limits and lockouts are advisory — an attacker with the device bypasses them.
→ **Resolution:** `flutter_mfa_core` is pure Dart with zero Flutter dependency so the **same verifier code runs on a Dart server** (shelf, dart_frog, serverpod) *and* on-device for legitimate local scenarios (offline step-up, app-lock PIN-plus-TOTP demos). The docs state plainly that the authoritative verifier belongs on the server. Rate-limit/lockout ships as a pluggable `AttemptLimiter` with an in-memory default and a store interface, so the server can back it with Redis/DB. (ADR-0002)

**G2. "Secure Enclave" cannot store an OTP secret.** The iOS Secure Enclave only generates and holds P-256 private keys; it cannot hold arbitrary bytes or compute HMAC-SHA1. Proposal §5.1 implies otherwise.
→ **Resolution:** TOTP seeds live in the Keychain (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, never synced to iCloud). Optional hardening: envelope-encrypt each seed with a Secure-Enclave P-256 key (ECIES, `eciesEncryptionCofactorVariableIVX963SHA256AESGCM`) so the Keychain blob is useless off-device; biometric gating via `SecAccessControl` with `.biometryCurrentSet`. (ADR-0004)

**G3. A "biometrics wrapper" that returns a boolean is bypassable.** `local_auth`-style `authenticate() → bool` can be hooked at runtime (Frida) and is called out in MASTG as a weak pattern. MASVS-AUTH-2 expects biometrics to be bound to a cryptographic operation.
→ **Resolution:** Biometric gating is implemented *inside the vault*: Android uses a Keystore key with `setUserAuthenticationRequired(true)` unlocked through `BiometricPrompt` + `CryptoObject`; iOS uses Keychain access control. The secret cannot be decrypted without the biometric event. No standalone `bool isAuthenticated` API is exposed. (ADR-0004)

**G4. Backup/export is the highest-risk feature and is underspecified.** An exported file containing OTP seeds is equivalent to every second factor the user owns.
→ **Resolution:** Encrypted-only export (no plaintext export API at all), versioned container format, AES-256-GCM, key from a user passphrase via PBKDF2-HMAC-SHA256 at ≥ 600 000 iterations (OWASP 2023 guidance), random 16-byte salt, 12-byte nonce, header bound as AAD, minimum passphrase strength check. Import validates and never partially applies. Format documented in `02_ARCHITECTURE.md §7`. (ADR-0007)

### 3.2 Significant

**G5. "MASVS-L1-aligned checklist"** — outdated terminology (§2.1). Replaced by a control-by-control mapping in `04_SECURITY_DESIGN.md §5`.

**G6. Package layout does not match Flutter's plugin model.** The proposal's `flutter_mfa_platform (android/ios/web)` + `flutter_mfa_examples` is not how pub.dev or the Flutter tool expects plugins. Example apps must live in each package's `example/` folder to earn pub points, and platform code must be either in-package or federated with a platform interface.
→ **Resolution:** five packages (ADR-0001):
`flutter_mfa_core` (pure Dart) · `flutter_mfa_platform_interface` · `flutter_mfa` (app-facing plugin with Android/iOS/Web implementations in-package) · `flutter_mfa_ui` (widgets) · `flutter_mfa_qr` (optional camera scanner).

**G7. Branch coverage on native code.** Dart coverage tools only measure Dart. Kotlin and Swift vault code needs its own JUnit/XCTest suites, measured separately (JaCoCo / `xccov`). The 85/75 gate applies to Dart packages; native code gets its own lower-bound gate set in Phase 0 once tooling is proven.

**G8. Golden tests are platform-sensitive.** Goldens rendered on macOS differ from Linux. → Goldens run on a single pinned Linux CI image only; other jobs skip the `golden` tag.

**G9. iOS integration tests need macOS runners.** Free for public GitHub repos; budget-relevant only if the repo is private during development. → Keep the repo public from M0 (it is MIT anyway), or accept macOS runner minutes.

**G10. otpauth URI is not an RFC.** It is the de-facto "Key Uri Format" from Google Authenticator. Many authenticator apps ignore `algorithm`, `digits` and `period`. → Parser is strict on what it accepts, lenient on optional params; generator emits a compatibility warning when non-default parameters are used. (See `03_API_SPEC.md §3`.)

### 3.3 Minor / housekeeping

- **G11.** Proposal §2.1 names internal products "Firse, Findly, CodeBreak". Public README must not list internal BF1 products beyond what BF1 approves for marketing. No proprietary BF1 code, names or references (SPECTRA, LYNX, PHALANX internals, client data) go into this public repo — consistent with the ARDC IP boundary.
- **G12.** Proposal subtitle "Seamless MFA Across Devices" — the only cross-device capability in scope is encrypted export/import. No sync service. README must not imply sync.
- **G13.** Proposal §4 has a stray "(" before "Method". Cosmetic.
- **G14.** No package-name check was done. `flutter_mfa` did not surface on pub.dev in searches on 28 October 2026, but names cannot be reserved without publishing. → Verify availability at Phase 0; publish `flutter_mfa_core 0.1.0-dev.1` as soon as M1 is green to hold the namespace (§6, decision D1).
- **G15.** No minimum SDK floor stated. → Dart `>=3.9.0 <4.0.0`, Flutter `>=3.35.0`; Android `minSdk 24` (Keystore AES-GCM, BiometricPrompt via AndroidX; Flutter 3.47 rejects ≤ 23); iOS 15.0 (Flutter 3.47 minimum deployment target); Web: secure contexts only (HTTPS/localhost) because WebCrypto requires it.
- **G16.** Accessibility: a 6–8-box OTP input is a common screen-reader failure (each box announced separately). → Implement as **one** semantic text field with a visual segmented presentation; supports `AutofillHints.oneTimeCode` and paste of the whole code.

---

## 4. The build model has changed — implications

The proposal assumed ARDC student squads write the code over 8–10 weeks with BF1 reviewing. The plan now is that **Claude Code builds the plugin** under BF1's direction. That changes three things the proposal promised, and they need a decision before publication, not after:

| Proposal promise | Effect of Claude Code building it | Needs decision |
|---|---|---|
| Certificates on "assigned scope accepted", PRs, demos (Annex C) | Students would not author the bulk of the code | D2 — what students do instead (see below) |
| AUTHORS.md / pub.dev credits for "all student contributors" | Credits must reflect who actually did what | D3 — attribution wording |
| Educational internship delivered by ARDC | Still possible, but the learning activity shifts | D2 |

A workable shape for D2 that keeps the ARDC commitment honest: Claude Code produces each milestone as reviewable PRs; ARDC students act as **reviewers, security testers and documentation authors** — running the MAS-L1 test checklist on real devices, writing threat-model reviews, attacking the example apps (Frida hooking of the biometric path, backup extraction, clipboard leakage), writing cookbook pages and translations (hi/ar scaffolding). These map cleanly onto the existing rubric rows (Testing quality, Security hygiene, Documentation, Collaboration) and onto the Testing/Security and Documentation tracks the proposal already defines.

For D3, recommended AUTHORS.md wording: maintainers (BF1), contributors (named humans with what they did), and a one-line note that implementation was AI-assisted under maintainer review. Transparent, and it protects the credibility of ARDC's name on the package.

---

## 5. Feasibility and effort

| Workstream | Complexity | Main risk |
|---|---|---|
| Core OTP, base32, otpauth URI, verifier, limiter | Low | Subtle RFC bugs (key length per algorithm in RFC 6238 vectors, 8-digit modulo, Base32 padding/case) — mitigated by vector tests + property tests |
| Platform interface + method channels (Pigeon) | Medium | API churn — freeze interface at end of M1 |
| Android vault (Keystore, StrongBox, BiometricPrompt+CryptoObject) | Medium-High | OEM Keystore quirks; key invalidation on biometric enrol change |
| iOS vault (Keychain, SE envelope, access control) | Medium-High | Simulator has no Secure Enclave — tests need a device or SE-off path |
| Web vault (non-extractable AES-GCM key in IndexedDB) | Medium | Browser storage eviction; private-mode failures; XSS is unmitigable by design |
| UI widgets (Material-independent, a11y, i18n, goldens) | Medium | Flutter 3.50 Material split |
| QR package | Low | Web CDN loading (handled by config) |
| Export/import | Medium | Crypto parameter mistakes — mitigated by known-answer tests |
| CI matrix incl. iOS + web integration | Medium | Runner flakiness; emulator boot times |
| Publishing 5 packages in dependency order | Low | First publish is manual; verified publisher setup on breaktroughf1.com |

**Realistic calendar with Claude Code doing implementation and BF1 reviewing:** 6–8 weeks to v0.2.0, gated mostly by device testing and review bandwidth, not code-writing speed. The build plan (`06_BUILD_PLAN.md`) keeps the proposal's milestone names M0–M4 + Release so ARDC paperwork still lines up.

---

## 6. Decisions — what this study changes (summary)

| Ref | Proposal said | We will do | Why | ADR |
|---|---|---|---|---|
| C1 | 4 packages incl. `flutter_mfa_platform`, `flutter_mfa_examples` | 5 packages: core, platform_interface, flutter_mfa, ui, qr; examples in `example/` | pub.dev/Flutter plugin conventions; optional camera dependency | 0001 |
| C2 | "Enrollment & verification" | Authenticator and Verifier as separate APIs; core is pure Dart and server-usable | Real MFA security model | 0002 |
| C3 | WebCrypto/IndexedDB | Own web vault, non-extractable AES-GCM key in IndexedDB; no `flutter_secure_storage` on web | Ecosystem option stores key in LocalStorage | 0003 |
| C4 | Keychain/Secure Enclave; biometrics wrapper | Keychain + optional SE envelope; biometric gating bound to crypto in the vault | SE can't hold HMAC seeds; boolean biometrics bypassable | 0004 |
| C5 | Camera scanner in the plugin | Separate `flutter_mfa_qr`; native BarcodeDetector default on web | Optional heavy dependency; CDN supply chain | 0005 |
| C6 | UI widgets | Built on `widgets` layer with own theme; Material/Cupertino adapters thin | Flutter 3.50 Material split | 0006 |
| C7 | Export/import | Encrypted-only, versioned, PBKDF2 600k + AES-256-GCM | Highest-risk feature | 0007 |
| C8 | "MASVS-L1" | MASVS v2 controls + MAS-L1 profile mapping | Standard changed | — |
| C9 | Codecov | Codecov **or** self-hosted coverage gate (`tool/coverage_gate.dart`) — CI fails on threshold without depending on a third-party token | Gate must not be bypassed by an outage | 0008 |
| C10 | Signed tags | Signed tags + pub.dev OIDC automated publishing with required `pub.dev` environment | No long-lived credentials | 0008 |

---

## 7. Open decisions for BF1 (blocking marked ★)

| ID | Decision | Recommended | Blocks |
|---|---|---|---|
| D1 ★ | Confirm package names (`flutter_mfa*`) after availability check; fallback prefix `bf1_mfa*` | Keep `flutter_mfa*` if free | Phase 0 |
| D2 ★ | Student role now that Claude Code implements | Reviewers / security testers / docs + translations | ARDC communication, certificates |
| D3 | AUTHORS.md attribution wording incl. AI-assisted note | As in §4 | Release |
| D4 ★ | GitHub org + repo name (`breaktroughf1/flutter_mfa`?) and who are CODEOWNERS | BF1 org, Noeal as code owner | Phase 0 |
| D5 ★ | pub.dev verified publisher `breaktroughf1.com` (DNS TXT via Google Search Console) | Set up now — takes a day | First publish |
| D6 | Security disclosure address | `security@breaktroughf1.com` (separate from info@) | SECURITY.md |
| D7 | DCO vs CLA | DCO (sign-off), lighter for students | CONTRIBUTING.md |
| D8 | Repo public from day one | Yes (free macOS CI minutes, it's MIT anyway) | CI cost |
| D9 | Hindi/Arabic strings in v0.2 or scaffolding only | Scaffolding + English; hi/ar as student contribution | i18n scope |

Every decision has a default in this pack, so Claude Code can start Phase 0 immediately and the defaults can be swapped later; only D1, D4 and D5 must be settled before anything is pushed or published.
