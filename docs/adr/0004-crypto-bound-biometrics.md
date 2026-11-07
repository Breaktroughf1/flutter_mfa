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
− Simulator/emulator cannot exercise all paths → manual device tests at M3/M4.

## Implementation note (M3-05, 6 November 2026; maintainer decision)
Android wraps instead of encrypting directly with the gated key. An AES key that requires authentication needs a biometric for encryption too, and `MfaPlatform.write` has no prompt. So each entry gets a Keystore **RSA-2048** key (OAEP SHA-256, MGF1-SHA-1) that unlocks only with a strong biometric. A random AES-256-GCM data key encrypts the secret, and the public key wraps the data key without authentication. Reading unwraps inside `BiometricPrompt` + `CryptoObject`. This matches iOS: saving never prompts, and every read does. RSA-2048 (about 112-bit strength) is added to 04 §6 for this use only. The framework `BiometricPrompt` (API 30+) replaces AndroidX, so there is no new dependency and no `FlutterFragmentActivity` requirement; devices below API 30 do not offer the protected levels.

## Implementation note (M3-06, 7 November 2026)
iOS as designed: `.biometryCurrentSet` on the Keychain item (`biometric`) or on a per-entry Secure Enclave key that wraps the seed with ECIES (`hardwareBound`). Saving never prompts. Each protected item records a hash of the biometric enrolment state, so a re-enrolment is reported as `VaultKeyInvalidated` without a prompt; the access control stays the actual gate. The ECIES plaintext begins with the entry's key name, so ciphertext moved between entries is rejected.
