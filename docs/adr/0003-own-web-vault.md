# ADR-0003: Own web vault (non-extractable WebCrypto key in IndexedDB)

- Status: Accepted (28 October 2026)

## Context
The proposal commits to WebCrypto/IndexedDB. The common ecosystem option (`flutter_secure_storage` web) is labelled experimental and keeps its key in LocalStorage, optionally wrapped with an app-supplied key — which then has to live in the JS bundle.

## Decision
Implement the web vault in Dart with `package:web` + `dart:js_interop` (WASM-compatible): AES-256-GCM key generated with `extractable: false`, stored as a `CryptoKey` in IndexedDB; records encrypted with AAD = record key; require a secure context; call `navigator.storage.persist()`.

## Consequences
+ Key bytes are never exposed to JS; meets the proposal's commitment.
− XSS on the host origin can still *use* the key — documented as a hard limit of web. Browser eviction risk surfaced via capabilities. Biometric gating unavailable on web in 0.2 (WebAuthn PRF later).
