import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../otp/otp_algorithm.dart';

/// One RFC 4226 Appendix D known-answer vector.
@immutable
final class HotpVector {
  /// Creates a vector.
  const HotpVector(this.counter, this.code);

  /// Counter value.
  final int counter;

  /// Expected 6-digit SHA-1 code.
  final String code;
}

/// One RFC 6238 Appendix B known-answer vector (8 digits, 30 s, T0 = 0).
@immutable
final class TotpVector {
  /// Creates a vector.
  const TotpVector(this.unixSeconds, this.algorithm, this.code);

  /// Unix time in seconds.
  final int unixSeconds;

  /// Algorithm; each uses its own seed from [rfc6238Seed].
  final OtpAlgorithm algorithm;

  /// Expected 8-digit code.
  final String code;
}

/// RFC 4226 Appendix D secret: ASCII `12345678901234567890`. Test data only.
Uint8List get rfc4226Secret =>
    Uint8List.fromList('12345678901234567890'.codeUnits);

/// RFC 4226 Appendix D: HOTP, SHA-1, 6 digits. Verified against the RFC
/// text and independently with Python `hmac` (M1-04).
const rfc4226Vectors = <HotpVector>[
  HotpVector(0, '755224'),
  HotpVector(1, '287082'),
  HotpVector(2, '359152'),
  HotpVector(3, '969429'),
  HotpVector(4, '338314'),
  HotpVector(5, '254676'),
  HotpVector(6, '287922'),
  HotpVector(7, '162583'),
  HotpVector(8, '399871'),
  HotpVector(9, '520489'),
];

/// RFC 6238 Appendix B seed for [algorithm]. The seed length differs per
/// algorithm (20/32/64 bytes); reusing the 20-byte seed is the most common
/// implementation bug. Test data only.
Uint8List rfc6238Seed(OtpAlgorithm algorithm) {
  const base = '1234567890';
  final length = switch (algorithm) {
    OtpAlgorithm.sha1 => 20,
    OtpAlgorithm.sha256 => 32,
    OtpAlgorithm.sha512 => 64,
  };
  return Uint8List.fromList(
    List<int>.generate(length, (i) => base.codeUnitAt(i % 10)),
  );
}

/// RFC 6238 Appendix B: TOTP, 8 digits, period 30 s, T0 = 0, all 18
/// vectors. Verified against the RFC text and independently (M1-04).
const rfc6238Vectors = <TotpVector>[
  TotpVector(59, OtpAlgorithm.sha1, '94287082'),
  TotpVector(59, OtpAlgorithm.sha256, '46119246'),
  TotpVector(59, OtpAlgorithm.sha512, '90693936'),
  TotpVector(1111111109, OtpAlgorithm.sha1, '07081804'),
  TotpVector(1111111109, OtpAlgorithm.sha256, '68084774'),
  TotpVector(1111111109, OtpAlgorithm.sha512, '25091201'),
  TotpVector(1111111111, OtpAlgorithm.sha1, '14050471'),
  TotpVector(1111111111, OtpAlgorithm.sha256, '67062674'),
  TotpVector(1111111111, OtpAlgorithm.sha512, '99943326'),
  TotpVector(1234567890, OtpAlgorithm.sha1, '89005924'),
  TotpVector(1234567890, OtpAlgorithm.sha256, '91819424'),
  TotpVector(1234567890, OtpAlgorithm.sha512, '93441116'),
  TotpVector(2000000000, OtpAlgorithm.sha1, '69279037'),
  TotpVector(2000000000, OtpAlgorithm.sha256, '90698825'),
  TotpVector(2000000000, OtpAlgorithm.sha512, '38618901'),
  TotpVector(20000000000, OtpAlgorithm.sha1, '65353130'),
  TotpVector(20000000000, OtpAlgorithm.sha256, '77737706'),
  TotpVector(20000000000, OtpAlgorithm.sha512, '47863826'),
];
