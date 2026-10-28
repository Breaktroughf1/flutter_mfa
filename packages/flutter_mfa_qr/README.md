# flutter_mfa_qr

Optional camera scanner for `otpauth://` QR codes, part of [flutter_mfa](https://github.com/Breaktroughf1/flutter_mfa). On the web it uses the native `BarcodeDetector` and loads no remote decoder unless you opt in.

> **Status:** in development towards v0.2.0. Not yet published. APIs may change.

Built and maintained by **BreaktroughF1 LLP** in collaboration with **ARDC, CHRIST (Deemed to be University)**. MIT licensed.

Security model and design: see the [project docs](https://github.com/Breaktroughf1/flutter_mfa/tree/main/docs) and [ADR-0005](https://github.com/Breaktroughf1/flutter_mfa/blob/main/docs/adr/0005-optional-qr-package.md).

## Usage

```dart
OtpQrScanner(
  onScanned: (uri) async {
    // The URI holds the account secret: enrol it and drop it.
    await client.enrollFromUri(uri.toUri().toString());
    if (context.mounted) Navigator.of(context).pop();
  },
  onRejected: (_) => showNotAnAuthenticatorCode(), // never log the payload
  onOpenSettings: openAppSettings, // for example from package:app_settings
)
```

Give the scanner a bounded size (it fills its parent), and always offer manual entry of the setup key next to it.

- Only valid `otpauth://` URIs reach `onScanned`; anything else goes to `onRejected`. A code held in front of the camera is reported once.
- Payloads are never logged. Camera frames are not kept. For de-duplication only a SHA-256 digest of the last payload is held.
- The text passed to `onRejected` can contain a secret (for example a malformed enrolment URI). Do not log it or send it anywhere.

### When the camera cannot be shown

Instead of the camera, the scanner shows a localized message (English, Hindi, Arabic via `MfaLocalizations`) with actions. Replace it with `permissionBuilder`, which receives an `OtpQrScannerStatus` and a `retry` callback. `mfaStrings(context)` from `flutter_mfa_ui` gives you the built-in texts.

| Status | Meaning | Built-in actions |
|---|---|---|
| `requesting` | The camera is starting; the permission prompt may be open. | none |
| `denied` | The user declined. Asking again shows the prompt (Android only). | Try again |
| `permanentlyDenied` | The system will not ask again; only the settings can allow it. | Open settings (if `onOpenSettings` is set), Try again |
| `unavailable` | No usable camera: none present, in use elsewhere, or it failed to start. | Try again |
| `unsupportedBrowser` | Web, default options: the browser has no built-in QR decoder. The camera is never requested. | none |
| `insecureContext` | Web page not served over HTTPS: the camera is never requested. | none |

On iOS and in browsers a denial is permanent. Android shows the prompt at most twice and does not say whether it will ask again, so the first denial there is `denied` and a denial after "Try again" is `permanentlyDenied`. In the `permanentlyDenied` state the scanner retries when the app returns to the foreground, so it picks up access granted in the settings.

## Platform setup

**Android.** The `CAMERA` permission is merged in from `mobile_scanner` (minSdk 24 here). Decoding uses Google's on-device ML Kit model, which adds a few MB to the APK. To use the Google Play services model instead, set `dev.steenbakker.mobile_scanner.useUnbundled=true` in `android/gradle.properties`. ML Kit can send usage and performance metrics to Google. Neither images nor payloads are sent. Check Google's ML Kit data-disclosure guidance when you fill in the Play data-safety form.

**iOS.** Add `NSCameraUsageDescription` to `ios/Runner/Info.plist`, for example "Scan the QR code to add an account". Decoding uses Apple's Vision framework, on device.

**Web.** The camera needs a secure context (HTTPS or `localhost`). If you send a `Permissions-Policy` header, it must allow `camera=(self)`. Decoding is chosen with `webOptions`:

| `OtpQrWebOptions` | Decoder | Loads | Content-Security-Policy additions |
|---|---|---|---|
| default | the browser's `BarcodeDetector` (Chrome, Edge, Safari 17+) | nothing | none |
| `decoderScriptUrl: Uri.parse('zxing/index.min.js')` | `@zxing/library` 0.23.0 UMD build (Apache-2.0), self-hosted | that one file | `script-src 'self'` (or the `https` host you serve it from) |
| `allowRemoteDecoder: true` | `BarcodeDetector`, else `zxing-wasm` 3.1.3 | script from `cdn.jsdelivr.net`, WebAssembly from `fastly.jsdelivr.net` | `script-src https://cdn.jsdelivr.net 'wasm-unsafe-eval'; connect-src https://fastly.jsdelivr.net` |

With the default, browsers without `BarcodeDetector` (Firefox, and Chrome on Windows and Linux according to MDN, at the time of writing) show `unsupportedBrowser` without asking for the camera, and users enter the setup key instead.

To scan in every browser without third-party code, self-host the decoder:

1. Copy `umd/index.min.js` from the npm package `@zxing/library@0.23.0` to `web/zxing/index.min.js`. Check that its SHA-256 is `3ede94153fb0c5b67a12d7adff6decd827c2b22714fdc6faecf27a8f20937ea6`. It loads no further files.
2. Pass `OtpQrWebOptions(decoderScriptUrl: Uri.parse('zxing/index.min.js'))`.

`decoderScriptUrl` must be an `https` URL or a same-origin path; anything else throws `ArgumentError`. `allowRemoteDecoder` runs code you do not control in the origin that holds your users' secrets, so prefer the self-hosted script. These settings apply to the whole page, and the script is loaded once, so use the same options for every scanner.
