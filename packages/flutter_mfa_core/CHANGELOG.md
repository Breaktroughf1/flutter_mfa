# Changelog

All notable changes to this package are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this package uses
[Semantic Versioning](https://semver.org) (0.x: a minor bump may break).

## Unreleased

## 0.1.0-dev.1

- TOTP/HOTP generation (RFC 6238 / RFC 4226) verified against all RFC test vectors, on VM, JS and WASM.
- `TotpVerifier` / `HotpVerifier` with drift window, replay protection, look-ahead and resync.
- `AttemptLimiter` with window, exponential back-off and hard lockout; pluggable `AttemptStore`.
- `OtpAuthUri` parsing/generation with compatibility warnings; redacted `toString`.
- `Base32` (RFC 4648), `OtpSecret`, `OtpAccount`, sealed `MfaException` hierarchy, `AsyncMutex`.
- `testing.dart`: `FakeClock`, `SeededRandom`, RFC vectors.
