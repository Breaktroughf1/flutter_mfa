# ADR-0001: Five-package layout with in-package platform implementations

- Status: Accepted (28 October 2026)
- Supersedes: proposal §6.1 suggested packages

## Context
The proposal suggested `flutter_mfa_core`, `flutter_mfa_ui`, `flutter_mfa_platform (android/ios/web)`, `flutter_mfa_examples`. Flutter plugins must either keep platform code in the app-facing package or federate it behind a platform interface. pub.dev scores examples only when they live in each package's `example/`. A camera/ML Kit dependency adds 3–10 MB on Android and should be optional. A server-side verifier must not pull in Flutter.

## Decision
`flutter_mfa_core` (pure Dart) · `flutter_mfa_platform_interface` · `flutter_mfa` (plugin; Android/iOS/Web code in-package) · `flutter_mfa_ui` (widgets, depends on core only) · `flutter_mfa_qr` (scanner, optional). Examples live in `example/` of each package; the full demo is `flutter_mfa/example`. Managed as a Dart pub workspace with Melos scripts.

## Consequences
+ Server use of core with no Flutter; UI testable without channels; camera opt-in; desktop or third-party vaults can be added by implementing the platform interface.
− Five packages to version and publish in order. Mitigated by Melos and per-package tag patterns.
