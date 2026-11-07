import CryptoKit
import Foundation
import LocalAuthentication
import Security

/// The protected byte map on iOS (02_ARCHITECTURE §4.1, FR-VLT-03).
///
/// Each entry is a generic-password Keychain item in this plugin's service,
/// accessible only while the device is unlocked, bound to this device
/// (`ThisDeviceOnly`: never in iCloud Keychain or encrypted backups restored
/// to another device) and never synchronizable. `kSecAttrGeneric` records the
/// format version and protection level. No value is ever logged or interpreted.
/// Immutable and backed by the thread-safe Keychain API, hence `Sendable`.
///
/// Protected levels (M3-06, ADR-0004); saving never prompts, reading does:
/// * `biometric`: the item itself has `SecAccessControl(.biometryCurrentSet)`
///   and `WhenPasscodeSetThisDeviceOnly`, so the Keychain releases the data only
///   after Face ID or Touch ID, and never again once biometrics are re-enrolled.
/// * `hardwareBound`: a per-entry Secure Enclave P-256 key with the same
///   biometric gate wraps the secret (ECIES cofactor X9.63 SHA-256 AES-GCM);
///   the item (standard access) holds `keyId(8) ‖ ciphertext`. The plaintext
///   starts with the key name, so ciphertext moved to another key is rejected.
///
/// Protected headers carry a hash of the biometric enrolment state, so a
/// re-enrolment is reported as `keyInvalidated` without showing a prompt.
final class KeychainVault: @unchecked Sendable {
  static let defaultService = "com.breaktroughf1.flutter_mfa"
  private static let formatVersion: UInt8 = 1
  private static let keyIdSize = 8
  static let algorithm = SecKeyAlgorithm.eciesEncryptionCofactorVariableIVX963SHA256AESGCM

  private let service: String
  private let keyTagPrefix: String

  init(service: String = KeychainVault.defaultService) {
    self.service = service
    self.keyTagPrefix = service + ".se."
  }

  /// Stores `value` under `key` at `level`, replacing any existing entry.
  func write(key: String, value: Data, level: ProtectionLevelMessage) throws {
    let previous = try existing(key)
    var attributes: [String: Any]
    var newKeyTag: Data?
    switch level {
    case .standard:
      attributes = [
        kSecValueData as String: value,
        kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        kSecAttrGeneric as String: Data([Self.formatVersion, UInt8(level.rawValue)]),
      ]
    case .biometric:
      let hash = try Biometry.enrolmentHash()
      var error: Unmanaged<CFError>?
      guard
        let access = SecAccessControlCreateWithFlags(
          nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .biometryCurrentSet, &error)
      else { throw VaultFailure(code: .biometricsUnavailable) }
      attributes = [
        kSecValueData as String: value,
        kSecAttrAccessControl as String: access,
        kSecAttrGeneric as String: Data([Self.formatVersion, UInt8(level.rawValue)]) + hash,
      ]
    case .hardwareBound:
      guard SecureEnclave.isAvailable else { throw VaultFailure(code: .secureEnclaveUnavailable) }
      let hash = try Biometry.enrolmentHash()
      var idBytes = [UInt8](repeating: 0, count: Self.keyIdSize)
      guard SecRandomCopyBytes(kSecRandomDefault, idBytes.count, &idBytes) == errSecSuccess else {
        throw VaultFailure(code: .storageUnavailable)
      }
      let tag = keyTag(Data(idBytes))
      let publicKey = try createEnclaveKey(tag: tag)
      newKeyTag = tag
      var error: Unmanaged<CFError>?
      guard
        let sealed = SecKeyCreateEncryptedData(
          publicKey, Self.algorithm, Self.bound(key, value) as CFData, &error) as Data?
      else {
        deleteEnclaveKey(tag: tag)
        throw VaultFailure(code: .secureEnclaveUnavailable)
      }
      attributes = [
        kSecValueData as String: id + sealed,
        kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        kSecAttrGeneric as String: Data([Self.formatVersion, UInt8(level.rawValue)]) + hash,
      ]
    }
    do {
      // An item with access control cannot be updated without authenticating,
      // so it is replaced; any other item is updated in place (atomic).
      if previous?.level == .biometric || level == .biometric {
        try delete(itemOnly: key)
        try add(key, attributes)
      } else if previous == nil {
        try add(key, attributes)
      } else {
        try Self.check(SecItemUpdate(itemQuery(key) as CFDictionary, attributes as CFDictionary))
      }
    } catch {
      if let newKeyTag { deleteEnclaveKey(tag: newKeyTag) }
      throw error
    }
    if let oldTag = previous?.keyTag { deleteEnclaveKey(tag: oldTag) }
  }

  /// The bytes under `key`, or nil if there is no entry. Protected entries
  /// show `prompt` and are released only after Face ID or Touch ID.
  func read(key: String, prompt: PromptMessage? = nil) throws -> Data? {
    guard let entry = try existing(key) else { return nil }
    switch entry.level {
    case .standard:
      return try data(key, context: nil)
    case .biometric:
      try checkEnrolment(entry)
      guard let value = try data(key, context: try Biometry.context(for: prompt)) else {
        throw VaultFailure(code: .keyInvalidated)  // the item became inaccessible
      }
      return value
    case .hardwareBound:
      try checkEnrolment(entry)
      guard let stored = try data(key, context: nil), stored.count > Self.keyIdSize,
        let tag = entry.keyTag
      else { throw VaultFailure(code: .corrupted) }
      let context = try Biometry.context(for: prompt)
      guard let privateKey = try enclaveKey(tag: tag, context: context) else {
        throw VaultFailure(code: .keyInvalidated)
      }
      var error: Unmanaged<CFError>?
      guard
        let plain = SecKeyCreateDecryptedData(
          privateKey, Self.algorithm, stored.dropFirst(Self.keyIdSize) as CFData, &error) as Data?
      else { throw VaultFailure(code: Biometry.code(keyError: error?.takeRetainedValue())) }
      return try Self.unbound(key, plain)
    }
  }

  /// Removes `key` (and the Secure Enclave key of a hardware-bound entry);
  /// absent keys are ignored.
  func delete(key: String) throws {
    let previous = try? existing(key)
    try delete(itemOnly: key)
    if let tag = previous??.keyTag { deleteEnclaveKey(tag: tag) }
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

  /// Removes every entry in this plugin's service and every Secure Enclave
  /// key it created.
  func wipe() throws {
    var query = serviceQuery()
    query[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
    let status = SecItemDelete(query as CFDictionary)
    if status != errSecItemNotFound { try Self.check(status) }
    for tag in enclaveKeyTags() { deleteEnclaveKey(tag: tag) }
  }

  // MARK: - Entries

  private struct Entry {
    let level: ProtectionLevelMessage
    let enrolment: Data?
    let keyTag: Data?
  }

  /// The header of the entry under `key`, read without authentication.
  private func existing(_ key: String) throws -> Entry? {
    var query = itemQuery(key)
    query[kSecReturnAttributes as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    let context = LAContext()
    context.interactionNotAllowed = true
    query[kSecUseAuthenticationContext as String] = context
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    try Self.check(status)
    guard let item = result as? [String: Any], let header = item[kSecAttrGeneric as String] as? Data
    else { throw VaultFailure(code: .corrupted) }
    let bytes = [UInt8](header)
    guard bytes.count >= 2, bytes[0] == Self.formatVersion,
      let level = ProtectionLevelMessage(rawValue: Int(bytes[1]))
    else { throw VaultFailure(code: .corrupted) }
    switch level {
    case .standard:
      guard bytes.count == 2 else { throw VaultFailure(code: .corrupted) }
      return Entry(level: level, enrolment: nil, keyTag: nil)
    case .biometric:
      guard bytes.count == 2 + 32 else { throw VaultFailure(code: .corrupted) }
      return Entry(level: level, enrolment: Data(bytes[2...]), keyTag: nil)
    case .hardwareBound:
      guard bytes.count == 2 + 32, let stored = try data(key, context: nil),
        stored.count > Self.keyIdSize
      else { throw VaultFailure(code: .corrupted) }
      return Entry(
        level: level, enrolment: Data(bytes[2...]),
        keyTag: keyTag(Data(stored.prefix(Self.keyIdSize))))
    }
  }

  /// A re-enrolled biometric invalidates the entry; say so before prompting.
  private func checkEnrolment(_ entry: Entry) throws {
    let current: Data
    do {
      current = try Biometry.enrolmentHash()
    } catch let failure as VaultFailure where failure.code == .biometricsNotEnrolled {
      throw VaultFailure(code: .keyInvalidated)  // every biometric was removed
    }
    if current != entry.enrolment { throw VaultFailure(code: .keyInvalidated) }
  }

  private func data(_ key: String, context: LAContext?) throws -> Data? {
    var query = itemQuery(key)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    if let context { query[kSecUseAuthenticationContext as String] = context }
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    try Self.check(status)
    guard let data = result as? Data else { throw VaultFailure(code: .corrupted) }
    return data
  }

  private func add(_ key: String, _ attributes: [String: Any]) throws {
    var item = itemQuery(key)
    for (name, value) in attributes { item[name] = value }
    try Self.check(SecItemAdd(item as CFDictionary, nil))
  }

  private func delete(itemOnly key: String) throws {
    let status = SecItemDelete(itemQuery(key) as CFDictionary)
    if status != errSecItemNotFound { try Self.check(status) }
  }

  /// `UTF-8 key length (2) ‖ key ‖ value`: binds the ciphertext to its entry.
  static func bound(_ key: String, _ value: Data) -> Data {
    let name = Data(key.utf8)
    return Data([UInt8(name.count >> 8), UInt8(name.count & 0xff)]) + name + value
  }

  /// The value of a `bound` plaintext, if it was made for `key`.
  static func unbound(_ key: String, _ plain: Data) throws -> Data {
    let bytes = [UInt8](plain)
    let name = [UInt8](key.utf8)
    guard bytes.count >= 2 else { throw VaultFailure(code: .corrupted) }
    let length = Int(bytes[0]) << 8 | Int(bytes[1])
    guard length == name.count, bytes.count >= 2 + length, Array(bytes[2..<(2 + length)]) == name
    else { throw VaultFailure(code: .corrupted) }
    return Data(bytes[(2 + length)...])
  }

  // MARK: - Secure Enclave keys

  private func keyTag(_ id: Data) -> Data {
    Data((keyTagPrefix + id.map { String(format: "%02x", $0) }.joined()).utf8)
  }

  private func createEnclaveKey(tag: Data) throws -> SecKey {
    var error: Unmanaged<CFError>?
    guard
      let access = SecAccessControlCreateWithFlags(
        nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
        [.privateKeyUsage, .biometryCurrentSet], &error)
    else { throw VaultFailure(code: .secureEnclaveUnavailable) }
    let attributes: [String: Any] = [
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecAttrKeySizeInBits as String: 256,
      kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
      kSecPrivateKeyAttrs as String: [
        kSecAttrIsPermanent as String: true,
        kSecAttrApplicationTag as String: tag,
        kSecAttrAccessControl as String: access,
      ],
    ]
    guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error),
      let publicKey = SecKeyCopyPublicKey(privateKey)
    else { throw VaultFailure(code: .secureEnclaveUnavailable) }
    return publicKey
  }

  private func enclaveKey(tag: Data, context: LAContext) throws -> SecKey? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrApplicationTag as String: tag,
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecReturnRef as String: true,
      kSecUseAuthenticationContext as String: context,
    ]
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    try Self.check(status)
    guard let result, CFGetTypeID(result) == SecKeyGetTypeID() else {
      throw VaultFailure(code: .corrupted)
    }
    return unsafeDowncast(result, to: SecKey.self)  // type checked above
  }

  private func deleteEnclaveKey(tag: Data) {
    let query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrApplicationTag as String: tag,
    ]
    SecItemDelete(query as CFDictionary)
  }

  private func enclaveKeyTags() -> [Data] {
    let query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecReturnAttributes as String: true,
      kSecMatchLimit as String: kSecMatchLimitAll,
    ]
    var result: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
      let items = result as? [[String: Any]]
    else { return [] }
    let prefix = Data(keyTagPrefix.utf8)
    return items.compactMap { $0[kSecAttrApplicationTag as String] as? Data }
      .filter { $0.starts(with: prefix) }
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
