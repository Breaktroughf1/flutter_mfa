# flutter_mfa

The Flutter plugin of [flutter_mfa](https://github.com/Breaktroughf1/flutter_mfa): `MfaClient`, a secure vault (Android Keystore, iOS Keychain, WebCrypto), biometric-bound protection, sensitive clipboard and encrypted backup.

> **Status:** in development towards v0.2.0. Not yet published. APIs may change.

Built and maintained by **BreaktroughF1 LLP** in collaboration with **ARDC, CHRIST (Deemed to be University)**. MIT licensed.

Security model and design: see the [project docs](https://github.com/Breaktroughf1/flutter_mfa/tree/main/docs).

## Web: security limits

**On the web the vault is best-effort. Prefer the mobile apps for high-value accounts.**

- Secrets are encrypted with AES-256-GCM under a **non-extractable** WebCrypto key. Both the key and the ciphertext live in IndexedDB (`flutter_mfa_v1`). Page script cannot export the key. The browser still stores the key material in the profile's files, so **anyone who can read the browser profile on disk (malware, a stolen unencrypted laptop) can recover the secrets**. The web vault has no hardware binding.
- **Script running in your origin (XSS, a compromised dependency, a malicious extension with page access) can still ask the browser to decrypt, so it can read codes.** This cannot be fixed inside a web page. Serve the app with a strict Content-Security-Policy and Trusted Types, and keep third-party script off the page.
- The vault works only in a [secure context](https://developer.mozilla.org/docs/Web/Security/Secure_Contexts) (HTTPS or `localhost`). Anywhere else, every call throws `VaultUnavailable(insecureContext)`.
- Only `ProtectionLevel.standard` exists on the web. Requests for `biometric` or `hardwareBound` throw `VaultHardwareUnavailable`, and the account is never stored at a weaker level.
- Browsers may evict site data. The vault asks for persistent storage and reports the browser's answer in `capabilities.persistentStorage`. When it is `false`, prompt users to keep an encrypted backup. Clearing site data deletes all accounts.
- Copied codes are cleared after the expiry only when the page can already read the clipboard without a permission prompt. Otherwise the code stays on the clipboard until something else replaces it.
