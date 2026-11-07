import Flutter

/// iOS entry point of flutter_mfa.
///
/// The Keychain-backed vault (Pigeon host API) is added in M1-13.
public final class FlutterMfaPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {}
}
