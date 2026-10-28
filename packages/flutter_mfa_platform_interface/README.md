# flutter_mfa_platform_interface

The platform interface behind the [flutter_mfa](https://github.com/Breaktroughf1/flutter_mfa) secure vault. App developers should depend on `flutter_mfa`. Implement this interface only to add a new vault backend.

> **Status:** in development towards v0.2.0. Not yet published. APIs may change.

Built and maintained by **BreaktroughF1 LLP** in collaboration with **ARDC, CHRIST (Deemed to be University)**. MIT licensed.

Security model and design: see the [project docs](https://github.com/Breaktroughf1/flutter_mfa/tree/main/docs).

## Implementing a vault

Extend `MfaPlatform` and register your instance with `MfaPlatform.instance = …`. The contract is in [`03_API_SPEC.md` §2](https://github.com/Breaktroughf1/flutter_mfa/blob/main/docs/03_API_SPEC.md). In short:

- **A byte vault, nothing more.** Store and return opaque bytes per key; no OTP logic, JSON or validation (that lives in `flutter_mfa_core`).
- **Fail closed.** Unknown platform state throws a typed `VaultException`. Never store at a weaker `ProtectionLevel` than requested: throw `VaultHardwareUnavailable` instead.
- **Buffers belong to the caller.** `read` returns a new, modifiable buffer, which the caller overwrites after use.
- **No logging** of keys, values or platform error messages, which may echo inputs.
- `package:flutter_mfa_platform_interface/testing.dart` provides `InMemoryMfaPlatform` with failure injection for tests.
