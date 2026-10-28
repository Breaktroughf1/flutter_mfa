@TestOn('browser')
library;

import 'package:flutter_mfa/src/web/flutter_mfa_web.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

void main() {
  test('registers the web implementation without throwing', () {
    expect(
      () => FlutterMfaWeb.registerWith(webPluginRegistrar),
      returnsNormally,
    );
  });
}
