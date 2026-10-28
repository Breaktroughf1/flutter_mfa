import 'dart:math';

import 'package:meta/meta.dart';

import '../otp/hotp.dart';
import '../otp/otp_algorithm.dart';
import '../otp/totp.dart';

/// How strongly an account's secret is protected in the vault (FR-VLT-05).
///
/// A level is never silently downgraded: requesting one the device cannot
/// provide throws `VaultHardwareUnavailable`.
enum ProtectionLevel {
  /// Encrypted under a non-exportable platform key; no user authentication.
  standard,

  /// Decryptable only after a fresh strong-biometric authentication bound to
  /// the key operation (FR-VLT-06).
  biometric,

  /// [biometric] plus a hardware-isolated key (StrongBox or Secure Enclave).
  hardwareBound,
}

/// Non-secret metadata of an enrolled account (03 §1.7).
///
/// Holds no secret: the seed is stored separately in the vault under the
/// account [id]. Shared by the client, the UI and the backup format; this
/// is the only account (de)serialisation (DRY).
@immutable
final class OtpAccount {
  /// Creates account metadata. Use [generateId] for new accounts.
  const OtpAccount({
    required this.id,
    required this.type,
    required this.accountName,
    required this.createdAt,
    this.issuer,
    this.algorithm = OtpAlgorithm.sha1,
    this.digits = 6,
    this.period = const Duration(seconds: 30),
    this.counter,
    this.lastUsedStep,
    this.protection = ProtectionLevel.standard,
  });

  /// Decodes [toJson] output. Throws [FormatException] (never containing the
  /// input) on malformed, inconsistent or unknown-version data.
  factory OtpAccount.fromJson(Map<String, Object?> json) {
    T field<T>(String key, bool Function(T value) valid) {
      final value = json[key];
      if (value is T && valid(value)) return value;
      throw FormatException('invalid OtpAccount field: $key');
    }

    field<int>('v', (v) => v == 1);
    final type = _byName(
      OtpType.values,
      field<String>('type', (_) => true),
      'type',
    );
    final counter = field<int?>(
      'counter',
      (c) => c == null || (c >= 0 && c <= Hotp.maxCounter),
    );
    if (type == OtpType.hotp && counter == null) {
      throw const FormatException('invalid OtpAccount field: counter');
    }
    final created = DateTime.tryParse(field<String>('createdAt', (_) => true));
    if (created == null) {
      throw const FormatException('invalid OtpAccount field: createdAt');
    }
    return OtpAccount(
      id: field<String>('id', _uuidV4.hasMatch),
      type: type,
      issuer: field<String?>('issuer', (i) => i == null || i.isNotEmpty),
      accountName: field<String>('accountName', (a) => a.isNotEmpty),
      algorithm: _byName(
        OtpAlgorithm.values,
        field<String>('algorithm', (_) => true),
        'algorithm',
      ),
      digits: field<int>('digits', (d) => d >= 6 && d <= 8),
      period: Duration(seconds: field<int>('periodSeconds', (p) => p >= 1)),
      counter: counter,
      lastUsedStep: field<int?>('lastUsedStep', (s) => s == null || s >= 0),
      protection: _byName(
        ProtectionLevel.values,
        field<String>('protection', (_) => true),
        'protection',
      ),
      createdAt: created.toUtc(),
    );
  }

  /// A new random RFC 9562 version-4 UUID.
  ///
  /// Uses `Random.secure()` unless [random] is supplied (tests only).
  static String generateId({Random? random}) {
    final rng = random ?? Random.secure();
    final b = List<int>.generate(16, (_) => rng.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40; // version 4
    b[8] = (b[8] & 0x3f) | 0x80; // RFC 9562 variant
    final hex = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// Stable identifier (UUID v4); also the vault key of the secret.
  final String id;

  /// TOTP or HOTP.
  final OtpType type;

  /// Service name, or `null`.
  final String? issuer;

  /// Account name, for example an email address.
  final String accountName;

  /// HMAC algorithm.
  final OtpAlgorithm algorithm;

  /// Code length (6–8).
  final int digits;

  /// TOTP period.
  final Duration period;

  /// HOTP: the next counter to use. `null` for TOTP.
  final int? counter;

  /// TOTP: the last step a code was used for locally (replay guard for
  /// on-device verification), or `null`.
  final int? lastUsedStep;

  /// Vault protection of the secret.
  final ProtectionLevel protection;

  /// When the account was enrolled (UTC).
  final DateTime createdAt;

  /// `Issuer (account)`, or just the account name without an issuer.
  String get displayName =>
      issuer == null ? accountName : '$issuer ($accountName)';

  /// TOTP parameters, or `null` for HOTP.
  TotpConfig? get totpConfig => type == OtpType.totp
      ? TotpConfig(algorithm: algorithm, digits: digits, period: period)
      : null;

  /// HOTP parameters, or `null` for TOTP.
  HotpConfig? get hotpConfig => type == OtpType.hotp
      ? HotpConfig(algorithm: algorithm, digits: digits)
      : null;

  /// A copy with the given fields replaced. [issuer] and [counter] take a
  /// function so they can be set to `null`.
  OtpAccount copyWith({
    String? Function()? issuer,
    String? accountName,
    int? Function()? counter,
    int? lastUsedStep,
    ProtectionLevel? protection,
  }) => OtpAccount(
    id: id,
    type: type,
    issuer: issuer == null ? this.issuer : issuer(),
    accountName: accountName ?? this.accountName,
    algorithm: algorithm,
    digits: digits,
    period: period,
    counter: counter == null ? this.counter : counter(),
    lastUsedStep: lastUsedStep ?? this.lastUsedStep,
    protection: protection ?? this.protection,
    createdAt: createdAt,
  );

  /// JSON-compatible, versioned form used by the vault index.
  Map<String, Object?> toJson() => {
    'v': 1,
    'id': id,
    'type': type.name,
    'issuer': issuer,
    'accountName': accountName,
    'algorithm': algorithm.name,
    'digits': digits,
    'periodSeconds': period.inSeconds,
    'counter': counter,
    'lastUsedStep': lastUsedStep,
    'protection': protection.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is OtpAccount &&
      other.id == id &&
      other.type == type &&
      other.issuer == issuer &&
      other.accountName == accountName &&
      other.algorithm == algorithm &&
      other.digits == digits &&
      other.period == period &&
      other.counter == counter &&
      other.lastUsedStep == lastUsedStep &&
      other.protection == protection &&
      other.createdAt.isAtSameMomentAs(createdAt);

  @override
  int get hashCode => Object.hash(
    id,
    type,
    issuer,
    accountName,
    algorithm,
    digits,
    period,
    counter,
    lastUsedStep,
    protection,
    createdAt.millisecondsSinceEpoch,
  );

  @override
  String toString() =>
      'OtpAccount($id, ${type.name}, $displayName, ${protection.name})';

  static final _uuidV4 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  static T _byName<T extends Enum>(List<T> values, String name, String key) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    throw FormatException('invalid OtpAccount field: $key');
  }
}
