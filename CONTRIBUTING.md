# Contributing to flutter_mfa

Thanks for helping. This is security software, so the bar is deliberately high — but the process is simple.

## Ground rules
- **Never** paste real OTP secrets, otpauth URIs, codes, backup files or personal data into issues, PRs, tests or logs. Use the RFC test vectors in `packages/flutter_mfa_core/test/vectors/`.
- Security vulnerabilities go through [SECURITY.md](SECURITY.md), not public issues.
- Be kind: [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## Setup
```bash
git clone https://github.com/Breaktroughf1/flutter_mfa && cd flutter_mfa
dart pub global activate melos
dart pub get
melos run verify
```

## Workflow
1. Open or pick an issue; comment that you're working on it.
2. Branch: `feat/<short-name>`, `fix/<short-name>`, `docs/<short-name>`.
3. Write tests first for logic in `flutter_mfa_core`.
4. `melos run verify` must pass. Coverage gates: core ≥ 95 % lines / 90 % branches, other packages ≥ 85 % / 75 %.
5. Commit with [Conventional Commits](https://www.conventionalcommits.org) and **sign off** every commit (`git commit -s`) — this certifies the [Developer Certificate of Origin](https://developercertificate.org).
6. Open a PR using the template. A code owner must approve; CI must be green.

## Design rules (summary)
- One implementation per rule (DRY). Native code is a thin vault; logic lives in Dart.
- Secrets are `Uint8List`, never `String`, never logged.
- Public API changes need an update to `docs/03_API_SPEC.md` and the CHANGELOG.
- New dependencies need a licence (MIT/BSD/Apache-2.0), maintenance and size note.

Full detail: `docs/` (start with `02_ARCHITECTURE.md` and `04_SECURITY_DESIGN.md`).

## Good ways to contribute without writing core code
Device testing on real hardware, security testing of the example app (see `docs/security/dynamic-test-guide.md` once published), accessibility audits with TalkBack/VoiceOver, translations (`packages/flutter_mfa_ui/lib/l10n/`), cookbook docs.
