// Server-side TOTP enrolment and verification with flutter_mfa_core.
//
// Run: dart run example/main.dart
//
// A relying party (your backend) owns the secret, enrols the user by showing
// an otpauth:// URI as a QR code, and verifies submitted codes with replay
// protection and throttling. Persist the secret encrypted at rest, and
// persist `lastUsedStep` and limiter state in shared storage.
import 'dart:io';

import 'package:flutter_mfa_core/flutter_mfa_core.dart';

/// What your user table would hold for TOTP (secret encrypted at rest!).
final class UserRecord {
  /// Creates a record.
  UserRecord(this.id, this.secret);

  /// User id; also the limiter subject.
  final String id;

  /// The TOTP seed.
  final OtpSecret secret;

  /// Last accepted time step, for replay protection.
  int? lastUsedStep;
}

/// Runs the demo and returns the verification results, so a test can check
/// them. [clock] lets the test control time.
Future<List<String>> runDemo({Clock clock = const SystemClock()}) async {
  final log = <String>[];

  // 1. Enrolment: generate a secret and give the user an otpauth:// URI.
  final user = UserRecord('user-42', OtpSecret.generate());
  final uri = OtpAuthUri(
    type: OtpType.totp,
    secret: user.secret,
    accountName: 'alice@example.com',
    issuer: 'Example',
  );
  // Render uri.toUri() as a QR code. Never log it: it contains the secret.
  log.add(
    'enrolment URI ready (${uri.toUri().scheme}, ${uri.compatibilityWarnings.length} warnings)',
  );

  // 2. Verification setup: one limiter per deployment, backed by shared storage.
  final limiter = AttemptLimiter(store: InMemoryAttemptStore(), clock: clock);
  final totp = Totp(user.secret, clock: clock);
  final verifier = TotpVerifier(totp: totp, limiter: limiter);

  Future<void> login(String code) async {
    try {
      final result = await verifier.verify(
        code,
        subject: user.id,
        lastUsedStep: user.lastUsedStep,
      );
      switch (result) {
        case Accepted(:final nextState):
          user.lastUsedStep = nextState; // persist BEFORE reporting success
          log.add('accepted');
        case Rejected(:final reason):
          log.add('rejected: ${reason.name}');
      }
    } on VerificationRateLimited catch (e) {
      // Round up: never tell a user to wait 0 s while still limited.
      final seconds = (e.retryAfter.inMilliseconds / 1000).ceil();
      log.add('rate limited: retry after ${seconds}s');
    }
  }

  // The user's authenticator app would show this code.
  final code = totp.generate();
  await login(code); // accepted
  await login(code); // replayed: same step cannot be used twice
  await login('000000'); // throttled: back-off after the previous failure
  return log;
}

Future<void> main() async {
  for (final line in await runDemo()) {
    stdout.writeln(line);
  }
}
