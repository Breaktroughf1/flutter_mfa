# ADR-0012: iOS wipes vault leftovers on the first launch after a reinstall

- Status: Accepted (28 October 2026, M1 checkpoint)

## Context
iOS keeps Keychain items after an app is deleted; Android deletes the app's data. Without handling this, reinstalling an iOS app silently restores the previous installation's secrets, which surprises users who uninstall an authenticator to get rid of its accounts, and which the threat model does not expect (for example a device handed to someone else after the app was deleted).

## Decision
- A marker in the app's `UserDefaults` (deleted by iOS with the app) records that the current installation has been checked. Before the first vault operation of each process, if the marker is missing, every entry in the plugin's Keychain service is wiped and the marker is set.
- Fail closed: if the wipe cannot run yet (for example the device is locked), the vault operation fails and nothing is written, so a later launch can never wipe data this installation stored.
- Restoring an encrypted backup to the same device brings back both the marker and the `ThisDeviceOnly` items, so they stay consistent; restoring to another device brings back neither the items nor anything to wipe.

## Consequences
+ Same lifecycle on Android and iOS: uninstall removes the accounts.
− Users who reinstall lose their accounts unless they have an encrypted backup (M3), which matches Android; the README and the backup docs must say so.
