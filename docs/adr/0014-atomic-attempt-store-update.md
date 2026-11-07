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
- The cookbook shows `update` on Redis (WATCH/MULTI with retry) and on SQL (a transaction with `SELECT … FOR UPDATE`).

## Consequences
+ Shared stores can make the limits exact across instances without forking the limiter.
+ No existing store breaks; stores opt in.
− Correctness still depends on the integrator implementing `update` atomically; the library cannot check it. The contract and the cookbook say so.
