---
description: Security self-review of the current diff against the security design
---
Review the current uncommitted diff (or the last commit if clean) against docs/04_SECURITY_DESIGN.md and CLAUDE.md golden rules. Check specifically:

- Any secret handled as String, logged, put in toString/exception/assert/test message?
- Any new path that falls back to weaker protection without the caller asking?
- Constant-time comparison used for codes and secrets?
- Limiter consulted before HMAC in verifiers?
- Random.secure() everywhere outside testing.dart?
- Native code: keys non-exportable, correct accessibility/backup flags, errors mapped to typed VaultException, no debug logging of values?
- Web: secure-context check, non-extractable key, AAD used?
- New dependency or network access?
- Does the change affect a MASVS row in §5? If so, update the evidence column.

Output: a table (check, result, file:line, fix) and fix every failing item before committing.
