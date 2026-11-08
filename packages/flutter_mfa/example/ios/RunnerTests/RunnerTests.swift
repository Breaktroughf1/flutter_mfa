import CryptoKit
import LocalAuthentication
import Security
import XCTest

@testable import flutter_mfa

/// Native tests of the Keychain vault on the simulator (FR-VLT-03 AC1).
/// Uses a separate service so the app's own entries are never touched.
final class RunnerTests: XCTestCase {
  private let service = "com.breaktroughf1.flutter_mfa.tests"
  private var vault: KeychainVault!

  override func setUpWithError() throws {
    vault = KeychainVault(service: service)
    try vault.wipe()
  }

  override func tearDownWithError() throws {
    try vault.wipe()
  }

  func testRoundTripOverwriteAndDelete() throws {
    try vault.write(key: "acct_1", value: Data([1, 2, 3]), level: .standard)
    XCTAssertEqual(try vault.read(key: "acct_1"), Data([1, 2, 3]))
    try vault.write(key: "acct_1", value: Data([9]), level: .standard)
    XCTAssertEqual(try vault.read(key: "acct_1"), Data([9]))
    try vault.delete(key: "acct_1")
    XCTAssertNil(try vault.read(key: "acct_1"))
    try vault.delete(key: "acct_1")  // absent keys are ignored
  }

  func testKeysAndWipe() throws {
    try vault.write(key: "b", value: Data([1]), level: .standard)
    try vault.write(key: "__index_v1__", value: Data([1]), level: .standard)
    XCTAssertEqual(try vault.keys(), ["__index_v1__", "b"])
    try vault.wipe()
    XCTAssertEqual(try vault.keys(), [])
  }

  func testItemsAreThisDeviceOnlyAndNeverSynchronized() throws {
    try vault.write(key: "a", value: Data([1]), level: .standard)
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: "a",
      kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
      kSecReturnAttributes as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var result: CFTypeRef?
    XCTAssertEqual(SecItemCopyMatching(query as CFDictionary, &result), errSecSuccess)
    let attributes = try XCTUnwrap(result as? [String: Any])
    XCTAssertEqual(
      attributes[kSecAttrAccessible as String] as? String,
      kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
    XCTAssertNotEqual(attributes[kSecAttrSynchronizable as String] as? Bool, true)
  }

  /// The simulator has no Secure Enclave and, by default, no enrolled Face ID:
  /// protected levels fail closed with a clear code and nothing is stored.
  func testProtectedLevelsFailClosedOnTheSimulator() throws {
    if !SecureEnclave.isAvailable {
      XCTAssertThrowsError(try vault.write(key: "hw", value: Data([1]), level: .hardwareBound)) { error in
        XCTAssertEqual(error as? VaultFailure, VaultFailure(code: .secureEnclaveUnavailable))
      }
    }
    if !Biometry.available {
      XCTAssertThrowsError(try vault.write(key: "bio", value: Data([1]), level: .biometric)) { error in
        let code = (error as? VaultFailure)?.code
        XCTAssertTrue(code == .biometricsNotEnrolled || code == .biometricsUnavailable)
      }
    }
    XCTAssertEqual(try vault.keys(), [])
  }

  func testCapabilitiesOfferOnlyWhatTheDeviceCanProvide() {
    XCTAssertEqual(FlutterMfaPlugin.supportedLevels(biometry: false, enclave: true), [.standard])
    XCTAssertEqual(FlutterMfaPlugin.supportedLevels(biometry: true, enclave: false), [.standard, .biometric])
    XCTAssertEqual(
      FlutterMfaPlugin.supportedLevels(biometry: true, enclave: true), [.standard, .biometric, .hardwareBound])
  }

  func testHardwareBoundPlaintextIsBoundToItsKey() throws {
    let bound = try KeychainVault.bound("acct_a", Data([9, 8]))
    XCTAssertEqual(try KeychainVault.unbound("acct_a", bound), Data([9, 8]))
    for (key, data) in [("acct_b", bound), ("acct_a", Data([0])), ("acct_a", Data([0, 9, 1]))] {
      XCTAssertThrowsError(try KeychainVault.unbound(key, data)) { error in
        XCTAssertEqual(error as? VaultFailure, VaultFailure(code: .corrupted))
      }
    }
    let tooLong = String(repeating: "x", count: 121)
    for invalid in ["", tooLong] {
      XCTAssertThrowsError(try KeychainVault.bound(invalid, Data([1]))) { error in
        XCTAssertEqual(error as? VaultFailure, VaultFailure(code: .corrupted))
      }
      XCTAssertThrowsError(try vault.write(key: invalid, value: Data([1]), level: .standard)) { error in
        XCTAssertEqual(error as? VaultFailure, VaultFailure(code: .corrupted))
      }
      XCTAssertThrowsError(try vault.read(key: invalid)) { error in
        XCTAssertEqual(error as? VaultFailure, VaultFailure(code: .corrupted))
      }
    }
  }

  func testBiometricErrorsMapToVaultErrors() {
    XCTAssertEqual(Biometry.code(laError: LAError.biometryNotEnrolled.rawValue), .biometricsNotEnrolled)
    for code in [LAError.userCancel, .appCancel, .systemCancel, .userFallback] {
      XCTAssertEqual(Biometry.code(laError: code.rawValue), .userCancelled)
    }
    XCTAssertEqual(Biometry.code(laError: LAError.biometryLockout.rawValue), .biometricsUnavailable)
    XCTAssertEqual(
      Biometry.code(keyError: NSError(domain: NSOSStatusErrorDomain, code: Int(errSecUserCanceled))),
      .userCancelled)
    XCTAssertEqual(Biometry.code(keyError: NSError(domain: "other", code: 1)), .corrupted)
  }

  func testAProtectedHeaderOfTheWrongShapeIsCorrupted() throws {
    // A standard item relabelled as biometric without the enrolment hash.
    try vault.write(key: "a", value: Data([1]), level: .standard)
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: "a",
    ]
    let update: [String: Any] = [kSecAttrGeneric as String: Data([1, 1])]
    XCTAssertEqual(SecItemUpdate(query as CFDictionary, update as CFDictionary), errSecSuccess)
    XCTAssertThrowsError(try vault.read(key: "a")) { error in
      XCTAssertEqual(error as? VaultFailure, VaultFailure(code: .corrupted))
    }
  }

  func testErrorCodesUseTheDartEnumNames() {
    XCTAssertEqual(VaultFailure(code: .notFound).pigeonError.code, "notFound")
    XCTAssertEqual(VaultFailure(code: .hostActivityNotFragmentActivity).pigeonError.code, "hostActivityNotFragmentActivity")
    XCTAssertNil(VaultFailure(code: .corrupted).pigeonError.message)
  }

  func testLeftoversFromAnEarlierInstallAreWipedOnce() throws {
    let suite = "com.breaktroughf1.flutter_mfa.tests.defaults"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defaults.removePersistentDomain(forName: suite)
    defer { defaults.removePersistentDomain(forName: suite) }

    try vault.write(key: "old", value: Data([1]), level: .standard)
    let guardOne = FreshInstallGuard(vault: vault, defaults: defaults)
    try guardOne.ensure()
    XCTAssertEqual(try vault.keys(), [], "leftover from the earlier install is wiped")
    XCTAssertTrue(defaults.bool(forKey: FreshInstallGuard.markerKey))

    try vault.write(key: "new", value: Data([2]), level: .standard)
    try guardOne.ensure()
    try FreshInstallGuard(vault: vault, defaults: defaults).ensure()
    XCTAssertEqual(try vault.keys(), ["new"], "this installation's data is never wiped")
  }
}
