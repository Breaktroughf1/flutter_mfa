// Generates the frozen backup format v1 known-answer fixture,
// test/vectors/backup_v1.json (05_TEST_PLAN §3.4).
//
//   cd packages/flutter_mfa_core && dart run tool/gen_backup_kat.dart
//
// Run once. The fixture is then frozen: a change to it means the format
// changed. tool/crosscheck_backup.py recomputes the ciphertext with Python's
// `cryptography` so the known answer is not self-referential.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:flutter_mfa_core/src/backup/backup_crypto.dart';
import 'package:flutter_mfa_core/src/backup/backup_format.dart';

const passphrase = 'correct horse battery staple';
const iterations = 600000;
final salt = Uint8List.fromList(List.generate(16, (i) => i)); // 00..0f
final nonce = Uint8List.fromList(List.generate(12, (i) => i)); // 00..0b
final createdAt = DateTime.utc(2026, 11, 6, 12);
final entry = BackupEntry(
  account: OtpAccount(
    id: 'f81d4fae-7dec-41d0-a765-00a0c91e6bf6',
    type: OtpType.totp,
    issuer: 'Example',
    accountName: 'alice@example.com',
    createdAt: DateTime.utc(2026, 11, 6),
  ),
  secret: OtpSecret.fromBase32('JBSWY3DPEHPK3PXP'),
);

String hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

Future<void> main() async {
  final backup = await sealBackup(
    dartBackupCrypto,
    entries: [entry],
    passphrase: passphrase,
    salt: salt,
    nonce: nonce,
    iterations: iterations,
    createdAt: createdAt,
  );
  final fixture = {
    'description':
        'Backup format v1 known answer (05_TEST_PLAN §3.4). Frozen: do not '
        'regenerate unless the format version changes.',
    'passphrase': passphrase,
    'iterations': iterations,
    'salt': hex(salt),
    'nonce': hex(nonce),
    'createdAt': createdAt.toIso8601String(),
    'plaintext': backupPlaintext([entry], createdAt),
    'backup': hex(backup),
    'armored': const BackupCodec().armor(backup),
  };
  final file = File('test/vectors/backup_v1.json');
  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(fixture)}\n',
  );
  stdout.writeln('wrote ${file.path} (${backup.length} bytes of backup)');
}
