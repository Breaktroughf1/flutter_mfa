import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;

import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:flutter_mfa_platform_interface/flutter_mfa_platform_interface.dart';

import '../integrity/device_integrity.dart';
import '../logging/mfa_logger.dart';
import '../repository/account_repository.dart';
import 'backup_import.dart';
import 'code_ticker.dart';
import 'mfa_client_options.dart';
import 'relying_party_enrollment.dart';

/// The single entry point for apps: enrol accounts, list them and produce
/// codes, with secrets kept in the platform vault (FR-FAC-01).
///
/// This is the **authenticator** side. Verifying codes belongs on your
/// server (`TotpVerifier`); see ADR-0002.
///
/// Secrets never leave the vault except transiently in memory to compute a
/// code; they are wiped after use where Dart allows. Nothing here logs
/// secrets, codes or URIs.
final class MfaClient {
  MfaClient._(this._platform, this._options)
    : _repository = AccountRepository(_platform),
      _ticker = CodeTicker(_options.clock);

  /// Creates a client over `MfaPlatform.instance`.
  ///
  /// Probes the vault so an unusable environment fails here with a
  /// `VaultException` (for example `VaultUnavailable(insecureContext)` on
  /// web). The account index is loaded lazily, so a corrupted index does not
  /// prevent creating a client and calling [wipeAll].
  ///
  /// Then runs [MfaClientOptions.integrityCheck] and passes the report to
  /// [MfaClientOptions.integrityPolicy]; whatever the policy throws is thrown
  /// here, so an app can refuse to start on a compromised device.
  static Future<MfaClient> create({
    MfaClientOptions options = const MfaClientOptions(),
  }) async {
    final platform = MfaPlatform.instance;
    await platform.capabilities();
    final client = MfaClient._(platform, options);
    try {
      await client._runIntegrity();
    } on Object {
      await client.dispose();
      rethrow;
    }
    return client;
  }

  final MfaPlatform _platform;
  final MfaClientOptions _options;
  final AccountRepository _repository;
  final CodeTicker _ticker;
  final _changes = StreamController<List<OtpAccount>>.broadcast();
  bool _disposed = false;

  /// What this device's vault can provide; use it to offer protection levels.
  Future<VaultCapabilities> get capabilities {
    _checkOpen();
    return _platform.capabilities();
  }

  /// Starts enrolling a user in TOTP on the relying-party side (FR-FAC-07).
  ///
  /// Generates a new secret of the recommended length for the algorithm in
  /// [config] (20, 32 or 64 bytes) with a secure random generator, and
  /// returns its `otpauth://` URI with a `TotpVerifier` for the
  /// confirm-first-code step. Nothing is stored: keep the secret on your
  /// server once the first code is confirmed. This touches no vault, so it
  /// needs no client.
  ///
  /// Pass the server's shared [limiter] so confirmation attempts are
  /// throttled; without one the returned verifier does not limit guesses.
  ///
  /// Throws `OtpConfigException` for an empty [issuer] or [accountName],
  /// an invalid configuration, or a non-zero `TotpConfig.t0`, which
  /// `otpauth://` URIs cannot carry; `OtpAuthUriException` for an issuer
  /// containing a colon (the label separator).
  static RelyingPartyEnrollment createEnrollment({
    required String issuer,
    required String accountName,
    TotpConfig config = const TotpConfig(),
    AttemptLimiter? limiter,
  }) {
    final trimmedIssuer = issuer.trim();
    final trimmedName = accountName.trim();
    if (trimmedIssuer.isEmpty) {
      throw const OtpConfigException(
        field: 'issuer',
        reason: 'must not be empty',
      );
    }
    if (trimmedName.isEmpty) {
      throw const OtpConfigException(
        field: 'accountName',
        reason: 'must not be empty',
      );
    }
    if (config.t0 != 0) {
      throw const OtpConfigException(
        field: 't0',
        reason: 'must be 0 for an otpauth:// URI',
      );
    }
    final secret = OtpSecret.generate(
      length: OtpSecret.recommendedLength(config.algorithm),
    );
    // Validates the configuration (OtpConfigException) before the URI.
    final verifier = TotpVerifier(
      totp: Totp(secret, config: config),
      limiter: limiter,
    );
    final uri = OtpAuthUri(
      type: OtpType.totp,
      secret: secret,
      issuer: trimmedIssuer,
      accountName: trimmedName,
      algorithm: config.algorithm,
      digits: config.digits,
      period: config.period,
    );
    // Building the URI validates the label and parameters.
    uri.toUri();
    return RelyingPartyEnrollment(uri: uri, verifier: verifier);
  }

  /// Enrols the account described by an `otpauth://` URI (UC1).
  ///
  /// Throws `OtpAuthUriException` for an invalid URI and
  /// `VaultHardwareUnavailable` if [protection] is not supported (the account
  /// is never stored with weaker protection).
  Future<OtpAccount> enrollFromUri(
    String otpauthUri, {
    ProtectionLevel protection = ProtectionLevel.standard,
  }) async {
    _checkOpen();
    final uri = OtpAuthUri.parse(otpauthUri);
    return _enroll(
      secret: uri.secret,
      type: uri.type,
      issuer: uri.issuer,
      accountName: uri.accountName,
      algorithm: uri.algorithm,
      digits: uri.digits,
      period: uri.period,
      counter: uri.counter,
      protection: protection,
    );
  }

  /// Enrols an account from a typed-in Base32 secret (UC2).
  ///
  /// Pass [totp] or [hotp] to override defaults; HOTP starts at [counter]
  /// (default 0). Throws `OtpConfigException` for an invalid secret, name or
  /// configuration, and `VaultHardwareUnavailable` for an unsupported
  /// [protection].
  Future<OtpAccount> enrollManual({
    required String secretBase32,
    required String accountName,
    String? issuer,
    OtpType type = OtpType.totp,
    TotpConfig? totp,
    HotpConfig? hotp,
    int? counter,
    ProtectionLevel protection = ProtectionLevel.standard,
  }) async {
    _checkOpen();
    final secret = OtpSecret.fromBase32(secretBase32);
    final totpConfig = totp ?? const TotpConfig();
    final hotpConfig = hotp ?? const HotpConfig();
    final isTotp = type == OtpType.totp;
    return _enroll(
      secret: secret,
      type: type,
      issuer: (issuer == null || issuer.trim().isEmpty) ? null : issuer.trim(),
      accountName: accountName.trim(),
      algorithm: isTotp ? totpConfig.algorithm : hotpConfig.algorithm,
      digits: isTotp ? totpConfig.digits : hotpConfig.digits,
      period: totpConfig.period,
      counter: isTotp ? null : (counter ?? 0),
      protection: protection,
    );
  }

  Future<OtpAccount> _enroll({
    required OtpSecret secret,
    required OtpType type,
    required String? issuer,
    required String accountName,
    required OtpAlgorithm algorithm,
    required int digits,
    required Duration period,
    required int? counter,
    required ProtectionLevel protection,
  }) async {
    if (accountName.isEmpty) {
      throw const OtpConfigException(
        field: 'accountName',
        reason: 'must not be empty',
      );
    }
    // Validate the configuration before anything is stored.
    if (type == OtpType.totp) {
      Totp(
        secret,
        config: TotpConfig(
          algorithm: algorithm,
          digits: digits,
          period: period,
        ),
      ).generateForStep(0);
    } else {
      Hotp(
        secret,
        config: HotpConfig(algorithm: algorithm, digits: digits),
      ).generate(counter!);
    }
    final account = OtpAccount(
      id: OtpAccount.generateId(),
      type: type,
      issuer: issuer,
      accountName: accountName,
      algorithm: algorithm,
      digits: digits,
      period: period,
      counter: counter,
      protection: protection,
      createdAt: _options.clock.now().toUtc(),
    );
    final bytes = secret.bytes;
    try {
      await _repository.add(account, bytes);
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
    _log(
      MfaLogLevel.info,
      'enrolled ${account.id} (${type.name}, ${protection.name})',
    );
    await _notify();
    return account;
  }

  /// All enrolled accounts, oldest first. Throws `VaultCorrupted` if the
  /// index cannot be read (recover with [wipeAll] or a backup).
  Future<List<OtpAccount>> accounts() {
    _checkOpen();
    return _repository.list();
  }

  /// The current accounts, then the new list after every change.
  Stream<List<OtpAccount>> watchAccounts() async* {
    _checkOpen();
    yield await _repository.list();
    yield* _changes.stream;
  }

  /// The current code of account [accountId] (UC3).
  ///
  /// For protected accounts the OS shows [prompt] (default:
  /// [MfaClientOptions.defaultPrompt]) and the secret is decrypted only after
  /// the biometric check. For HOTP the counter is advanced and persisted
  /// **before** the code is returned, so a code is never reused; an account
  /// whose counter reached `Hotp.maxCounter` is exhausted and throws
  /// `OtpConfigException` instead. Throws `VaultNotFound`,
  /// `VaultUserCancelled`, `VaultKeyInvalidated` or `VaultCorrupted`.
  Future<OtpCode> currentCode(
    String accountId, {
    BiometricPrompt? prompt,
  }) async {
    _checkOpen();
    final account = await _repository.get(accountId);
    final secret = await _readSecret(account, prompt);
    if (account.type == OtpType.totp) {
      return totpCode(_totp(account, secret), _options.clock.now());
    }

    var used = 0;
    await _repository.modify(accountId, (current) {
      used = current.counter!;
      // The next counter could not be stored, so this one is never issued.
      if (used >= Hotp.maxCounter) {
        throw const OtpConfigException(
          field: 'counter',
          reason: 'is exhausted; re-enrol the account',
        );
      }
      return current.copyWith(counter: () => used + 1);
    });
    await _notify();
    return OtpCode(
      value: Hotp(secret, config: account.hotpConfig!).generate(used),
      remaining: Duration.zero,
      progress: 0,
      step: used,
    );
  }

  /// Live codes of time-based account [accountId] (FR-FAC-02).
  ///
  /// Emits the current code when listened to, then every second (with the
  /// updated countdown) and exactly once at each step change. The secret is
  /// read once per subscription, so a protected account shows [prompt] once,
  /// not every second; cancel the subscription when the code is off screen.
  /// All live streams of this client share one timer. Errors
  /// (`VaultNotFound`, `VaultUserCancelled`, `VaultKeyInvalidated`,
  /// `VaultCorrupted`, or `OtpConfigException` for a counter-based account,
  /// which has no live code: use [currentCode], or for a device clock before
  /// 1970) arrive on the stream, which then closes. [dispose] closes every
  /// live stream.
  Stream<OtpCode> codeStream(String accountId, {BiometricPrompt? prompt}) {
    _checkOpen();
    return tickCodes(
      ticker: _ticker,
      load: () async {
        final account = await _repository.get(accountId);
        if (account.type != OtpType.totp) {
          throw const OtpConfigException(
            field: 'type',
            reason: 'live codes need a time-based (TOTP) account',
          );
        }
        return _totp(account, await _readSecret(account, prompt));
      },
    );
  }

  /// Copies the current code of [accountId] with [copySensitive] (FR-FAC-05).
  ///
  /// For a counter-based account this generates (and uses up) the next code,
  /// like [currentCode].
  Future<void> copyCode(String accountId) async {
    final code = await currentCode(accountId);
    await copySensitive(code.value);
    _log(MfaLogLevel.info, 'copied code of $accountId');
  }

  /// Copies [text] (a code or a setup key) marked sensitive where the
  /// platform supports it, and clears it after
  /// [MfaClientOptions.clipboardExpiry] (FR-FAC-05).
  ///
  /// Android 13+ hides sensitive clips from previews and suggestions; iOS
  /// keeps the clip local (never Universal Clipboard) and expires it; the web
  /// clears it only when that is possible without a permission prompt. Other
  /// apps can still read the clipboard until it is cleared.
  Future<void> copySensitive(String text) {
    _checkOpen();
    return _platform.copySensitive(text, expiry: _options.clipboardExpiry);
  }

  /// Hides the app from screenshots, screen recording and the recent-apps
  /// preview while [enabled] (FR-FAC-06): Android `FLAG_SECURE` on the
  /// current activity, kept across activity re-creation.
  ///
  /// iOS and the web cannot block screenshots; there this does nothing, and
  /// `capabilities.screenCaptureProtection` is `false`, so apps can explain
  /// it or blur their own snapshot. It does not stop a camera pointed at the
  /// screen or a rooted device.
  Future<void> setScreenCaptureProtection(bool enabled) async {
    _checkOpen();
    await _platform.setScreenCaptureProtection(enabled);
    _log(
      MfaLogLevel.info,
      'screen capture protection ${enabled ? 'on' : 'off'}',
    );
  }

  /// Changes the displayed [issuer] and/or [accountName] of an account.
  /// `null` leaves a field unchanged.
  Future<OtpAccount> rename(
    String accountId, {
    String? issuer,
    String? accountName,
  }) async {
    _checkOpen();
    if (accountName != null && accountName.trim().isEmpty) {
      throw const OtpConfigException(
        field: 'accountName',
        reason: 'must not be empty',
      );
    }
    final updated = await _repository.modify(
      accountId,
      (a) => a.copyWith(
        issuer: issuer == null
            ? null
            : () => issuer.trim().isEmpty ? null : issuer.trim(),
        accountName: accountName?.trim(),
      ),
    );
    await _notify();
    return updated;
  }

  /// Deletes account [accountId] and its secret (UC8). Throws
  /// `VaultNotFound` if absent.
  Future<void> remove(String accountId) async {
    _checkOpen();
    await _repository.remove(accountId);
    _log(MfaLogLevel.info, 'removed $accountId');
    await _notify();
  }

  /// Deletes every account and secret. Also the recovery path for a
  /// corrupted index.
  Future<void> wipeAll() async {
    _checkOpen();
    await _repository.wipe();
    _log(MfaLogLevel.warning, 'vault wiped');
    await _notify();
  }

  /// An encrypted backup of every account, or of [accountIds] only
  /// (FR-BAK-01, UC6).
  ///
  /// The backup is format v1 (PBKDF2-HMAC-SHA256 with 600 000 iterations,
  /// AES-256-GCM): store it anywhere, and turn it into text with
  /// `BackupCodec().armor`. There is no unencrypted export. The passphrase
  /// is checked against `PassphrasePolicy` before any secret is read, so a
  /// weak one throws `BackupWeakPassphrase` without biometric prompts.
  /// Protected accounts then show [MfaClientOptions.defaultPrompt], once
  /// each. The slow key derivation runs on a background isolate on Android
  /// and iOS and in WebCrypto on the web, so the UI keeps running.
  ///
  /// Protects the secrets against anyone without the passphrase. It does not
  /// protect against a guessed passphrase beyond the policy, and secret
  /// bytes copied to the background isolate cannot be wiped there.
  ///
  /// Throws `VaultNotFound` for an unknown id in [accountIds],
  /// `VaultUserCancelled` and other `VaultException`s from reading secrets.
  Future<Uint8List> exportEncrypted(
    String passphrase, {
    Iterable<String>? accountIds,
  }) async {
    _checkOpen();
    final check = PassphrasePolicy.check(passphrase);
    if (check != PassphraseCheck.ok) throw BackupWeakPassphrase(check);
    final all = await _repository.list();
    final List<OtpAccount> selected;
    if (accountIds == null) {
      selected = all;
    } else {
      final byId = {for (final a in all) a.id: a};
      selected = [
        for (final id in {...accountIds})
          byId[id] ?? (throw const VaultNotFound()),
      ];
    }
    final entries = <BackupEntry>[
      for (final account in selected)
        BackupEntry(
          account: account,
          secret: await _readSecret(account, null),
        ),
    ];
    final data = await compute(_encryptBackup, (entries, passphrase));
    _log(MfaLogLevel.info, 'exported ${entries.length} accounts');
    return data;
  }

  /// Restores the accounts of a backup made by [exportEncrypted] on any
  /// platform (FR-BAK-03, UC7).
  ///
  /// The import is all or nothing: the backup is decrypted and checked in
  /// full before anything is stored, and the accounts are then added in one
  /// change of the index. If anything fails, the secrets already written are
  /// deleted and the vault is left as it was. Accounts already on the
  /// device are handled by [onDuplicate] (see [DuplicateStrategy]). Each
  /// account keeps its protection level; one this device cannot provide
  /// fails the import with `VaultHardwareUnavailable` rather than storing it
  /// with weaker protection.
  ///
  /// Throws `BackupDecryptFailed` for a wrong passphrase or modified data
  /// (indistinguishable on purpose), `BackupUnsupportedVersion` for a newer
  /// format, and `VaultException`s from the vault.
  Future<ImportReport> importEncrypted(
    Uint8List data,
    String passphrase, {
    DuplicateStrategy onDuplicate = DuplicateStrategy.skip,
  }) async {
    _checkOpen();
    final entries = await compute(_decryptBackup, (data, passphrase));
    final secrets = [for (final e in entries) e.secret.bytes];
    try {
      final report = await _repository.batch((current) {
        final plan = planImport(
          current,
          [for (final e in entries) e.account],
          onDuplicate,
          OtpAccount.generateId,
        );
        return (
          add: [for (final (a, i) in plan.add) (a, secrets[i])],
          remove: plan.remove,
          result: plan.report,
        );
      });
      _log(
        MfaLogLevel.info,
        'imported backup (${report.added.length} added, '
        '${report.replaced.length} replaced, ${report.skipped.length} '
        'skipped)',
      );
      await _notify();
      return report;
    } finally {
      for (final s in secrets) {
        s.fillRange(0, s.length, 0);
      }
    }
  }

  /// Runs the device integrity check again and applies the policy
  /// (FR-FAC-03), for example when the app returns to the foreground.
  ///
  /// Returns the report, or throws what the policy throws. Detection only:
  /// see [DeviceIntegrityCheck] for what this does not protect against.
  Future<IntegrityReport> checkIntegrity() {
    _checkOpen();
    return _runIntegrity();
  }

  Future<IntegrityReport> _runIntegrity() async {
    final report = await _options.integrityCheck.run();
    _log(
      report.verdict == IntegrityVerdict.compromised
          ? MfaLogLevel.warning
          : MfaLogLevel.info,
      'integrity ${report.verdict.name}',
    );
    await _options.integrityPolicy(report);
    return report;
  }

  /// Releases resources; the client cannot be used afterwards.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _ticker.close();
    await _changes.close();
  }

  /// The secret of [account], decrypted after [prompt] for protected
  /// accounts. The vault's buffer is wiped before returning.
  Future<OtpSecret> _readSecret(
    OtpAccount account,
    BiometricPrompt? prompt,
  ) async {
    final bytes = await _repository.readSecret(
      account,
      prompt ?? _options.defaultPrompt,
    );
    try {
      return OtpSecret.fromBytes(bytes);
    } on OtpConfigException {
      throw const VaultCorrupted();
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  Totp _totp(OtpAccount account, OtpSecret secret) =>
      Totp(secret, config: account.totpConfig!, clock: _options.clock);

  Future<void> _notify() async {
    if (_changes.hasListener) _changes.add(await _repository.list());
  }

  void _log(MfaLogLevel level, String message) =>
      _options.logger.log(level, message);

  void _checkOpen() {
    if (_disposed) throw StateError('MfaClient has been disposed');
  }
}

Future<Uint8List> _encryptBackup((List<BackupEntry>, String) args) =>
    const BackupCodec().encrypt(args.$1, args.$2);

Future<List<BackupEntry>> _decryptBackup((Uint8List, String) args) =>
    const BackupCodec().decrypt(args.$1, args.$2);
