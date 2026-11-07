/// Outcome of checking a backup passphrase against the policy (FR-BAK-02).
enum PassphraseCheck {
  /// The passphrase satisfies the policy.
  ok,

  /// Shorter than the 12-character minimum.
  tooShort,

  /// Appears in the bundled list of common passwords.
  tooCommon,

  /// Long enough but with too little variety to resist guessing.
  lowVariety,
}
