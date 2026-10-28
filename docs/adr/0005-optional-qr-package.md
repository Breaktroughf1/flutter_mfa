# ADR-0005: QR scanning in a separate optional package; no remote decoder by default on web

- Status: Accepted (28 October 2026)

## Context
`mobile_scanner` is the maintained cross-platform scanner (Android ML Kit, iOS Vision, web). On Android the bundled ML Kit model adds several MB. On web, when the browser lacks the native `BarcodeDetector` (notably Firefox), it can load a zxing WASM/JS decoder from a public CDN at runtime — third-party code executing in an origin that holds OTP seeds.

## Decision
`flutter_mfa_qr` wraps `mobile_scanner`. On web the default backend is the native `BarcodeDetector`; the zxing fallback is used only when the integrator sets `allowRemoteDecoder: true` or supplies a self-hosted `decoderScriptUrl`. README documents the CSP needed. Payloads other than `otpauth://` are dropped and never logged.

## Consequences
+ Apps that only need manual entry or server-side enrolment avoid camera dependencies; no surprise CDN code on web.
− Firefox users of web apps need integrator opt-in to scan; manual entry always available.
