# Changelog

All notable changes to this package are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this package uses
[Semantic Versioning](https://semver.org) (0.x: a minor bump may break).

## 0.2.0

- `AtomicAttemptStore`: optional atomic per-subject `update` for shared
  attempt stores; `AttemptLimiter` records failures through it, so no failure is
  lost across processes. `InMemoryAttemptStore` implements it (ADR-0014).

- `BackupCodec` and `BackupEntry`: encrypted backup format v1 (PBKDF2-HMAC-SHA256,
  600 000 iterations, AES-256-GCM with the header authenticated), ASCII armour,
  a frozen known-answer fixture cross-checked against Python (FR-BAK-01).
  In browsers the key derivation and encryption use WebCrypto, off the main
  thread (ADR-0010).

- `PassphrasePolicy.check` for backup passphrases (FR-BAK-02): at least 12
  characters, not one of the 10 000 most common passwords (zxcvbn list, also
  after removing digits, spaces and symbols), and enough variety. Depends on
  `cryptography` (Apache-2.0) for the backup format (ADR-0007).

## 0.1.0-dev.1

- TOTP/HOTP generation (RFC 6238 / RFC 4226) verified against all RFC test vectors, on VM, JS and WASM.
- `TotpVerifier` / `HotpVerifier` with drift window, replay protection, look-ahead and resync.
- `AttemptLimiter` with window, exponential back-off and hard lockout; pluggable `AttemptStore`.
- `OtpAuthUri` parsing/generation with compatibility warnings; redacted `toString`.
- `Base32` (RFC 4648), `OtpSecret`, `OtpAccount`, sealed `MfaException` hierarchy, `AsyncMutex`.
- `testing.dart`: `FakeClock`, `SeededRandom`, RFC vectors.
