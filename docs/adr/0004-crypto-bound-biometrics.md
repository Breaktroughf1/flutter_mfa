# ADR-0004: Biometric protection is bound to key use inside the vault; Secure Enclave used as an envelope only

- Status: Accepted (28 October 2026)

## Context
The proposal mentions a "biometrics wrapper" and "Keychain/Secure Enclave" for secrets. A boolean biometric result can be hooked at runtime (MASTG documents this pattern). The iOS Secure Enclave stores only P-256 private keys and cannot hold an HMAC seed or compute HMAC.

## Decision
- Android: per-entry Keystore AES-GCM key with `setUserAuthenticationRequired(true)`, `setInvalidatedByBiometricEnrollment(true)`, `BIOMETRIC_STRONG`; decryption only inside `BiometricPrompt` with a `CryptoObject`. StrongBox when available.
- iOS: Keychain item with `SecAccessControl(.biometryCurrentSet)`; `hardwareBound` additionally wraps the seed with a Secure-Enclave P-256 key via ECIES (cofactor, variable IV, X9.63 SHA-256, AES-GCM).
- No public "isAuthenticated" boolean anywhere in the API.
- Biometric enrolment changes invalidate keys → `VaultKeyInvalidated`; apps must re-enrol or restore from backup (example shows the flow).

## Consequences
+ Satisfies MASVS-AUTH-2 intent; resists Frida-style boolean bypass.
− Host Android activity must be a `FlutterFragmentActivity`. Simulator/emulator cannot exercise all paths → manual device tests at M3/M4.
