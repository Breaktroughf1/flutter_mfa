import 'package:meta/meta.dart';

import '../model/otp_account.dart';
import '../otp/otp_secret.dart';

/// One account and its secret, as stored in an encrypted backup.
///
/// [toString] shows the account but never the secret.
@immutable
final class BackupEntry {
  /// Pairs [account] with its [secret].
  const BackupEntry({required this.account, required this.secret});

  /// The account's metadata.
  final OtpAccount account;

  /// The shared secret.
  final OtpSecret secret;

  @override
  String toString() => 'BackupEntry(${account.displayName}, $secret)';
}
