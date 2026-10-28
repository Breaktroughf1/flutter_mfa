import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:flutter_mfa_platform_interface/flutter_mfa_platform_interface.dart';

/// Stores account metadata (the index) and secrets in the vault
/// (02_ARCHITECTURE §4.1).
///
/// * The index is one JSON document under [indexKey] at
///   `ProtectionLevel.standard`; secrets live under `acct_<id>` at each
///   account's protection level.
/// * Every index read-modify-write is serialised by one [AsyncMutex], so
///   concurrent mutations never lose updates.
/// * Secrets are never left orphaned: they are written before and removed
///   before their index entry, a failed enrolment deletes its secret, and
///   leftovers are swept when the index is first loaded.
/// * A garbled or tampered index surfaces as `VaultCorrupted`; [wipe]
///   recovers.
final class AccountRepository {
  /// Creates a repository over [platform].
  AccountRepository(this._platform);

  /// Vault key of the account index.
  static const indexKey = '__index_v1__';

  static const _secretPrefix = 'acct_';

  final MfaPlatform _platform;
  final _lock = AsyncMutex();
  List<OtpAccount>? _cache;

  /// Vault key of the secret of account [id].
  static String secretKey(String id) => '$_secretPrefix$id';

  /// All accounts, oldest first.
  Future<List<OtpAccount>> list() =>
      _lock.protect(() async => List.unmodifiable(await _load()));

  /// The account with [id]. Throws `VaultNotFound` if absent.
  Future<OtpAccount> get(String id) =>
      _lock.protect(() async => _find(await _load(), id));

  /// Stores [secret] at the account's protection level, then adds [account]
  /// to the index. On failure nothing is left behind.
  Future<void> add(OtpAccount account, Uint8List secret) => _lock.protect(
    () async {
      final accounts = await _load();
      await _platform.write(secretKey(account.id), secret, account.protection);
      try {
        await _save([...accounts, account]);
      } on Object {
        await _platform.delete(secretKey(account.id));
        rethrow;
      }
    },
  );

  /// Applies [change] to account [id] atomically and returns the result.
  Future<OtpAccount> modify(
    String id,
    OtpAccount Function(OtpAccount current) change,
  ) => _lock.protect(() async {
    final accounts = await _load();
    final updated = change(_find(accounts, id));
    await _save([for (final a in accounts) a.id == id ? updated : a]);
    return updated;
  });

  /// Reads the secret of [account], showing [prompt] if it is protected.
  /// The caller owns the returned bytes and must wipe them.
  Future<Uint8List> readSecret(
    OtpAccount account,
    BiometricPrompt prompt,
  ) async {
    final bytes = await _platform.read(
      secretKey(account.id),
      prompt: account.protection == ProtectionLevel.standard ? null : prompt,
    );
    if (bytes == null) throw const VaultCorrupted();
    return bytes;
  }

  /// Deletes the secret of [id], then its index entry. Throws
  /// `VaultNotFound` if absent.
  Future<void> remove(String id) => _lock.protect(() async {
    final accounts = await _load();
    _find(accounts, id);
    await _platform.delete(secretKey(id));
    await _save([
      for (final a in accounts)
        if (a.id != id) a,
    ]);
  });

  /// Deletes every entry of this plugin (all secrets and the index).
  Future<void> wipe() => _lock.protect(() async {
    await _platform.wipe();
    _cache = [];
  });

  static OtpAccount _find(List<OtpAccount> accounts, String id) {
    for (final a in accounts) {
      if (a.id == id) return a;
    }
    throw const VaultNotFound();
  }

  Future<List<OtpAccount>> _load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await _platform.read(indexKey);
    final accounts = raw == null ? <OtpAccount>[] : _decode(raw);
    await _sweepOrphans(accounts);
    return _cache = accounts;
  }

  Future<void> _save(List<OtpAccount> accounts) async {
    final json = jsonEncode({
      'v': 1,
      'accounts': [for (final a in accounts) a.toJson()],
    });
    await _platform.write(
      indexKey,
      Uint8List.fromList(utf8.encode(json)),
      ProtectionLevel.standard,
    );
    _cache = accounts;
  }

  Future<void> _sweepOrphans(List<OtpAccount> accounts) async {
    final known = {for (final a in accounts) secretKey(a.id)};
    for (final key in await _platform.keys()) {
      if (key.startsWith(_secretPrefix) && !known.contains(key)) {
        await _platform.delete(key);
      }
    }
  }

  static List<OtpAccount> _decode(Uint8List raw) {
    try {
      final doc = jsonDecode(utf8.decode(raw));
      if (doc is! Map<String, Object?> ||
          doc['v'] != 1 ||
          doc['accounts'] is! List<Object?>) {
        throw const FormatException('invalid index');
      }
      final accounts = <OtpAccount>[];
      for (final entry in doc['accounts']! as List<Object?>) {
        if (entry is! Map<String, Object?>) {
          throw const FormatException('invalid index');
        }
        accounts.add(OtpAccount.fromJson(entry));
      }
      if (accounts.map((a) => a.id).toSet().length != accounts.length) {
        throw const FormatException('duplicate ids');
      }
      return accounts;
    } on FormatException {
      throw const VaultCorrupted();
    }
  }
}
