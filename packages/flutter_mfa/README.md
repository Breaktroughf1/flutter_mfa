# flutter_mfa

The Flutter plugin of [flutter_mfa](https://github.com/Breaktroughf1/flutter_mfa): `MfaClient`, a secure vault (Android Keystore, iOS Keychain, WebCrypto), biometric-bound protection, sensitive clipboard and encrypted backup.

> **Status:** in development towards v0.2.0. Not yet published. APIs may change.

Built and maintained by **BreaktroughF1 LLP** in collaboration with **ARDC, CHRIST (Deemed to be University)**. MIT licensed.

Security model and design: see the [project docs](https://github.com/Breaktroughf1/flutter_mfa/tree/main/docs).

## Quick start

```dart
import 'package:flutter_mfa/flutter_mfa.dart';

final client = await MfaClient.create(); // fails with a VaultException if secrets can't be stored safely

// Add an account from a scanned or pasted otpauth:// URI, or from a typed setup key.
final account = await client.enrollFromUri(otpauthUri);
await client.enrollManual(secretBase32: setupKey, accountName: 'alice@example.com', issuer: 'Example');

// Live codes: the current code, then every second, and once at each change.
final subscription = client.codeStream(account.id).listen(showCode); // cancel() when off screen

// Copy with the sensitive clipboard (cleared after 30 s by default).
await client.copyCode(account.id);
```

| Capability | API |
|---|---|
| Enrol (URI or setup key), list, rename, remove, wipe | `enrollFromUri`, `enrollManual`, `accounts`, `watchAccounts`, `rename`, `remove`, `wipeAll` |
| Codes | `codeStream` (TOTP, one shared timer per client), `currentCode` (HOTP advances and persists the counter first) |
| Sensitive clipboard | `copyCode`, `copySensitive` |
| Relying-party helper (demos and tests) | `MfaClient.createEnrollment` |
| Vault capabilities | `capabilities` (hardware backing, biometrics, secure context, persistent storage, supported protection levels) |

Secrets stay in the platform vault: Android Keystore (StrongBox when available), iOS Keychain (`ThisDeviceOnly`, excluded from backups) or, on the web, AES-256-GCM under a non-extractable WebCrypto key. Biometric-bound protection levels are being completed in M3. Nothing is logged unless you pass an `MfaLogger`, and even then only event names and account ids.

All of `flutter_mfa_core` is re-exported, so one import is enough. Widgets are in [`flutter_mfa_ui`](https://pub.dev/packages/flutter_mfa_ui) and QR scanning is in [`flutter_mfa_qr`](https://pub.dev/packages/flutter_mfa_qr).

Guides: [Add an authenticator to your app](https://github.com/Breaktroughf1/flutter_mfa/blob/main/docs/cookbook/add-an-authenticator.md) · [Enrol users (relying party)](https://github.com/Breaktroughf1/flutter_mfa/blob/main/docs/cookbook/enrol-users.md) · [Verify on a Dart server](https://github.com/Breaktroughf1/flutter_mfa/blob/main/docs/cookbook/verify-on-a-dart-server.md). A complete app is in [`example/`](example).

## Platform notes

- **Uninstall removes accounts on every platform.** Android deletes app data on uninstall. iOS keeps Keychain items, so the plugin wipes anything left from an earlier installation before its first vault operation (ADR-0012). Users who reinstall need an encrypted backup to restore their accounts.

## Web: security limits

**On the web the vault is best-effort. Prefer the mobile apps for high-value accounts.**

- Secrets are encrypted with AES-256-GCM under a **non-extractable** WebCrypto key. Both the key and the ciphertext live in IndexedDB (`flutter_mfa_v1`). Page script cannot export the key. The browser still stores the key material in the profile's files, so **anyone who can read the browser profile on disk (malware, a stolen unencrypted laptop) can recover the secrets**. The web vault has no hardware binding.
- **Script running in your origin (XSS, a compromised dependency, a malicious extension with page access) can still ask the browser to decrypt, so it can read codes.** This cannot be fixed inside a web page. Serve the app with a strict Content-Security-Policy and Trusted Types, and keep third-party script off the page.
- The vault works only in a [secure context](https://developer.mozilla.org/docs/Web/Security/Secure_Contexts) (HTTPS or `localhost`). Anywhere else, every call throws `VaultUnavailable(insecureContext)`.
- Only `ProtectionLevel.standard` exists on the web. Requests for `biometric` or `hardwareBound` throw `VaultHardwareUnavailable`, and the account is never stored at a weaker level.
- Browsers may evict site data. The vault asks for persistent storage and reports the browser's answer in `capabilities.persistentStorage`. When it is `false`, prompt users to keep an encrypted backup. Clearing site data deletes all accounts.
- Copied codes are cleared after the expiry only when the page can already read the clipboard without a permission prompt. Otherwise the code stays on the clipboard until something else replaces it.
