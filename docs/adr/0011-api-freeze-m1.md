# ADR-0011: Core and platform-interface API frozen at M1

- Status: Accepted (28 October 2026, M1 checkpoint)

## Context
The build plan freezes the public API of `flutter_mfa_core` and `flutter_mfa_platform_interface` at the end of M1, so that the plugin, widgets, QR package and backup work in M2–M4 build on a stable contract.

## Decision
- The public API of `flutter_mfa_core` (`flutter_mfa_core.dart`, `testing.dart`) and `flutter_mfa_platform_interface` (`flutter_mfa_platform_interface.dart`, `testing.dart`), as exported at the M1 checkpoint and described in `03_API_SPEC.md` §1–§2, is frozen.
- From now on, any change to those exports, signatures, behaviour contracts or error types needs a new ADR, a `03_API_SPEC.md` update and a CHANGELOG entry in the same PR. Purely additive members that M2–M4 need (for example the backup codec in M3) are allowed only when `03_API_SPEC.md` already lists them.
- The `MfaPlatform.read` contract includes: the returned buffer is owned by the caller, is modifiable, and should be overwritten after use.

## Consequences
+ M2–M4 and integrators can rely on the contract; review can reject unplanned API drift.
− Fixing a design mistake now costs an ADR, which is intended.
