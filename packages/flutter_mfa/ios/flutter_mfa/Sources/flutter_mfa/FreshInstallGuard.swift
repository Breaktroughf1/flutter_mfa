import Foundation

/// Removes vault entries left over from an earlier installation of the app.
///
/// iOS keeps Keychain items after an app is deleted, while Android deletes the
/// app's data, so without this a reinstalled app would silently regain old
/// secrets. A marker in the app's `UserDefaults` (which iOS deletes with the
/// app) records that this installation has already been checked.
///
/// Fails closed: until the leftovers are wiped, every vault operation fails
/// (for example with `deviceLocked`), so nothing written by this installation
/// can be wiped later by mistake.
final class FreshInstallGuard: @unchecked Sendable {
  static let markerKey = "com.breaktroughf1.flutter_mfa.installed.v1"

  /// One lock for the whole process: an app may run several Flutter engines,
  /// each with its own plugin instance and guard.
  private static let processLock = NSLock()

  private let vault: KeychainVault
  private let defaults: UserDefaults
  private var checked = false

  init(vault: KeychainVault, defaults: UserDefaults = .standard) {
    self.vault = vault
    self.defaults = defaults
  }

  /// Wipes leftovers once per installation; throws the vault's failure if the
  /// wipe is not possible yet.
  func ensure() throws {
    Self.processLock.lock()
    defer { Self.processLock.unlock() }
    if checked { return }
    // Re-read under the process lock: another guard may have just finished.
    if !defaults.bool(forKey: Self.markerKey) {
      try vault.wipe()
      defaults.set(true, forKey: Self.markerKey)
    }
    checked = true
  }
}
