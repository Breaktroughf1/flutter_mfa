import 'package:flutter_mfa_platform_interface/flutter_mfa_platform_interface.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'browser_web_store.dart';
import 'web_vault.dart';

/// Web registration entry point for flutter_mfa.
final class FlutterMfaWeb {
  FlutterMfaWeb._();

  /// Called by the Flutter tool to make the WebCrypto + IndexedDB vault the
  /// platform implementation (FR-VLT-04).
  static void registerWith(Registrar registrar) {
    MfaPlatform.instance = WebVault(BrowserWebStore());
  }
}
