# 03 — Public API Specification (target for 0.2.0)

This is the contract. Claude Code implements to it; changes require an ADR or a PR note under "API change" and a CHANGELOG entry. Names are final unless marked *(tentative)*.

Conventions: immutable value classes (`final` fields, `const` constructors, `==`/`hashCode`, `copyWith`), `@immutable` from `package:meta`. No `dynamic` in public signatures. All `Future`s document their exceptions.

---

## 1. `flutter_mfa_core`

### 1.1 Primitives
```dart
enum OtpAlgorithm { sha1, sha256, sha512 }
enum OtpType { totp, hotp }

abstract interface class Clock { DateTime now(); }
final class SystemClock implements Clock { const SystemClock(); }

/// Opaque secret. Holds a defensive copy; `bytes` returns a copy.
@immutable
final class OtpSecret {
  factory OtpSecret.fromBytes(Uint8List bytes);          // 10..256 bytes or throws OtpConfigException (M1-03: 80-bit issuer secrets must import)
  static const minLength = 10, rfcMinLength = 16, maxLength = 256;
  bool get meetsRfcMinimum;                              // >= 16 bytes (RFC 4226 R6); flagged by URI compatibility warnings
  factory OtpSecret.fromBase32(String input);            // lenient decode
  factory OtpSecret.generate({int length = 20, Random? random}); // Random.secure() default; 16..256 bytes
  static int recommendedLength(OtpAlgorithm a);          // 20 / 32 / 64
  Uint8List get bytes;
  String toBase32();                                     // upper, no padding
  int get length;
  @override String toString() => 'OtpSecret(<redacted ${length}B>)'; // never prints bytes
}
```

### 1.2 Codecs
```dart
abstract final class Base32 {
  static String encode(List<int> bytes, {bool padding = false});
  static Uint8List decode(String input); // throws FormatException(message, null, offset): source is never set, the input is a secret (M1-02)
}
```

### 1.3 Generators
```dart
@immutable
final class HotpConfig { const HotpConfig({this.algorithm = OtpAlgorithm.sha1, this.digits = 6}); } // validated on use

final class Hotp {
  const Hotp(this.secret, {this.config = const HotpConfig()});
  static const maxCounter = 9007199254740991;  // 2^53-1 on every platform (FR-OTP-01 AC3)
  String generate(int counter);                // throws OtpConfigException (digits, counter)
}

@immutable
final class TotpConfig {
  const TotpConfig({this.algorithm = OtpAlgorithm.sha1, this.digits = 6,
      this.period = const Duration(seconds: 30), this.t0 = 0});   // period: whole seconds > 0; t0: unix seconds; validated on use
  HotpConfig get hotp;
}

final class Totp {
  const Totp(this.secret, {this.config = const TotpConfig(), this.clock = const SystemClock()});
  int stepAt(DateTime t);
  String generate([DateTime? at]);
  String generateForStep(int step);
  Duration remaining([DateTime? at]);
  double progress([DateTime? at]);    // 0.0 at step start → <1.0
}
```
Internally both use one function: `String _otp(Uint8List key, int movingFactor, OtpAlgorithm, int digits)` in `src/otp/otp_core.dart`. Do not duplicate truncation logic.

### 1.4 Verifiers (server or local)
```dart
sealed class VerificationResult { const VerificationResult(); }
final class Accepted extends VerificationResult {
  final int step;            // TOTP: matched step; HOTP: matched counter
  final int nextState;       // TOTP: new lastUsedStep; HOTP: next counter to persist
  final int offset;          // TOTP: -window..+window; HOTP: look-ahead index
}
final class Rejected extends VerificationResult { final RejectReason reason; }
enum RejectReason { invalid, replayed, malformed }

final class TotpVerifier {
  TotpVerifier({required Totp totp, int window = 1, AttemptLimiter? limiter});
  /// [subject] keys the limiter (user id / account id). [lastUsedStep] enables replay protection.
  /// Throws VerificationRateLimited before any HMAC is computed if limited.
  Future<VerificationResult> verify(String code, {required String subject, int? lastUsedStep, DateTime? at});
}

final class HotpVerifier {
  HotpVerifier({required Hotp hotp, int lookAhead = 10, AttemptLimiter? limiter});
  Future<VerificationResult> verify(String code, {required String subject, required int counter});
  Future<VerificationResult> resync(String code1, String code2, {required String subject, required int counter, int resyncWindow = 100});
}
```
Verifiers are `async` only because the limiter store may be remote; the HMAC path itself is synchronous.

As built (M1-07): input normalisation removes ASCII spaces only and requires exactly `digits` ASCII digits (else `malformed`, which still counts as an attempt); `window` 0..10, `lookAhead` 0..100, `resyncWindow` 1..1000 (else `OtpConfigException`); the TOTP/HOTP configuration is validated in the constructor; every candidate in the window is compared (nearest offset wins, no early exit); a match at a step ≤ `lastUsedStep` is `replayed`; with a limiter, check → compute → record is atomic per subject.

### 1.5 Attempt limiting
```dart
@immutable
final class LimiterPolicy {
  const LimiterPolicy({this.maxAttempts = 5, this.window = const Duration(minutes: 5),
      this.backoffBase = const Duration(seconds: 1), this.backoffMax = const Duration(minutes: 15),
      this.lockoutAfter = 20});   // validated by AttemptLimiter (OtpConfigException field "policy.<name>")
}
@immutable
final class AttemptState {        // defined at M1-06
  const AttemptState({required int consecutiveFailures, required int windowFailures,
      required DateTime windowStart, required DateTime lastFailureAt});
  factory AttemptState.fromJson(Map<String, Object?> json);   // FormatException on bad/unknown-version data
  Map<String, Object?> toJson();                              // versioned ("v": 1), for server stores
}
abstract interface class AttemptStore {
  Future<AttemptState?> read(String subject);
  Future<void> write(String subject, AttemptState state);
  Future<void> clear(String subject);                          // also the administrative unlock
}
final class AttemptLimiter {
  AttemptLimiter({required AttemptStore store, LimiterPolicy policy = const LimiterPolicy(), Clock clock = const SystemClock()});
  Future<void> ensureAllowed(String subject);     // throws VerificationRateLimited(retryAfter, lockedOut)
  Future<void> recordFailure(String subject);
  Future<void> recordSuccess(String subject);
}
final class InMemoryAttemptStore implements AttemptStore { … }   // main library only (not testing.dart)
```
Rules: window (`maxAttempts` per `window`), exponential back-off `min(base·2^(n−1), max)`, hard lockout after `lockoutAfter` consecutive failures (`VerificationRateLimited.lockedOut == true`; waiting does not lift it). Operations are serialised per subject in-process; verifiers check → compute → record atomically, so a parallel burst cannot exceed the limits. Cross-process atomicity is the store's responsibility (documented).

### 1.6 otpauth URIs
```dart
enum CompatibilityWarning { nonDefaultAlgorithm, nonDefaultDigits, nonDefaultPeriod, issuerMismatch, shortSecret }

@immutable
final class OtpAuthUri {
  const OtpAuthUri({required this.type, required this.secret, required this.accountName,
      this.issuer, this.algorithm = OtpAlgorithm.sha1, this.digits = 6,
      this.period = const Duration(seconds: 30), this.counter, this.extras = const {}});
  factory OtpAuthUri.parse(String uri);          // throws OtpAuthUriException(field, reason) — a FormatException
  static OtpAuthUri? tryParse(String uri);
  Uri toUri();                                   // contains the secret; validates (throws OtpAuthUriException)
  @override String toString();                   // REDACTED: "OtpAuthUri(totp, Issuer:account, secret: <redacted 20B>)" (M1-05; the URI holds the secret, S8)
  List<CompatibilityWarning> get compatibilityWarnings;
  TotpConfig? get totpConfig; HotpConfig? get hotpConfig;
}
```
Parsing rules (M1-05): label split at the first literal `:` or `%3A`, parts trimmed; known parameter names case-insensitive and must not repeat; unknown parameters kept in `extras`; `counter` on TOTP and `period` on HOTP ignored; `issuer` parameter wins over a different label prefix (warning). Generation rejects colons in issuer/account (Key URI format) and emits only non-default parameters.

### 1.7 Accounts (shared model used by client, UI, backup)
```dart
enum ProtectionLevel { standard, biometric, hardwareBound }

@immutable
final class OtpAccount {             // NO secret inside
  final String id;                   // uuid v4
  final OtpType type; final String? issuer; final String accountName;
  final OtpAlgorithm algorithm; final int digits; final Duration period;
  final int? counter; final int? lastUsedStep;
  final ProtectionLevel protection; final DateTime createdAt;
  String get displayName;            // "Issuer (account)" or account
}
```

### 1.8 Backup
```dart
final class BackupEntry { final OtpAccount account; final OtpSecret secret; }
abstract final class PassphrasePolicy {
  static PassphraseCheck check(String passphrase); // ok | tooShort | tooCommon | lowVariety
}
final class BackupCodec {
  const BackupCodec({this.iterations = 600000});
  Future<Uint8List> encrypt(List<BackupEntry> entries, String passphrase, {Random? random}); // throws BackupWeakPassphrase
  Future<List<BackupEntry>> decrypt(Uint8List data, String passphrase);   // throws BackupDecryptFailed / BackupUnsupportedVersion
  String armor(Uint8List data); Uint8List dearmor(String text);
}
```

### 1.9 Errors
As listed in `02_ARCHITECTURE.md §6`. All extend `MfaException implements Exception` with `toString()` that never contains secret material. Details fixed at M1-01:
```dart
sealed class MfaException implements Exception {}           // value equality; toString = "Type(key: value, …)"
final class OtpConfigException extends MfaException { final String field; final String reason; } // also used for bad digits (FR-OTP-01 AC2)
final class OtpAuthUriException extends MfaException implements FormatException {
  final String field; final String reason;                   // message = "field: reason"; source/offset always null (URI holds the secret)
}
final class VerificationRateLimited extends MfaException { final Duration retryAfter; final bool lockedOut; } // lockedOut added at M1-06
sealed class VaultException extends MfaException {}
  VaultNotFound() · VaultUserCancelled() · VaultKeyInvalidated() · VaultCorrupted()
  VaultHardwareUnavailable(HardwareUnavailableReason reason) · VaultUnavailable(VaultUnavailableReason reason) · VaultUnknown(String code)
enum HardwareUnavailableReason { secureEnclaveUnavailable, strongBoxUnavailable, biometricsNotEnrolled, biometricsUnavailable, unsupportedOnPlatform }
enum VaultUnavailableReason { insecureContext, hostActivityNotFragmentActivity, storageUnavailable, deviceLocked }
sealed class BackupException extends MfaException {}
  BackupDecryptFailed() · BackupUnsupportedVersion(int version) · BackupWeakPassphrase(PassphraseCheck check)
enum PassphraseCheck { ok, tooShort, tooCommon, lowVariety }
```

### 1.11 Utilities
```dart
/// FIFO async lock used to serialise index read-modify-write (02 §4.1). Exported because flutter_mfa needs it.
final class AsyncMutex { bool get isLocked; Future<T> protect<T>(FutureOr<T> Function() action); }
```
Constant-time comparison (`constantTimeEquals`) stays internal to core (`src/util/`); only the verifiers use it.

### 1.10 Testing library — `package:flutter_mfa_core/testing.dart`
`FakeClock(DateTime)` with `advance(Duration)`, `SeededRandom(int)` (deterministic, insecure — exported only from `testing.dart`, never from the main library), `rfc4226Vectors`, `rfc6238Vectors`. (`InMemoryAttemptStore` lives in the main library: it is a legitimate default, not a fake.)

---

## 2. `flutter_mfa_platform_interface`
```dart
abstract base class MfaPlatform extends PlatformInterface {
  static MfaPlatform get instance; static set instance(MfaPlatform v);
  Future<VaultCapabilities> capabilities();
  Future<void> write(String key, Uint8List value, ProtectionLevel level);
  Future<Uint8List?> read(String key, {BiometricPrompt? prompt});
  Future<void> delete(String key);
  Future<List<String>> keys();
  Future<void> wipe();
  Future<void> copySensitive(String text, {Duration expiry = const Duration(seconds: 30)});
  Future<void> setScreenCaptureProtection(bool enabled);   // Android FLAG_SECURE; no-op elsewhere, reported in capabilities
}
@immutable final class VaultCapabilities { bool hardwareBacked, strongBox, secureEnclave, biometricsEnrolled, secureContext, persistentStorage; Set<ProtectionLevel> supportedLevels; }
@immutable final class BiometricPrompt { String title; String? subtitle; String cancelLabel; }
```
Pigeon schema `pigeons/messages.dart` is the source of truth for the mobile wire format and error codes. `lib/testing.dart` exports `InMemoryMfaPlatform` (configurable capabilities, injectable failures) — used by `flutter_mfa` unit tests and the UI example.

---

## 3. `flutter_mfa`
```dart
final class MfaClient {
  static Future<MfaClient> create({MfaClientOptions options = const MfaClientOptions()});
  Future<VaultCapabilities> get capabilities;

  // enrolment (authenticator side)
  Future<OtpAccount> enrollFromUri(String otpauthUri, {ProtectionLevel protection = ProtectionLevel.standard});
  Future<OtpAccount> enrollManual({required String secretBase32, required String accountName, String? issuer,
      OtpType type = OtpType.totp, TotpConfig? totp, HotpConfig? hotp, int? counter,
      ProtectionLevel protection = ProtectionLevel.standard});

  // reading
  Stream<List<OtpAccount>> watchAccounts();
  Future<List<OtpAccount>> accounts();
  Future<OtpCode> currentCode(String accountId, {BiometricPrompt? prompt});   // HOTP: increments + persists counter
  Stream<OtpCode> codeStream(String accountId, {BiometricPrompt? prompt});    // TOTP only
  Future<void> copyCode(String accountId);                                     // via copySensitive

  // mutation
  Future<OtpAccount> rename(String accountId, {String? issuer, String? accountName});
  Future<void> remove(String accountId);
  Future<void> wipeAll();

  // relying-party helpers (client side of enrolment; verify belongs on your server)
  static RelyingPartyEnrollment createEnrollment({required String issuer, required String accountName, TotpConfig config = const TotpConfig()});

  // backup
  Future<Uint8List> exportEncrypted(String passphrase, {Iterable<String>? accountIds});
  Future<ImportReport> importEncrypted(Uint8List data, String passphrase, {DuplicateStrategy onDuplicate = DuplicateStrategy.skip});

  // integrity
  Future<IntegrityReport> checkIntegrity();
  Future<void> dispose();
}

@immutable final class OtpCode { final String value; final Duration remaining; final double progress; final int step; String get grouped; }
@immutable final class MfaClientOptions { final Clock clock; final DeviceIntegrityCheck integrityCheck; final IntegrityPolicy? integrityPolicy; final MfaLogger logger; final Duration clipboardExpiry; }
abstract interface class DeviceIntegrityCheck { Future<IntegrityReport> run(); }
typedef IntegrityPolicy = Future<void> Function(IntegrityReport report); // app decides: warn / block
```
`flutter_mfa.dart` re-exports the core public API (not `testing.dart`) so apps need one import.

---

## 4. `flutter_mfa_ui`
```dart
class MfaTheme extends InheritedWidget { static MfaThemeData of(BuildContext); }
class MfaThemeData { factory MfaThemeData.fromMaterial(ThemeData t) /* in material_adapter.dart */; factory MfaThemeData.fromCupertino(...); … }

class OtpCodeField extends StatefulWidget {
  const OtpCodeField({super.key, this.length = 6, required this.onCompleted, this.onChanged,
      this.controller, this.errorText, this.autofocus = false, this.obscure = false, this.semanticLabel});
}
class OtpCodeDisplay extends StatelessWidget { const OtpCodeDisplay({required this.code, this.onCopy, this.hidden = false}); }
class OtpCountdownRing extends StatelessWidget { const OtpCountdownRing({required this.progress, required this.remaining}); }
class MfaStatusBadge extends StatelessWidget { const MfaStatusBadge({required this.status}); }
enum MfaStatus { enrolled, notEnrolled, locked, keyInvalidated, integrityWarning }
class OtpAccountTile extends StatelessWidget { const OtpAccountTile({required this.account, required this.codeStream, this.onTap, this.onCopy}); }
class OtpAccountList extends StatelessWidget { … }
class EnrollmentQrView extends StatelessWidget { const EnrollmentQrView({required this.uri, this.showSecret = true}); }
class MfaLocalizations { static const delegate; static const supportedLocales; }
```
`material_adapter.dart` and `cupertino_adapter.dart` are the **only** files allowed to import Material/Cupertino (CI script). QR rendering uses `qr` (pure Dart) painted with `CustomPainter` — no Material-dependent QR widget.

---

## 5. `flutter_mfa_qr`
```dart
class OtpQrScanner extends StatefulWidget {
  const OtpQrScanner({super.key, required this.onScanned, this.onRejected,
      this.permissionBuilder, this.overlayBuilder, this.webOptions = const OtpQrWebOptions()});
  final ValueChanged<OtpAuthUri> onScanned;
  final ValueChanged<String>? onRejected;    // non-otpauth payloads (never logged)
}
@immutable final class OtpQrWebOptions { const OtpQrWebOptions({this.allowRemoteDecoder = false, this.decoderScriptUrl}); }
```

---

## 6. Usage snippets (must compile — kept in `example/` and doc-tested)

Server verify:
```dart
final secret = OtpSecret.fromBase32(user.totpSecret);
final verifier = TotpVerifier(totp: Totp(secret), limiter: AttemptLimiter(store: redisStore));
final r = await verifier.verify(code, subject: user.id, lastUsedStep: user.lastStep);
if (r case Accepted(:final nextState)) { await users.saveLastStep(user.id, nextState); }
```

App authenticator:
```dart
final mfa = await MfaClient.create();
final acct = await mfa.enrollFromUri(scannedUri, protection: ProtectionLevel.biometric);
mfa.codeStream(acct.id, prompt: const BiometricPrompt(title: 'Unlock code')).listen(print);
```
