import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:flutter_mfa_core/src/backup/backup_crypto.dart';
import 'package:flutter_mfa_core/src/backup/backup_format.dart';
import 'package:flutter_mfa_core/testing.dart';
import 'package:test/test.dart';

const _passphrase = 'correct horse battery staple';
// Low iterations keep these tests fast; the frozen 600 000-iteration known
// answer lives in backup_kat_test.dart.
const _iterations = 1000;

BackupEntry _entry({
  String name = 'alice@example.com',
  String secret = 'JBSWY3DPEHPK3PXP',
  OtpType type = OtpType.totp,
}) => BackupEntry(
  account: OtpAccount(
    id: OtpAccount.generateId(random: SeededRandom(name.length)),
    type: type,
    issuer: 'Example',
    accountName: name,
    counter: type == OtpType.hotp ? 7 : null,
    createdAt: DateTime.utc(2026, 11, 6),
  ),
  secret: OtpSecret.fromBase32(secret),
);

Future<Uint8List> _seal(
  List<BackupEntry> entries, {
  String passphrase = _passphrase,
  int iterations = _iterations,
}) => sealBackup(
  defaultBackupCrypto,
  entries: entries,
  passphrase: passphrase,
  salt: Uint8List.fromList(List.generate(16, (i) => i)),
  nonce: Uint8List.fromList(List.generate(12, (i) => i)),
  iterations: iterations,
  createdAt: DateTime.utc(2026, 11, 6, 12),
);

Future<List<BackupEntry>> _open(Uint8List data, [String p = _passphrase]) =>
    openBackup(defaultBackupCrypto, data, p, minIterations: _iterations);

void main() {
  group('format v1 (02_ARCHITECTURE §7)', () {
    test('header: magic, version, KDF, iterations, salt, nonce', () async {
      final data = await _seal([_entry()]);
      expect(ascii.decode(data.sublist(0, 4)), 'FMFA');
      expect(data[4], 1, reason: 'format version');
      expect(data[5], 1, reason: 'PBKDF2-HMAC-SHA256');
      expect(ByteData.sublistView(data, 6, 10).getUint32(0), _iterations);
      expect(data.sublist(10, 26), List.generate(16, (i) => i));
      expect(data.sublist(26, 38), List.generate(12, (i) => i));
    });

    test('round-trips TOTP and HOTP accounts with their secrets', () async {
      final entries = [
        _entry(),
        _entry(name: 'bob', secret: 'GEZDGNBVGY3TQOJQ', type: OtpType.hotp),
      ];
      final restored = await _open(await _seal(entries));
      expect(restored, hasLength(2));
      for (var i = 0; i < 2; i++) {
        expect(restored[i].account, entries[i].account);
        expect(restored[i].secret, entries[i].secret);
      }
    });

    test('the plaintext is versioned JSON with one toJson per account', () {
      final json =
          jsonDecode(backupPlaintext([_entry()], DateTime.utc(2026)))
              as Map<String, Object?>;
      expect(json['format'], 'flutter_mfa.backup');
      expect(json['version'], 1);
      expect(json['createdAt'], '2026-01-01T00:00:00.000Z');
      final account = (json['accounts']! as List).single as Map;
      expect(account['secret'], 'JBSWY3DPEHPK3PXP');
      expect(
        Map.of(account)..remove('secret'),
        _entry().account.toJson(),
      );
    });

    test('an empty backup is valid', () async {
      expect(await _open(await _seal([])), isEmpty);
    });
  });

  group('decrypt failures (FR-BAK-03 AC1)', () {
    test('a wrong passphrase is BackupDecryptFailed', () async {
      final data = await _seal([_entry()]);
      await expectLater(
        _open(data, 'another long passphrase'),
        throwsA(const BackupDecryptFailed()),
      );
    });

    test('any changed byte is BackupDecryptFailed', () async {
      final data = await _seal([_entry()]);
      // Salt, nonce, ciphertext and tag; header fields have their own errors.
      for (final i in [10, 25, 26, 37, 38, data.length ~/ 2, data.length - 1]) {
        final tampered = Uint8List.fromList(data)..[i] ^= 0x01;
        await expectLater(
          _open(tampered),
          throwsA(const BackupDecryptFailed()),
          reason: 'byte $i',
        );
      }
    });

    test('truncated or foreign data is BackupDecryptFailed', () async {
      final data = await _seal([_entry()]);
      for (final bad in [
        Uint8List(0),
        data.sublist(0, 38),
        data.sublist(0, 53),
        Uint8List.fromList([...utf8.encode('XMFA'), ...data.sublist(4)]),
      ]) {
        await expectLater(_open(bad), throwsA(const BackupDecryptFailed()));
      }
    });

    test('an unknown version or KDF is BackupUnsupportedVersion', () async {
      final data = await _seal([_entry()]);
      await expectLater(
        _open(Uint8List.fromList(data)..[4] = 2),
        throwsA(const BackupUnsupportedVersion(2)),
      );
      await expectLater(
        _open(Uint8List.fromList(data)..[5] = 2),
        throwsA(const BackupUnsupportedVersion(1)),
      );
    });

    test('iterations outside the accepted range are refused before any '
        'key derivation', () async {
      final data = await _seal([_entry()]);
      Uint8List withIterations(int n) {
        final copy = Uint8List.fromList(data);
        ByteData.sublistView(copy, 6, 10).setUint32(0, n);
        return copy;
      }

      // The production floor (ADR-0007).
      await expectLater(
        openBackup(defaultBackupCrypto, data, _passphrase),
        throwsA(const BackupUnsupportedVersion(1)),
      );
      // A crafted file must not make an import run for hours.
      await expectLater(
        _open(withIterations(backupMaxIterations + 1)),
        throwsA(const BackupUnsupportedVersion(1)),
      );
    });

    test('authenticated but malformed contents are BackupDecryptFailed', () async {
      Future<Uint8List> sealText(String text) async {
        final key = await defaultBackupCrypto.deriveKey(
          utf8.encode(_passphrase),
          Uint8List(16),
          _iterations,
        );
        final header = backupHeader(_iterations, Uint8List(16), Uint8List(12));
        final sealed = await defaultBackupCrypto.seal(
          key,
          Uint8List(12),
          Uint8List.fromList(utf8.encode(text)),
          header,
        );
        return Uint8List.fromList([...header, ...sealed]);
      }

      final account = jsonEncode(_entry().account.toJson());
      String withAccount(String extra) =>
          '{"format":"flutter_mfa.backup","version":1,"createdAt":"x",'
          '"accounts":[${account.substring(0, account.length - 1)}$extra}]}';
      for (final text in [
        'not json',
        '{"format":"flutter_mfa.backup","version":"1","accounts":[]}',
        '{"format":"flutter_mfa.backup","version":1,"accounts":[]}',
        withAccount(''),
        withAccount(',"secret":"not base32!"'),
        '[]',
        '{"format":"other","version":1,"createdAt":"2026-01-01T00:00:00Z","accounts":[]}',
        '{"format":"flutter_mfa.backup","version":1,"createdAt":"x","accounts":[{"v":1}]}',
      ]) {
        await expectLater(
          _open(await sealText(text)),
          throwsA(const BackupDecryptFailed()),
          reason: text,
        );
      }
      await expectLater(
        _open(
          await sealText(
            '{"format":"flutter_mfa.backup","version":2,"accounts":[]}',
          ),
        ),
        throwsA(const BackupUnsupportedVersion(2)),
      );
    });
  });

  group('BackupCodec', () {
    test('refuses a weak passphrase before encrypting (FR-BAK-02)', () async {
      await expectLater(
        const BackupCodec().encrypt([_entry()], 'password1234'),
        throwsA(const BackupWeakPassphrase(PassphraseCheck.tooCommon)),
      );
      await expectLater(
        const BackupCodec().encrypt([_entry()], 'short'),
        throwsA(const BackupWeakPassphrase(PassphraseCheck.tooShort)),
      );
    });

    test('uses fresh salt and nonce for every export', () async {
      const codec = BackupCodec(iterations: backupMinIterations);
      final a = await codec.encrypt([_entry()], _passphrase);
      final b = await codec.encrypt([_entry()], _passphrase);
      expect(a.sublist(10, 38), isNot(b.sublist(10, 38)));
      expect(ByteData.sublistView(a, 6, 10).getUint32(0), backupMinIterations);
      final restored = await codec.decrypt(a, _passphrase);
      expect(restored.single.secret, _entry().secret);
    });

    test('refuses to write fewer iterations than readers accept', () {
      expect(
        () => const BackupCodec(iterations: 1000).encrypt([], _passphrase),
        throwsA(isA<OtpConfigException>()),
      );
    });

    test('armour wraps base64 at 64 columns and round-trips', () async {
      const codec = BackupCodec();
      final data = Uint8List.fromList(List.generate(200, (i) => i));
      final text = codec.armor(data);
      final lines = text.trimRight().split('\n');
      expect(lines.first, '-----BEGIN FLUTTER MFA BACKUP-----');
      expect(lines.last, '-----END FLUTTER MFA BACKUP-----');
      expect(
        lines.skip(1).take(lines.length - 2).every((l) => l.length <= 64),
        isTrue,
      );
      expect(codec.dearmor(text), data);
      // Pasted text often gains CRLF line endings and surrounding spaces.
      expect(codec.dearmor('  \r\n${text.replaceAll('\n', '\r\n')}  '), data);
    });

    test('text that is not an armoured backup is BackupDecryptFailed', () {
      const codec = BackupCodec();
      for (final bad in [
        '',
        'hello',
        '-----BEGIN FLUTTER MFA BACKUP-----\n@@@\n-----END FLUTTER MFA BACKUP-----',
        '-----BEGIN FLUTTER MFA BACKUP-----\nAAAA',
      ]) {
        expect(() => codec.dearmor(bad), throwsA(const BackupDecryptFailed()));
      }
    });

    test('entries never reveal their secret in toString', () {
      final text = _entry().toString();
      expect(text, isNot(contains('JBSWY3DPEHPK3PXP')));
      expect(text, contains('alice@example.com'));
    });
  });
}
