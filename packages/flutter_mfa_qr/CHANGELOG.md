# Changelog

All notable changes to this package are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this package uses
[Semantic Versioning](https://semver.org) (0.x: a minor bump may break).

## Unreleased

- `OtpQrScanner`: scans `otpauth://` QR codes with `mobile_scanner` and
  reports each valid code once as an `OtpAuthUri`; other payloads go to
  `onRejected` and are never logged.
- Permission and availability states (`OtpQrScannerStatus`) with a
  localized default view, `permissionBuilder` and `onOpenSettings`.
- `OtpQrWebOptions`: the native `BarcodeDetector` by default; a
  self-hosted `@zxing/library` script or the CDN `zxing-wasm` decoder
  only on opt-in. The README documents the CSP for each.

## 0.1.0-dev.1

- Initial package skeleton (not yet published).
