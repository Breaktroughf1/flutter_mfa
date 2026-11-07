import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:flutter_mfa_core/src/backup/backup_crypto.dart';
import 'package:flutter_mfa_core/src/backup/backup_format.dart';
import 'package:test/test.dart';

Uint8List _hex(String s) => Uint8List.fromList([
  for (var i = 0; i < s.length; i += 2)
    int.parse(s.substring(i, i + 2), radix: 16),
]);

/// Reads the fixture on the VM side, so the test also runs in the browser.
Future<Map<String, Object?>> _loadFixture() async {
  final channel = spawnHybridCode('''
import 'dart:io';
import 'package:stream_channel/stream_channel.dart';
void hybridMain(StreamChannel<Object?> channel) {
  channel.sink.add(File('test/vectors/backup_v1.json').readAsStringSync());
}
''');
  return jsonDecode(await channel.stream.first as String)
      as Map<String, Object?>;
}

// 600 000 PBKDF2 rounds in pure Dart compiled to JavaScript take seconds.
const _slow = Timeout(Duration(minutes: 3));

void main() {
  // Frozen by tool/gen_backup_kat.dart and cross-checked by
  // tool/crosscheck_backup.py (05_TEST_PLAN §3.4). Every BackupCrypto must
  // reproduce it (ADR-0010): in the browser that is WebCrypto and the
  // pure-Dart reference, under dart2js and dart2wasm.
  late Map<String, Object?> fixture;
  late Uint8List backup;
  late String passphrase;
  setUpAll(() async {
    fixture = await _loadFixture();
    backup = _hex(fixture['backup']! as String);
    passphrase = fixture['passphrase']! as String;
  });

  final backends = {
    'platform default': defaultBackupCrypto,
    'pure Dart': dartBackupCrypto,
  };

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

  for (final MapEntry(key: name, value: crypto) in backends.entries) {
    test('$name: opens the frozen backup and reproduces its bytes', () async {
      final entries = await openBackup(crypto, backup, passphrase);
      final createdAt = DateTime.parse(fixture['createdAt']! as String);
      expect(backupPlaintext(entries, createdAt), fixture['plaintext']);
      final sealed = await sealBackup(
        crypto,
        entries: entries,
        passphrase: passphrase,
        salt: _hex(fixture['salt']! as String),
        nonce: _hex(fixture['nonce']! as String),
        iterations: fixture['iterations']! as int,
        createdAt: createdAt,
      );
      expect(sealed, backup);
    }, timeout: _slow);

    test('$name: a wrong passphrase or a flipped byte fails', () async {
      await expectLater(
        openBackup(crypto, backup, 'not the passphrase at all'),
        throwsA(isA<BackupDecryptFailed>()),
      );
      final tampered = Uint8List.fromList(backup);
      tampered[tampered.length - 1] ^= 1;
      await expectLater(
        openBackup(crypto, tampered, passphrase),
        throwsA(isA<BackupDecryptFailed>()),
      );
    }, timeout: _slow);
  }

  test('the frozen armour matches', () {
    const codec = BackupCodec();
    expect(codec.armor(backup), fixture['armored']);
    expect(codec.dearmor(fixture['armored']! as String), backup);
  });
}
