import 'dart:convert';
import 'dart:typed_data';

import '../codec/base32.dart';
import '../errors/mfa_exception.dart';
import '../model/otp_account.dart';
import '../otp/otp_secret.dart';
import 'backup_crypto.dart';
import 'backup_entry.dart';

// Backup format v1 (02_ARCHITECTURE §7, ADR-0007). The only implementation
// of the container; BackupCodec and the known-answer tool both use it.

/// Lowest iteration count a reader accepts (ADR-0007).
const backupMinIterations = 210000;

/// Iteration count a writer uses by default (ADR-0007).
const backupDefaultIterations = 600000;

/// Highest iteration count a reader accepts, so a crafted file cannot make
/// an import run for hours.
const backupMaxIterations = 10000000;

const _magic = [0x46, 0x4D, 0x46, 0x41]; // "FMFA"
const _version = 1;
const _kdfPbkdf2Sha256 = 1;
const _saltLength = 16;
const _nonceLength = 12;
const _headerLength = 38;
const _tagLength = 16;
const _formatName = 'flutter_mfa.backup';

/// The 38-byte header, which is also the AES-GCM additional data.
Uint8List backupHeader(int iterations, Uint8List salt, Uint8List nonce) {
  final header = Uint8List(_headerLength)
    ..setAll(0, _magic)
    ..[4] = _version
    ..[5] = _kdfPbkdf2Sha256
    ..setAll(10, salt)
    ..setAll(26, nonce);
  ByteData.sublistView(header, 6, 10).setUint32(0, iterations);
  return header;
}

/// The UTF-8 JSON plaintext: one [OtpAccount.toJson] per entry plus its
/// Base32 `secret`.
String backupPlaintext(List<BackupEntry> entries, DateTime createdAt) =>
    jsonEncode({
      'format': _formatName,
      'version': _version,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'accounts': [
        for (final e in entries)
          {...e.account.toJson(), 'secret': Base32.encode(e.secret.bytes)},
      ],
    });

/// Encrypts [entries] with exactly the given parameters. Callers check the
/// passphrase policy and supply fresh random [salt] and [nonce].
Future<Uint8List> sealBackup(
  BackupCrypto crypto, {
  required List<BackupEntry> entries,
  required String passphrase,
  required Uint8List salt,
  required Uint8List nonce,
  required int iterations,
  required DateTime createdAt,
}) async {
  final header = backupHeader(iterations, salt, nonce);
  final key = await crypto.deriveKey(utf8.encode(passphrase), salt, iterations);
  final plaintext = utf8.encode(backupPlaintext(entries, createdAt));
  try {
    final sealed = await crypto.seal(key, nonce, plaintext, header);
    return Uint8List.fromList([...header, ...sealed]);
  } finally {
    key.fillRange(0, key.length, 0);
    plaintext.fillRange(0, plaintext.length, 0);
  }
}

/// Decrypts and validates [data].
///
/// Throws [BackupUnsupportedVersion] for another format version, KDF or an
/// iteration count outside [minIterations]..[backupMaxIterations] (checked
/// before any key derivation), and [BackupDecryptFailed] for everything
/// else: wrong passphrase, any modified or missing byte, or contents that
/// are not a valid v1 backup.
Future<List<BackupEntry>> openBackup(
  BackupCrypto crypto,
  Uint8List data,
  String passphrase, {
  int minIterations = backupMinIterations,
}) async {
  if (data.length < _headerLength + _tagLength) {
    throw const BackupDecryptFailed();
  }
  for (var i = 0; i < _magic.length; i++) {
    if (data[i] != _magic[i]) throw const BackupDecryptFailed();
  }
  final version = data[4];
  if (version != _version) throw BackupUnsupportedVersion(version);
  final iterations = ByteData.sublistView(data, 6, 10).getUint32(0);
  if (data[5] != _kdfPbkdf2Sha256 ||
      iterations < minIterations ||
      iterations > backupMaxIterations) {
    throw BackupUnsupportedVersion(version);
  }

  final header = Uint8List.sublistView(data, 0, _headerLength);
  final salt = Uint8List.sublistView(data, 10, 10 + _saltLength);
  final nonce = Uint8List.sublistView(data, 26, 26 + _nonceLength);
  final key = await crypto.deriveKey(utf8.encode(passphrase), salt, iterations);
  final Uint8List? plaintext;
  try {
    plaintext = await crypto.open(
      key,
      nonce,
      Uint8List.sublistView(data, _headerLength),
      header,
    );
  } finally {
    key.fillRange(0, key.length, 0);
  }
  if (plaintext == null) throw const BackupDecryptFailed();
  try {
    return _parse(plaintext);
  } finally {
    plaintext.fillRange(0, plaintext.length, 0);
  }
}

List<BackupEntry> _parse(Uint8List plaintext) {
  final Object? json;
  try {
    json = jsonDecode(utf8.decode(plaintext));
  } on FormatException {
    throw const BackupDecryptFailed();
  }
  if (json is! Map<String, Object?> || json['format'] != _formatName) {
    throw const BackupDecryptFailed();
  }
  final version = json['version'];
  if (version is! int) throw const BackupDecryptFailed();
  if (version != _version) throw BackupUnsupportedVersion(version);
  final accounts = json['accounts'];
  if (accounts is! List || json['createdAt'] is! String) {
    throw const BackupDecryptFailed();
  }
  try {
    return [
      for (final item in accounts)
        if (item
            case {'secret': final String secret} &&
                final Map<String, Object?> map)
          BackupEntry(
            account: OtpAccount.fromJson(Map.of(map)..remove('secret')),
            secret: OtpSecret.fromBase32(secret),
          )
        else
          throw const BackupDecryptFailed(),
    ];
  } on FormatException {
    throw const BackupDecryptFailed();
  } on OtpConfigException {
    throw const BackupDecryptFailed();
  }
}
