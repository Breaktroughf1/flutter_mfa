# ADR-0013: Keep flutter_mfa_ui on core only: OtpCode in core, theme adapters as separate libraries

- Status: Accepted (28 October 2026, M2-01)

## Context
ADR-0001 says `flutter_mfa_ui` depends on `flutter_mfa_core` only, and ADR-0006 keeps Material and Cupertino out of the widget libraries. `03_API_SPEC.md` §4, as written, breaks both:

1. `OtpCodeDisplay` and `OtpAccountTile` take an `OtpCode`, which was declared in `flutter_mfa` (the plugin).
2. The theme adapters were written as `factory MfaThemeData.fromMaterial(ThemeData)`. A factory must be declared in the class's own library, so that library, which every widget imports, would import Material.

## Decision
- `OtpCode` (a plain immutable value with a redacted `toString`) moves to `flutter_mfa_core`. `flutter_mfa` re-exports core, so `import 'package:flutter_mfa/flutter_mfa.dart'` still provides it: no change for apps. This is additive to the frozen core API (ADR-0011) and is recorded in `03_API_SPEC.md` §1.
- The adapters are extensions in their own libraries:
  - `package:flutter_mfa_ui/material.dart`: `ThemeData.toMfaTheme()`
  - `package:flutter_mfa_ui/cupertino.dart`: `CupertinoThemeData.toMfaTheme(...)`
  The main library `package:flutter_mfa_ui/flutter_mfa_ui.dart` never imports a design library; apps that don't use Material never load it.

## Consequences
+ UI stays testable and usable without the plugin or platform channels; the CI guard against Material imports keeps working as written.
− Two extra import lines for apps that want the adapters.
