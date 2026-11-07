# flutter_mfa

[![ci](https://github.com/Breaktroughf1/flutter_mfa/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/Breaktroughf1/flutter_mfa/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Multi-factor authentication for Flutter — TOTP/HOTP (RFC 6238/4226), hardware-backed secure storage, QR enrolment and accessible UI widgets for **Android, iOS and Web**, plus a pure-Dart verifier for your server.

Built and maintained by **BreaktroughF1 LLP** in collaboration with **ARDC, CHRIST (Deemed to be University)**. MIT licensed.

> Status: in development towards v0.2.0. APIs may change until then.

| Package | What it is | pub.dev |
|---|---|---|
| [`flutter_mfa_core`](packages/flutter_mfa_core) | Pure Dart: OTP generation, verification with replay protection and throttling, otpauth URIs, Base32, encrypted backup format. Works on servers. | _soon_ |
| [`flutter_mfa`](packages/flutter_mfa) | The Flutter plugin: `MfaClient`, secure vault (Keystore / Keychain / WebCrypto), biometric-bound protection, sensitive clipboard. | _soon_ |
| [`flutter_mfa_ui`](packages/flutter_mfa_ui) | Widgets: code field, code display with countdown, account list, enrolment QR, status badges. Design-system independent, a11y + i18n. | _soon_ |
| [`flutter_mfa_qr`](packages/flutter_mfa_qr) | Optional camera scanner for `otpauth://` QR codes. | _soon_ |
| [`flutter_mfa_platform_interface`](packages/flutter_mfa_platform_interface) | Platform interface for vault implementations. | _soon_ |

## Platform support
| Android | iOS | Web | Dart server |
|---|---|---|---|
| API 24+ (Keystore, StrongBox) | iOS 15+ (Keychain, Secure Enclave envelope) | Secure contexts (HTTPS/localhost), JS and WASM | `flutter_mfa_core` only |

Minimum toolchain: Dart 3.9 / Flutter 3.35.

## Security model in one paragraph
Codes are **generated** on the user's device and **verified** by your server. `flutter_mfa_core` gives you the server verifier (replay protection + attempt limiting) so the same audited code runs on both sides. Seeds are stored encrypted under non-exportable platform keys, excluded from backups, and can be bound to biometrics so no code can be produced without a fresh biometric event. **On the web, storage uses a non-extractable WebCrypto key, but a script running in your origin (XSS) can still use it to produce codes: treat web as best-effort and use a strict CSP.** Details: [docs/04_SECURITY_DESIGN.md](docs/04_SECURITY_DESIGN.md).

## Privacy
The packages make no network requests, collect no telemetry and store everything locally on the device.

## Project docs
Requirements, architecture, API contract, threat model, test plan and build plan live in [docs/](docs/README.md). Design decisions: [docs/adr/](docs/adr/).

## Contributing
See [CONTRIBUTING.md](CONTRIBUTING.md) and the [Code of Conduct](CODE_OF_CONDUCT.md). Report vulnerabilities privately — see [SECURITY.md](SECURITY.md).

## Credits
See [AUTHORS.md](AUTHORS.md).
