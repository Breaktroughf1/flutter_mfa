# ADR-0007: Encrypted-only backup format v1 (PBKDF2-SHA256 + AES-256-GCM)

- Status: Accepted (format 28 October 2026; dependency chosen at M3-01, 6 November 2026)

## Context
Export/import (proposal M3) produces a file equivalent to all of a user's second factors. It must be portable across Android/iOS/Web and decryptable by the pure-Dart core.

## Decision
- No plaintext export API.
- Container per `02_ARCHITECTURE.md §7`: magic, version, KDF id, iterations, salt(16), nonce(12), AES-256-GCM ciphertext+tag, header as AAD.
- KDF: PBKDF2-HMAC-SHA256, 600 000 iterations on write (OWASP 2023 recommendation), reject < 210 000 on read. KDF id reserved for Argon2id (0x02) later.
- Passphrase policy: ≥ 12 chars, not in bundled common list, minimal variety.
- KDF runs off the UI isolate.
- **Dependency (decide at M3-01):** a pure-Dart AEAD/PBKDF2 implementation is needed in core. Candidates: `cryptography` (Apache-2.0) or `pointycastle` (MIT). Choose by: licence compatible with MIT distribution, active maintenance (release in last 12 months), no native code in the core path, WASM compatibility, KAT agreement with the Python cross-check. Record the choice here.

## Dependency choice (M3-01, 6 November 2026)
**`cryptography` (Apache-2.0, publisher dint.dev), version `^2.9.0`, using only `DartPbkdf2` and `DartAesGcm`.**

| Criterion | `cryptography` 2.9.0 | `pointycastle` 4.0.0 |
|---|---|---|
| Licence compatible with MIT distribution | Apache-2.0 ✅ | MIT ✅ |
| Release in the last 12 months | 21 Nov 2025 ✅ | 19 Feb 2025 ❌ |
| No native code in the core path | ✅ pure-Dart classes; its only `dart:ffi` import is an unused, conditionally imported Argon2 implementation | ✅ |
| WASM compatibility | ✅ compiled with dart2wasm | ✅ |
| KAT agreement with Python | ✅ PBKDF2-HMAC-SHA256 (600 000 iterations) and AES-256-GCM byte-identical to `hashlib` and Python `cryptography` | not checked |

- Transitive dependencies: `collection`, `crypto`, `ffi`, `meta`, `typed_data` (all BSD-3, Dart team). Archive 171 KB.
- 600 000 iterations take about 2.7 s on the Dart VM: run with `Isolate.run`; the web uses WebCrypto (ADR-0010).
- **Maintenance risk:** the last release is close to the 12-month criterion. Mitigation: the two primitives sit behind an internal interface (already needed for ADR-0010), and the frozen KAT fixture plus the Python cross-check (M3-03) pin the bytes, so the implementation can be replaced (for example by `pointycastle` or WebCrypto-style platform code) without changing the format. Re-check at each release.

## Consequences
+ One format everywhere, testable with known answers, upgradeable.
− PBKDF2 is not memory-hard; mitigated by iteration count and passphrase policy, Argon2id planned.
