/// A vault failure with a schema error code and no message: native errors must
/// never carry values (CLAUDE.md rule 2), and Dart maps only the code.
struct VaultFailure: Error, Equatable {
  let code: VaultErrorCode

  /// The platform error sent over the channel: the case name, which is also
  /// the Dart `VaultErrorCode` name (for example "notFound").
  var pigeonError: PigeonError {
    PigeonError(code: "\(code)", message: nil, details: nil)
  }
}
