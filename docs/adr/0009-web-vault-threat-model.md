# ADR-0009: Web vault threat model and clipboard policy

- Status: Accepted (28 October 2026, M1 checkpoint); refines ADR-0003

## Context
ADR-0003 chose a non-extractable AES-256-GCM `CryptoKey` in IndexedDB. Building and testing it (M1-14) showed two facts the original decision did not state:

1. Browsers persist the material of a non-extractable key inside the profile's IndexedDB files. `extractable: false` stops page script from exporting the key; it does not stop someone who can read the profile on disk (malware, a stolen unencrypted laptop) from recovering it.
2. Browsers have no "sensitive clip" flag, and reading the clipboard to check whether the code is still there triggers a permission prompt in most browsers.

## Decision
- Record format matches Android: `version(1) ‖ protection(1) ‖ nonce(12) ‖ ciphertext ‖ tag(16)` with AAD `"flutter_mfa.v1:" ‖ header ‖ key`, so a record cannot be moved to another key or relabelled.
- The key is read from IndexedDB on every use (no cache) and never created on read; concurrent first writes converge through `add` (first key wins).
- Only `ProtectionLevel.standard` exists on the web; other levels throw `VaultHardwareUnavailable(unsupportedOnPlatform)`. Outside a secure context every storage call throws `VaultUnavailable(insecureContext)`.
- Clipboard: a copied code is cleared at expiry **only** if `clipboard-read` is already granted and the clipboard still holds the code. Otherwise it is left alone: no permission prompt from a library, and never wiping something the user copied later.
- Residual risks are documented in bold in the plugin README and in `04_SECURITY_DESIGN.md` S12: script in the page origin can decrypt (XSS), and disk access to the browser profile recovers secrets.

## Consequences
+ Honest, tested guarantees; one record format across Android and web.
− The web is best-effort and weaker than mobile; integrators must be told (README).
− On browsers without `clipboard-read` (Firefox, Safari) a copied code stays on the clipboard until replaced; codes expire within their period, which bounds the exposure.
