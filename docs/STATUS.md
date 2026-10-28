# Build status

Updated by Claude Code after every task. Newest at the bottom.

| Date | Task | Status | Commit / PR | Coverage | Notes / deviations |
|---|---|---|---|---|---|
| 28 Oct 2026 | — | Docs pack created | — | — | Baseline docs, ADR-0001..0008, CI scaffold |
| 28 Oct 2026 | M0-01 | Done | see git log | — | Toolchain verified; Android SDK + Xcode unavailable locally (CI only) |
| 28 Oct 2026 | M0-02 | Done | see git log | — | All 5 names unclaimed; D1 confirmed by maintainer |

## Environment (M0-01)
Verified 28 Oct 2026 in the Claude Code cloud container (Ubuntu 24.04, x86_64). Sources: Flutter release manifest, pub.dev API, developer.android.com.

| Tool | Version found | Notes |
|---|---|---|
| Flutter | **3.47.8** stable (rev 737ba8f885, 22 Oct 2026) | Installed from the official archive, SHA-256 verified. The scaffold's "3.38.6" was stale. |
| Dart | **3.13.7** (bundled with Flutter) | Workspace floor stays `>=3.9.0 <4.0.0` (Flutter 3.35.7 ships Dart 3.9.2) |
| Melos | **8.10.0** (latest; 7.x line ends at 7.8.2) | Scaffold pinned `^7.0.0`; moved to 8.x (M0-03) |
| lints | 6.1.0 | `^6.0.0` already correct |
| coverage / test | 1.16.0 / 1.33.0 | |
| Java / Gradle | OpenJDK 21.0.12, Gradle 8.14.3 | |
| Android SDK / emulator | **Not available** | `dl.google.com` blocked by the container's network policy, so the SDK can't be installed; `maven.google.com` works. Android builds and tests run only in GitHub CI. Latest stable platform: **API 36** (Android 16). |
| Xcode / simulator | **Not available** (Linux) | iOS validated only in CI (`macos-latest`) and on maintainer devices |
| Chrome | Playwright Chromium (`CHROME_EXECUTABLE=/opt/pw-browsers/chromium-1243/chrome-linux64/chrome`) | Web tests and `--wasm` builds run locally |
## Package name availability (M0-02)
Checked 28 Oct 2026 against `https://pub.dev/api/packages/<name>` (404 = no package with that name exists) and pub.dev search (no confusingly similar `flutter_mfa*` packages found). A name can't be reserved without publishing, so these stay free only until someone claims them. Plan: publish `flutter_mfa_core 0.1.0-dev.1` as soon as M1 is green (G14).

| Package | Available on pub.dev? |
|---|---|
| flutter_mfa_core | Yes (404) |
| flutter_mfa_platform_interface | Yes (404) |
| flutter_mfa | Yes (404) |
| flutter_mfa_ui | Yes (404) |
| flutter_mfa_qr | Yes (404) |

## Open decisions
See docs/00_STUDY.md §7. Record outcomes here: D1 **confirmed `flutter_mfa*`** (maintainer, 28 Oct 2026), D2 _, D3 _, D4 Breaktroughf1/flutter_mfa (CODEOWNERS: @NoealRajeev), D5 _, D6 _, D7 DCO (default), D8 Public, D9 _.
