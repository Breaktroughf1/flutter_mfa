// The browser run uses WebCrypto (ADR-0010) and is added with that backend.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:flutter_mfa_core/src/backup/backup_crypto.dart';
import 'package:flutter_mfa_core/src/backup/backup_format.dart';
import 'package:test/test.dart';

Uint8List _hex(String s) => Uint8List.fromList([
  for (var i = 0; i < s.length; i += 2)
    int.parse(s.substring(i, i + 2), radix: 16),
]);

void main() {
  // Frozen by tool/gen_backup_kat.dart and cross-checked by
  // tool/crosscheck_backup.py (05_TEST_PLAN §3.4).
  final fixture =
      jsonDecode(File('test/vectors/backup_v1.json').readAsStringSync())
          as Map<String, Object?>;
  final backup = _hex(fixture['backup']! as String);
  final passphrase = fixture['passphrase']! as String;

  test(
    'the frozen backup decrypts to the known account (FR-BAK-01 AC1)',
    () async {
      final entries = await const BackupCodec().decrypt(backup, passphrase);
      final entry = entries.single;
      expect(entry.account.id, 'f81d4fae-7dec-41d0-a765-00a0c91e6bf6');
      expect(entry.account.issuer, 'Example');
      expect(entry.account.accountName, 'alice@example.com');
      expect(entry.account.type, OtpType.totp);
      expect(entry.secret, OtpSecret.fromBase32('JBSWY3DPEHPK3PXP'));
    },
  );

  test(
    'sealing with the fixed salt and nonce reproduces the frozen bytes',
    () async {
      final entries = await const BackupCodec().decrypt(backup, passphrase);
      final createdAt = DateTime.parse(fixture['createdAt']! as String);
      expect(backupPlaintext(entries, createdAt), fixture['plaintext']);
      final sealed = await sealBackup(
        defaultBackupCrypto,
        entries: entries,
        passphrase: passphrase,
        salt: _hex(fixture['salt']! as String),
        nonce: _hex(fixture['nonce']! as String),
        iterations: fixture['iterations']! as int,
        createdAt: createdAt,
      );
      expect(sealed, backup);
    },
  );

  test('the frozen armour matches', () {
    const codec = BackupCodec();
    expect(codec.armor(backup), fixture['armored']);
    expect(codec.dearmor(fixture['armored']! as String), backup);
  });
}
