import Flutter
import LocalAuthentication
import UIKit

/// iOS entry point of flutter_mfa: a thin byte vault behind the Pigeon
/// `MfaHostApi`. No OTP logic, JSON or validation lives here (CLAUDE.md rule 1).
public final class FlutterMfaPlugin: NSObject, FlutterPlugin, MfaHostApi {
  private let vault = KeychainVault()

  public static func register(with registrar: FlutterPluginRegistrar) {
    MfaHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: FlutterMfaPlugin())
  }

  func capabilities() throws -> CapabilitiesMessage {
    #if targetEnvironment(simulator)
      let hardware = false
    #else
      let hardware = true
    #endif
    return CapabilitiesMessage(
      hardwareBacked: hardware,
      strongBox: false,
      secureEnclave: hardware,
      biometricsEnrolled: LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil),
      persistentStorage: true,
      screenCaptureProtection: false,
      // Biometric and hardware-bound levels arrive in M3-06 (fail closed until then).
      supportedLevels: [.standard]
    )
  }

  func write(key: String, value: FlutterStandardTypedData, level: ProtectionLevelMessage) async throws {
    try mapped { try vault.write(key: key, value: value.data, level: level) }
  }

  func read(key: String, prompt: PromptMessage?) async throws -> FlutterStandardTypedData? {
    try mapped { try vault.read(key: key).map { FlutterStandardTypedData(bytes: $0) } }
  }

  func delete(key: String) throws {
    try mapped { try vault.delete(key: key) }
  }

  func keys() throws -> [String] {
    try mapped { try vault.keys() }
  }

  func wipe() throws {
    try mapped { try vault.wipe() }
  }

  func copySensitive(text: String, expiryMillis: Int64) throws {
    // Local only (never Universal Clipboard) and removed by the system at expiry.
    UIPasteboard.general.setItems(
      [["public.utf8-plain-text": text]],
      options: [
        .localOnly: true,
        .expirationDate: Date().addingTimeInterval(Double(max(expiryMillis, 0)) / 1000),
      ]
    )
  }

  func setScreenCaptureProtection(enabled: Bool) throws {
    // iOS cannot block screenshots; reported via capabilities (FR-FAC-06).
  }

  private func mapped<T>(_ body: () throws -> T) throws -> T {
    do {
      return try body()
    } catch let failure as VaultFailure {
      throw failure.pigeonError
    }
  }
}
