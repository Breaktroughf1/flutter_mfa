# Verify codes on a Dart server

Your server enrols users and checks their codes with `flutter_mfa_core`. It is pure Dart: no Flutter, no network calls. It runs in any Dart backend (shelf, dart_frog, Serverpod).

Why on the server: a code checked on the same device that holds the secret is not a second factor, and a device holder can reset client-side attempt limits ([ADR-0002](../adr/0002-authenticator-verifier-split.md)).

```yaml
dependencies:
  flutter_mfa_core: ^0.2.0
```

## What to store per user

| Field | Notes |
|---|---|
| TOTP secret | `secret.bytes`, **encrypted at rest** with a key from your KMS or secret manager. Never in logs, analytics or error reports. |
| `enrolled` | `false` until the first code is confirmed. |
| `lastUsedStep` | The last accepted time step (`Accepted.nextState`). It makes a code usable once. |
| Attempt state | In shared storage (Redis, SQL) through your own `AttemptStore`, so every server instance sees the same limits. |

## 1. Start enrolment

```dart
import 'package:flutter_mfa_core/flutter_mfa_core.dart';

/// Called by an authenticated user who wants to turn on two-factor sign-in.
Future<String> startEnrolment(User user) async {
  final secret = OtpSecret.generate(); // 20 random bytes from Random.secure()
  final uri = OtpAuthUri(
    type: OtpType.totp,
    secret: secret,
    issuer: 'Example', // your service name; no colons
    accountName: user.email,
  );
  await users.savePendingSecret(user.id, encrypt(secret.bytes));
  // Send this to the app over TLS to show as a QR code. It contains the
  // secret: never log it, and do not send it again after enrolment.
  return uri.toUri().toString();
}
```

The app shows the URI with `EnrollmentQrView` (see [Enrol users](enrol-users.md)). A Flutter-side `MfaClient.createEnrollment` does the same three steps, for demos and tests.

## 2. Confirm the first code

Turn two-factor sign-in on only after the user proves their authenticator works.

```dart
Future<bool> confirmEnrolment(User user, String code) async {
  final secret = OtpSecret.fromBytes(decrypt(await users.pendingSecret(user.id)));
  final verifier = TotpVerifier(totp: Totp(secret), limiter: limiter);
  final result = await verifier.verify(code, subject: user.id);
  if (result case Accepted(:final nextState)) {
    await users.enableMfa(user.id, lastUsedStep: nextState);
    return true;
  }
  return false;
}
```

## 3. Check a code at sign-in

```dart
/// One limiter per deployment, backed by shared storage.
final limiter = AttemptLimiter(store: RedisAttemptStore(redis));

Future<SignInOutcome> verifySignIn(User user, String code) async {
  final verifier = TotpVerifier(
    totp: Totp(OtpSecret.fromBytes(decrypt(user.secret))),
    limiter: limiter,
  );
  try {
    final result = await verifier.verify(
      code,
      subject: user.id,
      lastUsedStep: user.lastUsedStep,
    );
    switch (result) {
      case Accepted(:final nextState):
        // Persist BEFORE reporting success, or the same code works twice.
        await users.saveLastUsedStep(user.id, nextState);
        return SignInOutcome.success;
      case Rejected(reason: RejectReason.replayed):
        return SignInOutcome.codeAlreadyUsed;
      case Rejected():
        return SignInOutcome.wrongCode;
    }
  } on VerificationRateLimited catch (e) {
    return e.lockedOut ? SignInOutcome.lockedOut : SignInOutcome.tryLater;
  }
}
```

What `TotpVerifier` guarantees:
- **Limits first:** the limiter is consulted before any code is computed. By default, 5 failures per 5 minutes, exponential back-off capped at 15 minutes, and a hard lockout after 20 consecutive failures, which only clearing the subject in your store lifts.
- **Replays are rejected:** a code for a step at or before `lastUsedStep` is `RejectReason.replayed`. This holds only if you persist `nextState`.
- **Constant-time comparison:** every step in the drift window (±1 step by default) is computed and compared.
- **Strict input:** spaces are stripped; anything that isn't exactly the configured number of ASCII digits is `malformed` and still counts as an attempt.

## Shared attempt storage

Implement `AttemptStore` on storage every instance shares. `AttemptState.toJson()` and `fromJson()` give you a versioned format:

```dart
final class RedisAttemptStore implements AttemptStore {
  RedisAttemptStore(this.redis);

  final Redis redis;

  @override
  Future<AttemptState?> read(String subject) async {
    final json = await redis.get('mfa:attempts:$subject');
    return json == null ? null : AttemptState.fromJson(jsonDecode(json) as Map<String, Object?>);
  }

  @override
  Future<void> write(String subject, AttemptState state) =>
      redis.set('mfa:attempts:$subject', jsonEncode(state.toJson()));

  @override
  Future<void> clear(String subject) => redis.del('mfa:attempts:$subject');
}
```

`InMemoryAttemptStore` is for a single process and tests only.

## Checklist

- [ ] Server clock synchronised (NTP). Codes change every 30 s and the window tolerates ±30 s of drift.
- [ ] Secrets encrypted at rest; the key is not in the same database.
- [ ] `lastUsedStep` persisted before success is returned.
- [ ] Attempt state shared across instances.
- [ ] Enrolment URIs, secrets and codes never logged. flutter_mfa's own exceptions and `toString`s never contain them.
- [ ] A recovery path (for example single-use recovery codes) for users who lose their device. Not part of flutter_mfa.

A runnable version of steps 1–3 is in [`packages/flutter_mfa_core/example/main.dart`](../../packages/flutter_mfa_core/example/main.dart).
