# ADR-0014: Atomic per-subject updates for shared attempt stores

- Status: Accepted (7 November 2026, M3 checkpoint, maintainer decision 5)

## Context
`AttemptLimiter` serialises operations per subject inside one process, but records a failure as `read` then `write` on its `AttemptStore`. With a store shared by several server instances (Redis, SQL), two instances that fail the same subject at the same moment can both read the old state; one failure is then lost and the limits are looser under a burst (threat model S1). The cookbook documents this as last-writer-wins and leaves atomicity to each integrator's store.

`AttemptStore` is part of the API frozen by ADR-0011. Adding a method to it would break every existing implementation.

## Decision
- Add an optional interface, purely additive:
  ```dart
  abstract interface class AtomicAttemptStore implements AttemptStore {
    Future<AttemptState?> update(
      String subject,
      AttemptState? Function(AttemptState? current) change,
    );
  }
  ```
  `update` applies `change` to the current state of `subject` atomically with respect to every other `update`, `write` and `clear` on that subject, stores the result (`null` clears it) and returns it. A store may call `change` more than once (for example, retrying after a lost compare-and-set race), so `change` must be pure; the limiter's is.
- `AttemptLimiter` records failures with `update` when its store is an `AtomicAttemptStore`, and keeps today's read-then-write otherwise. Nothing else changes: `ensureAllowed` stays a read, success stays `clear`.
- `InMemoryAttemptStore` implements `AtomicAttemptStore`.
- The failure keeps `lastFailureAt` monotonic (the later of the stored time and `now`), so an instance with a slightly slow clock cannot shorten the back-off another instance set.
- The cookbook shows `update` on Redis (WATCH/MULTI with retry) and on SQL (a transaction holding a per-subject lock that also covers a subject with no row yet).

## Consequences
+ With a shared atomic store no failure is lost: every failure on every instance is counted, so back-off and lockout reflect the true number of failures.
− Admission stays a read and is not atomic across instances. Requests on different instances can all pass `ensureAllowed` before any of their failures is recorded, so a burst can exceed `maxAttempts` by at most one in-flight attempt per instance (each instance serialises a subject's attempts). Every such attempt is still counted. Making admission atomic would need a reservation step in the store contract; not needed for 6-digit codes at these limits, revisit if a deployment runs many instances.
+ No existing store breaks; stores opt in.
− Correctness still depends on the integrator implementing `update` atomically; the library cannot check it. The contract and the cookbook say so.
