# ADR-0010: Backup key derivation on the web uses WebCrypto PBKDF2

- Status: Accepted (28 October 2026, M1 checkpoint); refines ADR-0007 for the web

## Context
ADR-0007 fixes backup format v1 as PBKDF2-HMAC-SHA256 (600 000 iterations) + AES-256-GCM, computed off the UI thread with `Isolate.run`. The web has no isolates: 600 000 iterations in pure Dart (dart2js or WASM) on the main thread freezes the page for seconds, and a web worker would need a separately compiled entry point shipped by every app.

## Decision
- On the web, the PBKDF2 step and the AES-GCM step of backup export/import use `crypto.subtle` (`deriveBits` with PBKDF2/SHA-256 and the same parameters; `encrypt`/`decrypt` with AES-GCM). Both are asynchronous and run off the main thread inside the browser.
- The byte format, parameters and KAT vectors are identical on every platform. The web implementation must pass the same known-answer tests as the pure-Dart one (run in Chrome under JS and WASM), so a backup made on any platform restores on any other.
- The shared logic (header parsing, parameter validation, passphrase policy, error mapping) stays in `flutter_mfa_core`. Only the two primitives are swapped behind a small internal interface, chosen by conditional import. No new dependency.

## Consequences
+ No UI freeze on the web; no extra build artefact for integrators; WebCrypto is a native, audited implementation.
− Two implementations of the same two primitives. The shared KAT suite is the guard against drift and is mandatory in CI for both.
