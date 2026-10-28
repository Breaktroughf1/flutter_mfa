import 'package:flutter_mfa_core/flutter_mfa_core.dart';

/// An account for widget tests.
OtpAccount account({
  String id = 'a',
  String? issuer = 'Example',
  String name = 'alice',
  OtpType type = OtpType.totp,
}) => OtpAccount(
  id: id,
  type: type,
  issuer: issuer,
  accountName: name,
  counter: type == OtpType.hotp ? 0 : null,
  createdAt: DateTime.utc(2026),
);

/// A code for widget tests (RFC 6238 SHA-1 at T=59, 6 digits).
const code = OtpCode(
  value: '287082',
  remaining: Duration(seconds: 12),
  progress: 0.6,
  step: 1,
);
