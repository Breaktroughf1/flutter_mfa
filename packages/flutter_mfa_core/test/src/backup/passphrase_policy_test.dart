import 'package:flutter_mfa_core/flutter_mfa_core.dart';
import 'package:test/test.dart';

void main() {
  PassphraseCheck check(String p) => PassphrasePolicy.check(p);

  group('length (FR-BAK-02 AC1)', () {
    test('fewer than 12 characters is too short', () {
      expect(check(''), PassphraseCheck.tooShort);
      expect(check('Kx9!mQ2#vL7'), PassphraseCheck.tooShort, reason: '11');
      expect(check('Kx9!mQ2#vL7@'), PassphraseCheck.ok, reason: '12');
    });

    test('length counts characters, not UTF-16 code units', () {
      // 11 emoji are 22 code units but only 11 characters.
      expect(check('🔐🌍🎲🚀🧭🪐🎯🧩🛰🌋🦉'), PassphraseCheck.tooShort);
      expect(check('झरना-पहाड़-नदी-12'), PassphraseCheck.ok);
    });
  });

  group('common passwords (FR-BAK-02 AC1)', () {
    test('a listed password is too common, in any letter case', () {
      expect(check('baseball1234'), PassphraseCheck.tooCommon);
      expect(check('PASSWORD1234'), PassphraseCheck.tooCommon);
    });

    test(
      'a listed word padded with digits, spaces or symbols is too common',
      () {
        expect(check('Password1234!'), PassphraseCheck.tooCommon);
        expect(check('iloveyou 2024!!'), PassphraseCheck.tooCommon);
        expect(check('   qwerty   12'), PassphraseCheck.tooCommon);
      },
    );

    test('the list holds the top 10 000 entries of the bundled source', () {
      expect(PassphrasePolicy.commonPasswordCount, 10000);
    });
  });

  group('variety', () {
    test('few distinct characters is low variety at any length', () {
      expect(check('abababababababababab'), PassphraseCheck.lowVariety);
      expect(check('1212121212121212'), PassphraseCheck.lowVariety);
    });

    test('a short passphrase from one character class is low variety', () {
      expect(check('zqvjwxkplmhy'), PassphraseCheck.lowVariety);
      expect(check('ZQVJWXKPLMHY'), PassphraseCheck.lowVariety);
      expect(check('948372615038'), PassphraseCheck.lowVariety);
    });

    test('a long single-class passphrase is enough', () {
      expect(check('zqvjwxkplmhyrtbc'), PassphraseCheck.ok);
    });

    test('words separated by spaces pass (diceware style)', () {
      expect(check('correct horse battery staple'), PassphraseCheck.ok);
      expect(check('glacier tiramisu quorum'), PassphraseCheck.ok);
    });
  });

  test('checks run in order: length, then common list, then variety', () {
    expect(check('aaaa'), PassphraseCheck.tooShort);
    // On the list and also low variety: the list check comes first.
    expect(check('ghjcnjghjcnj'), PassphraseCheck.tooCommon);
  });
}
