import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:meta/meta.dart';

/// What `MfaClient.importEncrypted` does with a backed-up account that is
/// already on this device (FR-BAK-03).
///
/// An account counts as already present when an existing account has the
/// same id (the same enrolment, backed up earlier), or the same type, issuer
/// and account name. Secrets are not compared, because reading a protected
/// secret would need a biometric prompt per account.
enum DuplicateStrategy {
  /// Keep the existing account and ignore the backed-up one.
  skip,

  /// Remove the existing account and store the backed-up one under a new id,
  /// so the old one stays intact until the import has been committed.
  replace,

  /// Keep both. The backed-up account gets a new id if its id is taken.
  keepBoth,
}

/// The outcome of `MfaClient.importEncrypted`: account metadata only, never
/// secrets (FR-BAK-03).
@immutable
final class ImportReport {
  /// Creates a report.
  const ImportReport({
    required this.added,
    required this.replaced,
    required this.skipped,
  });

  /// Accounts stored as new, as they are now on this device.
  final List<OtpAccount> added;

  /// Accounts stored in place of an existing one, with their new ids.
  final List<OtpAccount> replaced;

  /// Backed-up accounts that were not stored ([DuplicateStrategy.skip]), as
  /// they appear in the backup.
  final List<OtpAccount> skipped;

  @override
  String toString() =>
      'ImportReport(added: ${added.length}, replaced: ${replaced.length}, '
      'skipped: ${skipped.length})';
}

/// The changes an import makes, decided against the accounts present when
/// the vault lock is held.
@internal
typedef ImportPlan = ({
  /// New accounts in order, each with the index of its backup entry.
  List<(OtpAccount, int)> add,

  /// Ids of existing accounts to delete.
  Set<String> remove,
  ImportReport report,
});

/// Decides what importing [incoming] into [current] does under [strategy].
/// Pure: [newId] supplies fresh ids.
@internal
ImportPlan planImport(
  List<OtpAccount> current,
  List<OtpAccount> incoming,
  DuplicateStrategy strategy,
  String Function() newId,
) {
  // Working set: the accounts as they will be after the import.
  final working = [...current];
  final source = <String, int>{}; // id of an added account -> backup index
  final remove = <String>{};
  final added = <String>{};
  final replaced = <String>{};
  final skipped = <OtpAccount>[];

  bool sameAccount(OtpAccount a, OtpAccount b) =>
      a.id == b.id ||
      (a.type == b.type &&
          a.issuer == b.issuer &&
          a.accountName == b.accountName);

  OtpAccount withId(OtpAccount a, String id) =>
      OtpAccount.fromJson({...a.toJson(), 'id': id});

  for (var i = 0; i < incoming.length; i++) {
    final account = incoming[i];
    final existing = working.where((a) => sameAccount(a, account)).firstOrNull;
    if (existing == null) {
      working.add(account);
      source[account.id] = i;
      added.add(account.id);
      continue;
    }
    switch (strategy) {
      case DuplicateStrategy.skip:
        skipped.add(account);
      case DuplicateStrategy.replace:
        working.remove(existing);
        if (source.remove(existing.id) == null) remove.add(existing.id);
        added.remove(existing.id);
        replaced.remove(existing.id);
        final stored = withId(account, newId());
        working.add(stored);
        source[stored.id] = i;
        replaced.add(stored.id);
      case DuplicateStrategy.keepBoth:
        final taken = working.any((a) => a.id == account.id);
        final stored = taken ? withId(account, newId()) : account;
        working.add(stored);
        source[stored.id] = i;
        added.add(stored.id);
    }
  }
  final stored = [
    for (final a in working)
      if (source.containsKey(a.id)) a,
  ];
  return (
    add: [for (final a in stored) (a, source[a.id]!)],
    remove: remove,
    report: ImportReport(
      added: List.unmodifiable(stored.where((a) => added.contains(a.id))),
      replaced: List.unmodifiable(
        stored.where((a) => replaced.contains(a.id)),
      ),
      skipped: List.unmodifiable(skipped),
    ),
  );
}
