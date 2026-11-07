import 'package:flutter_mfa/flutter_mfa.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the silent logger discards messages', () {
    const SilentMfaLogger().log(MfaLogLevel.error, 'x');
  });
}
