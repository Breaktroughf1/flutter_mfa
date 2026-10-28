# flutter_mfa_example

A small authenticator built only on the public `MfaClient` API. It runs on Android, iOS and the web from one codebase (FR-EX-01).

- Add an account by typing its Base32 secret key, time-based (TOTP) or counter-based (HOTP).
- See every account's current code. TOTP codes refresh every second; for HOTP, tap the account to generate the next code.
- Remove accounts. Errors come from the typed `MfaException` hierarchy and are shown as messages (`lib/src/error_text.dart`).

QR scanning, backup and restore arrive in later milestones (M2–M4).

## Run

```bash
flutter run                    # Android or iOS device/simulator
flutter run -d chrome          # web (needs a secure context: localhost or HTTPS)
```

## Test

```bash
flutter test                                        # widget tests (in-memory vault)
flutter test integration_test -d <device>           # real vault on Android/iOS
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/app_test.dart -d web-server   # real vault on the web
```

The examples use the RFC 4226/6238 test secret `GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ`. Never use it for a real account.
