# ADR-0002: Separate authenticator and verifier roles; verifier is pure Dart and server-usable

- Status: Accepted (28 October 2026)

## Context
The proposal says "enrollment & verification" without saying where verification happens. A code verified on the same device that holds the seed is not a second factor, and client-side rate limits can be bypassed by anyone holding the device.

## Decision
- Generation (authenticator) and verification (relying party) are separate APIs.
- `TotpVerifier`/`HotpVerifier` live in `flutter_mfa_core` with no Flutter dependency so they run on Dart servers.
- Replay protection is mandatory in the API shape (`lastUsedStep` in, `nextState` out).
- Throttling is a pluggable `AttemptLimiter` + `AttemptStore`; the verifier calls it before computing any HMAC.
- Docs state that authoritative verification belongs on the server; on-device verify is for demos and local step-up only.

## Consequences
+ Correct security model; one implementation shared by server and client.
− Integrators must persist `nextState` and limiter state; cookbook covers it.
