# Changelog

All notable changes to this package are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this package uses
[Semantic Versioning](https://semver.org) (0.x: a minor bump may break).

## 0.2.0 - 2026-11-08

- `MfaPlatform`: token-verified platform interface for the protected byte vault
  (`capabilities`, `write`, `read`, `delete`, `keys`, `wipe`), sensitive
  clipboard (`copySensitive`) and screen-capture protection
  (`setScreenCaptureProtection`).
- `VaultCapabilities` (including `screenCaptureProtection` and
  `supportedLevels`) and `BiometricPrompt`.
- `MethodChannelMfaPlatform`: Pigeon-backed mobile channel implementation and
  single-point mapping of platform `VaultErrorCode` values to `VaultException`
  (discarding native error messages).
- `testing.dart`: `InMemoryMfaPlatform` fake with configurable capabilities,
  fail-closed protection levels, simulated `BiometricPrompt` callback,
  `failNext` error injection and recorded clipboard/screen-capture state.

## 0.1.0-dev.1

- Initial package skeleton (not yet published).
