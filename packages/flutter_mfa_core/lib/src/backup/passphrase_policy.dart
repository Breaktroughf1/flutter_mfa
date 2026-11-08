import 'common_passwords.g.dart';
import 'passphrase_check.dart';

/// The rules a backup passphrase must meet (FR-BAK-02).
///
/// The passphrase is the only thing protecting an exported backup, which
/// holds every account's secret, so the policy rejects passphrases that an
/// offline attacker would guess early. Checks run in this order:
///
/// 1. [PassphraseCheck.tooShort]: fewer than [minLength] characters (Unicode
///    code points, so emoji and other scripts count once per character).
/// 2. [PassphraseCheck.tooCommon]: the passphrase in lower case, or its
///    letters alone (digits, spaces and symbols removed, so "Password1234!"
///    reduces to "password"), is one of the [commonPasswordCount] most common
///    passwords (zxcvbn's list).
/// 3. [PassphraseCheck.lowVariety]: fewer than 6 distinct characters, or
///    shorter than 16 characters and drawn from a single class (ASCII
///    lowercase, ASCII uppercase, digits, or everything else).
///
/// Several words separated by spaces ("correct horse battery staple") pass.
/// This is a floor, not a strength meter: it does not detect keyboard
/// patterns, dates, names or l33t substitutions.
abstract final class PassphrasePolicy {
  /// Minimum length in characters.
  static const minLength = 12;

  /// Length below which a single character class is low variety.
  static const _singleClassMinLength = 16;

  /// Minimum number of distinct characters.
  static const _minDistinct = 6;

  /// Number of common passwords the policy rejects.
  static const commonPasswordCount = commonPasswordsCount;

  /// Checks [passphrase] against the policy.
  static PassphraseCheck check(String passphrase) {
    final characters = passphrase.runes.toList();
    if (characters.length < minLength) return PassphraseCheck.tooShort;

    final lower = passphrase.toLowerCase();
    final hasNonAscii = characters.any((c) => c > 0x7f);
    final letters = String.fromCharCodes(
      lower.codeUnits.where((c) => c >= 0x61 && c <= 0x7a),
    );
    if (_common.contains(lower) ||
        (!hasNonAscii && letters.length >= 4 && _common.contains(letters))) {
      return PassphraseCheck.tooCommon;
    }

    if (characters.toSet().length < _minDistinct) {
      return PassphraseCheck.lowVariety;
    }
    if (characters.length < _singleClassMinLength &&
        characters.map(_classOf).toSet().length < 2) {
      return PassphraseCheck.lowVariety;
    }
    return PassphraseCheck.ok;
  }

  static int _classOf(int c) {
    if (c >= 0x61 && c <= 0x7a) return 0; // a-z
    if (c >= 0x41 && c <= 0x5a) return 1; // A-Z
    if (c >= 0x30 && c <= 0x39) return 2; // 0-9
    return 3;
  }

  static final Set<String> _common = _decode(commonPasswordsFrontCoded);

  static Set<String> _decode(String data) {
    final words = <String>{};
    var previous = '';
    for (final line in data.split('\n')) {
      if (line.isEmpty) continue;
      final shared = line.codeUnitAt(0) - 0x61;
      previous = previous.substring(0, shared) + line.substring(1);
      words.add(previous);
    }
    return words;
  }
}
