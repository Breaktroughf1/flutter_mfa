# Changelog

All notable changes to this package are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this package uses
[Semantic Versioning](https://semver.org) (0.x: a minor bump may break).

## 0.3.0 - 2026-11-24

- Requires Dart 3.13 and Flutter 3.47 or later (was 3.9 / 3.35), the oldest
  release where `qr` 4 and Flutter's `material_ui` / `cupertino_ui` packages
  are available (ADR-0015). Android minSdk 24 and iOS 15 are unchanged.
- Accepts `flutter_mfa_core` and `flutter_mfa_ui` 0.2 or 0.3
  (`>=0.2.0 <0.4.0`). No API changes.

## 0.2.0 - 2026-11-08

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
