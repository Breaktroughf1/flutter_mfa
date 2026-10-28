import Foundation
import Security

/// The protected byte map on iOS (02_ARCHITECTURE §4.1, FR-VLT-03).
///
/// Each entry is a generic-password Keychain item in this plugin's service,
/// accessible only while the device is unlocked, bound to this device
/// (`ThisDeviceOnly`: never in iCloud Keychain or encrypted backups restored
/// to another device) and never synchronizable. `kSecAttrGeneric` records the
/// format version and protection level. No value is ever logged or interpreted.
/// Immutable and backed by the thread-safe Keychain API, hence `Sendable`.
final class KeychainVault: @unchecked Sendable {
  static let defaultService = "com.breaktroughf1.flutter_mfa"
  private static let formatVersion: UInt8 = 1

  private let service: String

  init(service: String = KeychainVault.defaultService) {
    self.service = service
  }

  /// Stores `value` under `key` at `level`, replacing any existing entry.
  func write(key: String, value: Data, level: ProtectionLevelMessage) throws {
    // Biometric and hardware-bound levels arrive in M3-06; never downgrade.
    guard level == .standard else { throw VaultFailure(code: .unsupportedOnPlatform) }
    let attributes: [String: Any] = [
      kSecValueData as String: value,
      kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
      kSecAttrGeneric as String: Data([Self.formatVersion, UInt8(level.rawValue)]),
    ]
    let query = itemQuery(key)
    let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    if status == errSecItemNotFound {
      var item = query
      for (name, value) in attributes { item[name] = value }
      try Self.check(SecItemAdd(item as CFDictionary, nil))
    } else {
      try Self.check(status)
    }
  }

  /// The bytes under `key`, or nil if there is no entry.
  func read(key: String) throws -> Data? {
    var query = itemQuery(key)
    query[kSecReturnData as String] = true
    query[kSecReturnAttributes as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    try Self.check(status)
    guard
      let item = result as? [String: Any],
      let header = item[kSecAttrGeneric as String] as? Data,
      header.count == 2,
      header[header.startIndex] == Self.formatVersion,
      header[header.startIndex + 1] == UInt8(ProtectionLevelMessage.standard.rawValue),
      let data = item[kSecValueData as String] as? Data
    else { throw VaultFailure(code: .corrupted) }
    return data
  }

  /// Removes `key`; absent keys are ignored.
  func delete(key: String) throws {
    let status = SecItemDelete(itemQuery(key) as CFDictionary)
    if status != errSecItemNotFound { try Self.check(status) }
  }

  /// All keys with an entry, sorted.
  func keys() throws -> [String] {
    var query = serviceQuery()
    query[kSecAttrSynchronizable as String] = kCFBooleanFalse
    query[kSecReturnAttributes as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitAll
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound { return [] }
    try Self.check(status)
    let items = result as? [[String: Any]] ?? []
    return items.compactMap { $0[kSecAttrAccount as String] as? String }.sorted()
  }

  /// Removes every entry in this plugin's service.
  func wipe() throws {
    var query = serviceQuery()
    query[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
    let status = SecItemDelete(query as CFDictionary)
    if status != errSecItemNotFound { try Self.check(status) }
  }

  private func serviceQuery() -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
    ]
  }

  private func itemQuery(_ key: String) -> [String: Any] {
    var query = serviceQuery()
    query[kSecAttrAccount as String] = key
    query[kSecAttrSynchronizable as String] = kCFBooleanFalse
    return query
  }

  private static func check(_ status: OSStatus) throws {
    switch status {
    case errSecSuccess: return
    case errSecItemNotFound: throw VaultFailure(code: .notFound)
    case errSecInteractionNotAllowed: throw VaultFailure(code: .deviceLocked)
    case errSecUserCanceled: throw VaultFailure(code: .userCancelled)
    default: throw VaultFailure(code: .storageUnavailable)
    }
  }
}
