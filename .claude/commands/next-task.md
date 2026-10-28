---
description: Implement the next unchecked task from the build plan
argument-hint: "[optional task ID, e.g. M1-07]"
---
Task: $ARGUMENTS (if empty, take the first unchecked task in docs/06_BUILD_PLAN.md whose dependencies are done).

1. Re-read the requirement IDs it references in docs/01_PRD.md and the matching sections of 02_ARCHITECTURE.md / 03_API_SPEC.md / 04_SECURITY_DESIGN.md.
2. State in 3–5 lines what you will build, which files you'll touch, and what tests prove each acceptance criterion.
3. Before writing new logic, search the codebase for an existing helper you should reuse (DRY rule). Name what you're reusing.
4. Tests first for anything in flutter_mfa_core.
5. Implement. Run `melos run verify` (and the platform tests relevant to the task). Fix until green.
6. Commit with Conventional Commit + task ID + `-s`.
7. Tick the task in docs/06_BUILD_PLAN.md, append to docs/STATUS.md (status, commit, coverage, deviations).
8. If the task ends at a 🛑 checkpoint, run /checkpoint instead of continuing.
