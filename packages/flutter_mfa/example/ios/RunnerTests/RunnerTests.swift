import XCTest

@testable import flutter_mfa

/// Native XCTests for flutter_mfa. Vault tests are added in M1-13.
final class RunnerTests: XCTestCase {
  func testPluginClassIsAvailable() {
    XCTAssertNotNil(FlutterMfaPlugin())
  }
}
