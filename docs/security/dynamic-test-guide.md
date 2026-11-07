# Dynamic security test guide (for the ARDC security track)

Purpose: give testers a focused plan to attack flutter_mfa on real devices before the 0.2.0 release (M4-07, build plan §9). The design and the risks it accepts are in the [threat model](threat-model.md). The controls and their automated evidence are in the [MASVS checklist](masvs-checklist.md). What remains for you is what only a person with a device and tools can test.

**Please report vulnerabilities privately as described in [`SECURITY.md`](../../SECURITY.md), not in public issues.** Use the report template in §5.

## 1. Set-up

- **Target:** the example app in `packages/flutter_mfa/example`, built from the release branch.
  - Debug build (for Frida): `flutter run -d <device>`.
  - Release build (what users get): `flutter build apk --release`, or `flutter build ipa` with your own signing.
- **Devices:**
  - Android: one device with StrongBox (for example a Pixel 6 or later, Android 13+); one rooted device or emulator with Magisk and Frida; one device on API 29 or lower.
  - iOS: one iPhone with Face ID, one with Touch ID, and one jailbroken device if available.
  - Web: Chrome and Firefox, served over `https://localhost`.
- **Test data:** the RFC test secret `GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ` (setup key), and a backup passphrase you choose. Never use real accounts.
- **Accounts to create:** one `standard`, one `biometric` and one `hardwareBound` (Settings shows which levels the device offers), plus one counter-based account.

## 2. What is in scope

The vault (all platforms), biometric gating, backup export and import, the clipboard, screen capture, logging, the integrity hook, QR input, and the published Dart packages. The example app's own UI is in scope only where it uses those.

Out of scope: hardware attacks on the TEE, StrongBox or Secure Enclave; the integrating app's server; denial of service by deleting the app's data.

## 3. Tests

Each test lists the threat-model item it targets and the result the design expects. **Anything that differs is a finding.**

| ID | Test | Threat | How | Expected |
|---|---|---|---|---|
| D1 | Seeds on disk | S3, S4 | Android: copy `/data/data/com.breaktroughf1.flutter_mfa_example/` (root or `run-as` on a debug build) and search for the Base32 secret, its hex form and the account names. iOS: dump the app container and the Keychain (jailbroken device, `keychain-dumper` or objection). | Only ciphertext files (`noBackupFilesDir/flutter_mfa/*.bin`). No secret in `shared_prefs`, databases, caches or logs. On iOS, items are `WhenUnlockedThisDeviceOnly`, or `WhenPasscodeSetThisDeviceOnly` for the biometric level. A jailbroken, unlocked iPhone *can* read `standard` items: that is accepted (S4). |
| D2 | Backups and device transfer | S3 | Android: `adb backup` (where still supported), Google One backup, then restore to a second device. iOS: an encrypted Finder backup restored to another device, and iCloud backup. | The accounts do not come back on the other device; they move only through flutter_mfa's encrypted export. |
| D3 | Biometric bypass | S5 | With Frida or objection, hook `BiometricPrompt.AuthenticationCallback.onAuthenticationSucceeded`, `LAContext.evaluatePolicy` and `SecItemCopyMatching` (for example objection `android hooking …` and `ios ui biometrics_bypass`). Try to read a `biometric` or `hardwareBound` code without a real biometric. | No code. Android decrypts only with the `CryptoObject` cipher the system unlocked, so a forced success callback has no usable cipher. iOS releases the item or uses the enclave key only after the OS check. A "success" without a real biometric must still end in an error. |
| D4 | Key invalidation | S23 | Add a new fingerprint or face in Settings, then open each protected account. Repeat after removing every biometric. | `VaultKeyInvalidated`: the example shows "This account can no longer be unlocked" with Restore and Remove. No silent fallback to a weaker level. `standard` accounts keep working. |
| D5 | Clipboard and screen | S6, S7 | Copy a code, then read the clipboard from a second app at once and after 30 s. Android 12 and older: check other apps can read it until it is cleared. Turn on Settings › Hide from screenshots, then take a screenshot, record the screen and open the recent-apps view. | Android 13+: no clipboard preview, cleared after 30 s. iOS: no Universal Clipboard; the clip expires. Android: screenshots and recording are black and the app is blank in recent apps. iOS cannot block screenshots (accepted). |
| D6 | Logs and crash output | S8 | `adb logcat` / Console.app during the whole journey (add, codes, copy, backup, restore, wrong passphrase), plus a forced crash if you can trigger one. | No secret, code, passphrase or `otpauth` URI in any log line. |
| D7 | Crafted input | S11, S19, S20 | Feed malformed or hostile `otpauth://` URIs (by QR and pasted): huge parameters, odd encodings, wrong schemes. Feed modified backup files: flipped bytes, truncation, a changed header, an iteration count of 10 000 001 or 209 999, valid ciphertext with invalid JSON. | The app rejects them cleanly: "not an authenticator QR code" for a bad URI; "Wrong passphrase, or the backup text is incomplete or damaged" for a damaged backup; "This backup was made by a newer version. Update the app." for an iteration count outside 210 000…10 000 000 or an unknown header version. No crash, no partial import. Iteration counts outside 210 000…10 000 000 are refused before any long computation. |
| D8 | Web | S12, S13 | In the example web build: check the IndexedDB `flutter_mfa_v1` contents; try `crypto.subtle.exportKey` on the stored key from DevTools; open the page over plain HTTP. | Only ciphertext in IndexedDB; the key cannot be exported; plain HTTP shows "Secure storage needs HTTPS (or localhost) on the web." at start-up (`MfaClient.create` refuses an insecure context). Script in the page *can* decrypt codes: that is documented as unmitigable (S12), not a finding unless it goes further. |

Optional, if time allows:
- Downgrade a protected account by editing stored files or Keychain attributes (S17, relabelling). The read must fail with "Stored data is damaged".
- Repackage the APK with a changed signature and see whether the vault still opens. The Keystore keys are tied to the app's UID, so the vault should not open.

## 4. Severity

| Severity | Examples |
|---|---|
| **High** | A seed recovered from a non-rooted device, a backup or another app. A biometric-protected code produced without a real biometric. A secret in logs. A crafted file that stores data at a weaker protection level. |
| Medium | A protected account usable after re-enrolment. A code readable by other apps beyond the documented limits. A crash on crafted input. |
| Low | Information leaks that reveal account names or the number of accounts. UX that invites a weak passphrase. |

Every high finding must be fixed before 0.2.0 (M4-11).

## 5. Report template

```
Title:
ID / threat (e.g. D3 / S5):
Severity (High / Medium / Low) and why:
Platform, device, OS version, app build (debug/release, commit):
Steps to reproduce:
Expected (from this guide):
Actual:
Evidence (logs, screenshots — never real secrets):
Suggested fix (optional):
```

Send it as described in `SECURITY.md`. The maintainers triage within the window stated there and record each finding and its fix in `docs/STATUS.md` under M4-11.
