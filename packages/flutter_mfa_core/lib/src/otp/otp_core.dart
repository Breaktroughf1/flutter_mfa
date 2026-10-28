import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../errors/mfa_exception.dart';
import 'otp_algorithm.dart';

/// Largest counter accepted on every platform: 2^53 − 1, the largest integer
/// a JavaScript number represents exactly (FR-OTP-01 AC3).
const int maxMovingFactor = 9007199254740991;

const _pow10 = {6: 1000000, 7: 10000000, 8: 100000000};

/// Computes an RFC 4226 one-time password.
///
/// This is the single HMAC + dynamic truncation implementation in flutter_mfa
/// (DRY); HOTP and TOTP both delegate here. [movingFactor] is the counter
/// (HOTP) or time step (TOTP), encoded as a 64-bit big-endian integer.
/// Throws [OtpConfigException] for digits other than 6–8 or a moving factor
/// outside 0..[maxMovingFactor].
String computeOtp(
  Uint8List key,
  int movingFactor,
  OtpAlgorithm algorithm,
  int digits,
) {
  final modulus = _pow10[digits];
  if (modulus == null) {
    throw const OtpConfigException(
      field: 'digits',
      reason: 'must be 6, 7 or 8',
    );
  }
  if (movingFactor < 0 || movingFactor > maxMovingFactor) {
    throw const OtpConfigException(
      field: 'counter',
      reason: 'must be between 0 and 2^53-1',
    );
  }

  // Arithmetic (not shifts or setUint64) so it is exact on VM, JS and WASM.
  final message = Uint8List(8);
  var value = movingFactor;
  for (var i = 7; i >= 0; i--) {
    message[i] = value % 256;
    value ~/= 256;
  }

  final hmac = Hmac(_hash(algorithm), key).convert(message).bytes;
  final offset = hmac[hmac.length - 1] & 0x0f;
  final binary =
      ((hmac[offset] & 0x7f) << 24) |
      (hmac[offset + 1] << 16) |
      (hmac[offset + 2] << 8) |
      hmac[offset + 3];
  return (binary % modulus).toString().padLeft(digits, '0');
}

Hash _hash(OtpAlgorithm algorithm) => switch (algorithm) {
  OtpAlgorithm.sha1 => sha1,
  OtpAlgorithm.sha256 => sha256,
  OtpAlgorithm.sha512 => sha512,
};
