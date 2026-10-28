/// Pure Dart core of flutter_mfa.
///
/// Provides TOTP/HOTP generation (RFC 6238 / RFC 4226), verification with
/// replay protection and attempt limiting, `otpauth://` URIs, Base32 and the
/// encrypted backup format. Has no Flutter dependency, so the same code runs
/// on Dart servers and in apps.
///
/// The public API is specified in `docs/03_API_SPEC.md`.
library;

export 'src/backup/passphrase_check.dart';
export 'src/codec/base32.dart';
export 'src/errors/mfa_exception.dart';
export 'src/util/async_mutex.dart';
