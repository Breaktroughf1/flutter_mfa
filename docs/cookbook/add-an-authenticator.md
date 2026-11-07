# Add an authenticator to your app

Let your users keep their one-time codes in your app: scan or type an enrolment, store the secret in the platform vault, and show live codes. This is the **authenticator** side; checking codes belongs on the server of the service the user signs in to ([Verify on a Dart server](verify-on-a-dart-server.md)).

```yaml
dependencies:
  flutter_mfa: ^0.2.0
  flutter_mfa_ui: ^0.2.0
  flutter_mfa_qr: ^0.2.0   # only if you scan QR codes
```

## 1. Open the client

```dart
import 'package:flutter_mfa/flutter_mfa.dart';

final client = await MfaClient.create();
```

`create` probes the vault. An environment that cannot store secrets safely fails here with a `VaultException`, for example `VaultUnavailable(insecureContext)` on a web page that is not HTTPS. Create one client, dispose it when the app no longer needs it, and never fall back to storing secrets yourself.

## 2. Add accounts

Scan the service's QR code (needs `flutter_mfa_qr`; see its README for camera setup and the web Content-Security-Policy):

```dart
OtpQrScanner(
  onScanned: (uri) async {
    await client.enrollFromUri(uri.toUri().toString());
    if (context.mounted) Navigator.of(context).pop();
  },
  onRejected: (_) => showMessage('That is not an authenticator QR code.'),
)
```

Always offer typing the setup key as well:

```dart
await client.enrollManual(
  secretBase32: setupKeyField.text, // spaces and lower case are accepted
  accountName: 'alice@example.com',
  issuer: 'Example',
);
```

Invalid input throws `OtpAuthUriException` or `OtpConfigException` before anything is stored. Neither ever contains the secret.

### Protection levels

`ProtectionLevel.standard` encrypts the secret under a non-exportable platform key. `biometric` and `hardwareBound` add a fresh biometric check before every code; they are being completed in M3. Offer only the levels in `(await client.capabilities).supportedLevels`. An unsupported level throws `VaultHardwareUnavailable`, and the account is never stored with weaker protection.

## 3. Show codes

```dart
import 'package:flutter_mfa_ui/flutter_mfa_ui.dart';

OtpAccountList(
  accounts: accounts, // client.watchAccounts(), created once (for example in initState)
  codeStream: (account) =>
      account.type == OtpType.totp ? client.codeStream(account.id) : null,
  onTap: openDetail,
  onCopy: (account) => client.copyCode(account.id),
)
```

- `codeStream` emits the code immediately, then every second with the countdown, and exactly once at each change. All streams of a client share one timer. The secret is read once per subscription, so a biometric-protected account asks once, not every second.
- Counter-based (HOTP) accounts have no live code: call `client.currentCode(id)` when the user asks. Each call uses up a counter value.
- `copyCode` and `copySensitive` mark the clipboard content sensitive where the platform supports it, and clear it after `MfaClientOptions.clipboardExpiry` (30 s by default).

The widgets work with any design system. Map your theme with `Theme.of(context).toMfaTheme()` (`package:flutter_mfa_ui/material.dart`) or `CupertinoTheme.of(context).toMfaTheme()` (`package:flutter_mfa_ui/cupertino.dart`), and add `MfaLocalizations.delegate` for Hindi and Arabic.

## 4. Handle errors

| Exception | What to tell the user |
|---|---|
| `VaultUnavailable` | Secure storage isn't available (on the web: needs HTTPS). |
| `VaultHardwareUnavailable` | This device can't provide the requested protection. |
| `VaultUserCancelled` | Authentication was cancelled. Nothing changed. |
| `VaultKeyInvalidated` | Biometrics changed, so the account must be restored from a backup or added again. |
| `VaultCorrupted` | Stored data is damaged. Offer `wipeAll()` or a restore. |
| `VaultNotFound` | The account no longer exists. |

## 5. Things to tell your users

- **Uninstalling removes the accounts** on every platform, and iOS wipes Keychain leftovers from an earlier installation. Encrypted backup arrives in M3.
- **On the web the vault is best-effort:** script running in your origin can produce codes. Use a strict CSP and prefer the mobile apps for high-value accounts. See the `flutter_mfa` README.

The example app (`packages/flutter_mfa/example`) implements all of this.
