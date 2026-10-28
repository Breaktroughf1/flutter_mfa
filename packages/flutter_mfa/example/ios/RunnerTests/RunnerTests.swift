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

  func testProtectedLevelsAreRefusedNotDowngraded() throws {
    for level in [ProtectionLevelMessage.biometric, .hardwareBound] {
      XCTAssertThrowsError(try vault.write(key: "a", value: Data([1]), level: level)) { error in
        XCTAssertEqual(error as? VaultFailure, VaultFailure(code: .unsupportedOnPlatform))
      }
    }
    XCTAssertEqual(try vault.keys(), [])
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
