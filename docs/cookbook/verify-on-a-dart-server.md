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
        // Persist BEFORE reporting success, and only if no concurrent
        // request already used this step, or the same code works twice:
        //   UPDATE users SET last_used_step = :next
        //   WHERE id = :id AND (last_used_step IS NULL OR last_used_step < :next)
        if (!await users.advanceLastUsedStep(user.id, nextState)) {
          return SignInOutcome.codeAlreadyUsed; // lost the race: a replay
        }
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
- **Replays are rejected:** a code for a step at or before `lastUsedStep` is `RejectReason.replayed`. This holds only if you persist `nextState`, conditionally as above. Two requests carrying the same code can otherwise both pass before either write lands.
- **Constant-time comparison:** every step in the drift window (±1 step by default) is computed and compared.
- **Strict input:** spaces are stripped; anything that isn't exactly the configured number of ASCII digits is `malformed` and still counts as an attempt.

## Shared attempt storage

Implement `AtomicAttemptStore` on storage every instance shares (ADR-0014). `AttemptState.toJson()` and `fromJson()` give you a versioned format. `update` must change one subject's state atomically across all instances. `AttemptLimiter` records every failure through it, so parallel failures on different instances are all counted:

```dart
final class RedisAttemptStore implements AtomicAttemptStore {
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

  /// Optimistic transaction: WATCH the key, compute, MULTI/EXEC; if another
  /// instance changed the key in between, EXEC fails and we retry.
  @override
  Future<AttemptState?> update(
    String subject,
    AttemptState? Function(AttemptState? current) change,
  ) async {
    final key = 'mfa:attempts:$subject';
    while (true) {
      await redis.watch(key);
      final json = await redis.get(key);
      final next = change(
        json == null ? null : AttemptState.fromJson(jsonDecode(json) as Map<String, Object?>),
      );
      final committed = await redis.multi((tx) => next == null
          ? tx.del(key)
          : tx.set(key, jsonEncode(next.toJson())));
      if (committed) return next;
    }
  }
}
```

With SQL, run `update` in a transaction that locks the row (`SELECT … FOR UPDATE`, then `INSERT … ON CONFLICT DO UPDATE` or `DELETE`). Because `change` can run more than once, it must have no side effects; the limiter's never does.

A store that implements only `AttemptStore` still works: the limiter then reads and writes. That is last-writer-wins across processes, so two instances failing at the same moment can lose one failure and the limits are looser under a burst. Use it only when each subject is routed to a single instance.

`InMemoryAttemptStore` is for a single process and tests only.

## Checklist

- [ ] Server clock synchronised (NTP). Codes change every 30 s and the window tolerates ±30 s of drift.
- [ ] Secrets encrypted at rest; the key is not in the same database.
- [ ] `lastUsedStep` advanced with a conditional update before success is returned.
- [ ] Attempt state shared across instances, with an atomic `update` (`AtomicAttemptStore`).
- [ ] Enrolment URIs, secrets and codes never logged. flutter_mfa's own exceptions and `toString`s never contain them.
- [ ] A recovery path (for example single-use recovery codes) for users who lose their device. Not part of flutter_mfa.

A runnable version of steps 1–3 is in [`packages/flutter_mfa_core/example/main.dart`](../../packages/flutter_mfa_core/example/main.dart).
