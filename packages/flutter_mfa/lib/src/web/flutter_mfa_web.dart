import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// Web registration entry point for flutter_mfa.
///
/// The WebCrypto + IndexedDB vault is implemented in M1-14.
final class FlutterMfaWeb {
  FlutterMfaWeb._();

  /// Called by the Flutter tool to register the web implementation.
  static void registerWith(Registrar registrar) {}
}
