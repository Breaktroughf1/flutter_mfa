import CryptoKit
import Foundation
import LocalAuthentication
import Security

/// Biometric state and error mapping for protected entries (ADR-0004). The
/// Keychain access control or Secure Enclave key is the gate; nothing here
/// returns an "authenticated" boolean (FR-VLT-06 AC4).
enum Biometry {
  /// SHA-256 of the current biometric enrolment state. Throws the vault error
  /// that explains why biometrics cannot be used now.
  static func enrolmentHash() throws -> Data {
    let context = LAContext()
    var error: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
      throw VaultFailure(code: code(laError: error?.code))
    }
    let state: Data?
    if #available(iOS 18.0, *) {
      state = context.domainState.biometry.stateHash
    } else {
      state = context.evaluatedPolicyDomainState
    }
    guard let state else { throw VaultFailure(code: .biometricsUnavailable) }
    return Data(SHA256.hash(data: state))
  }

  /// Whether a strong biometric can be used now.
  static var available: Bool { (try? enrolmentHash()) != nil }

  /// A context that shows `prompt` when the Keychain or Secure Enclave asks.
  static func context(for prompt: PromptMessage?) throws -> LAContext {
    guard let prompt else { throw VaultFailure(code: .biometricsUnavailable) }
    let context = LAContext()
    context.localizedReason =
      prompt.subtitle.map { "\(prompt.title)\n\($0)" } ?? prompt.title
    context.localizedCancelTitle = prompt.cancelLabel
    context.localizedFallbackTitle = ""  // no passcode fallback: biometrics only
    return context
  }

  /// LocalAuthentication error code to the vault error the app sees.
  static func code(laError: Int?) -> VaultErrorCode {
    switch laError {
    case LAError.biometryNotEnrolled.rawValue: return .biometricsNotEnrolled
    case LAError.userCancel.rawValue, LAError.appCancel.rawValue,
      LAError.systemCancel.rawValue, LAError.userFallback.rawValue:
      return .userCancelled
    default: return .biometricsUnavailable
    }
  }

  /// A failed key operation (`SecKeyCreateDecryptedData`) to the vault error.
  static func code(keyError: Error?) -> VaultErrorCode {
    guard let error = keyError as NSError? else { return .corrupted }
    switch error.domain {
    case LAErrorDomain: return code(laError: error.code)
    case NSOSStatusErrorDomain where error.code == Int(errSecUserCanceled): return .userCancelled
    case NSOSStatusErrorDomain where error.code == Int(errSecAuthFailed): return .biometricsUnavailable
    default: return .corrupted
    }
  }
}
