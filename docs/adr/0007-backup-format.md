# ADR-0007: Encrypted-only backup format v1 (PBKDF2-SHA256 + AES-256-GCM)

- Status: Accepted for format; dependency choice pending M3-01 (28 October 2026)

## Context
Export/import (proposal M3) produces a file equivalent to all of a user's second factors. It must be portable across Android/iOS/Web and decryptable by the pure-Dart core.

## Decision
- No plaintext export API.
- Container per `02_ARCHITECTURE.md §7`: magic, version, KDF id, iterations, salt(16), nonce(12), AES-256-GCM ciphertext+tag, header as AAD.
- KDF: PBKDF2-HMAC-SHA256, 600 000 iterations on write (OWASP 2023 recommendation), reject < 210 000 on read. KDF id reserved for Argon2id (0x02) later.
- Passphrase policy: ≥ 12 chars, not in bundled common list, minimal variety.
- KDF runs off the UI isolate.
- **Dependency (decide at M3-01):** a pure-Dart AEAD/PBKDF2 implementation is needed in core. Candidates: `cryptography` (Apache-2.0) or `pointycastle` (MIT). Choose by: licence compatible with MIT distribution, active maintenance (release in last 12 months), no native code in the core path, WASM compatibility, KAT agreement with the Python cross-check. Record the choice here.

## Consequences
+ One format everywhere, testable with known answers, upgradeable.
− PBKDF2 is not memory-hard; mitigated by iteration count and passphrase policy, Argon2id planned.
