# flutter_mfa_core

Pure Dart core of [flutter_mfa](https://github.com/Breaktroughf1/flutter_mfa):

- TOTP/HOTP generation per RFC 6238 / RFC 4226, verified against every RFC test vector.
- Server-side verification with replay protection and attempt limiting.
- `otpauth://` URI parsing and generation, with compatibility warnings.
- Base32 and the encrypted backup format.

It has **no Flutter dependency**, so the same audited code runs in your Dart backend (shelf, dart_frog, Serverpod) and in Flutter apps. It runs on the VM, and compiled to JS and WASM.

> **Status:** in development towards v0.2.0. Not yet published. APIs may change.

## Who verifies?
Codes are **generated** on the user's device and **verified** by your server. A code checked on the same device that holds the secret is not a second factor, and client-side rate limits can be reset by whoever holds the device. Use `TotpVerifier` / `HotpVerifier` on your server; on-device verification is only for local step-up.

## Enrol a user (relying party)
```dart
import 'package:flutter_mfa_core/flutter_mfa_core.dart';

final secret = OtpSecret.generate();               // 20 random bytes, Random.secure()
final uri = OtpAuthUri(
  type: OtpType.totp,
  secret: secret,
  accountName: 'alice@example.com',
  issuer: 'Example',
);
showQrCode(uri.toUri().toString());                // contains the secret: never log it
// Store `secret.bytes` encrypted at rest, then confirm the first code with the verifier.
```

## Verify a code on your server
```dart
final verifier = TotpVerifier(
  totp: Totp(OtpSecret.fromBytes(user.secretBytes)),
  limiter: AttemptLimiter(store: myRedisAttemptStore),   // shared storage across instances
);

try {
  final result = await verifier.verify(code, subject: user.id, lastUsedStep: user.lastStep);
  switch (result) {
    case Accepted(:final nextState):
      await users.saveLastStep(user.id, nextState);     // persist BEFORE reporting success
    case Rejected(:final reason):                       // invalid, replayed or malformed
      reject(reason);
  }
} on VerificationRateLimited catch (e) {
  tooManyAttempts(e.retryAfter, lockedOut: e.lockedOut);
}
```
A complete, runnable version is in [`example/main.dart`](example/main.dart).

### What the verifier guarantees
- **Throttling first.** The limiter is consulted before any code is computed. Check → compute → record is atomic per subject in-process, so a burst of parallel guesses can't exceed the limit.
- **Replay protection.** A code for a step ≤ `lastUsedStep` is rejected as `replayed` (RFC 6238 §5.2), but only if you persist `nextState`.
- **Constant-time comparison.** Every candidate in the drift window is compared, with no early exit.
- **Strict input handling.** Spaces are stripped; anything other than exactly 6–8 ASCII digits is `malformed` and still counts as an attempt.

### Limits (`LimiterPolicy`)
Defaults:
- at most 5 failures per 5 minutes;
- exponential back-off from 1 s, capped at 15 min;
- **hard lockout** after 20 consecutive failures (`VerificationRateLimited.lockedOut`). Waiting does not lift it; clear the subject in your store to unlock.

Implement `AttemptStore` on shared storage (Redis, SQL). `AttemptState.toJson()` / `fromJson()` give you a versioned format.

## Interoperability notes
- **Defaults:** SHA-1, 6 digits and 30 s work with every authenticator app. Other values produce `compatibilityWarnings`, because many apps silently ignore them.
- **Secret length:** secrets imported from existing issuers may be 10–15 bytes (80-bit). They are accepted, but flagged by `OtpSecret.meetsRfcMinimum` and `CompatibilityWarning.shortSecret`. Generated secrets are always at least 16 bytes (RFC 4226 R6).
- **Counter ceiling:** HOTP counters are limited to 2^53 − 1 on every platform, the JavaScript exact-integer limit.

## Security notes
- `OtpSecret` keeps a private copy, returns copies, has a redacted `toString`, and compares in constant time. Dart's garbage collector means memory cannot be reliably wiped.
- No exception or `toString` in this package ever contains a secret, a code or a URI.
- Report vulnerabilities privately: see [SECURITY.md](https://github.com/Breaktroughf1/flutter_mfa/blob/main/SECURITY.md).

## Testing helpers
`package:flutter_mfa_core/testing.dart` provides `FakeClock`, `SeededRandom` (insecure, tests only) and the RFC 4226/6238 vectors.

---
Built and maintained by **BreaktroughF1 LLP** in collaboration with **ARDC, CHRIST (Deemed to be University)**. MIT licensed.
