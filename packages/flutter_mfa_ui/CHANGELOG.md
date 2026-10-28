# Changelog

All notable changes to this package are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this package uses
[Semantic Versioning](https://semver.org) (0.x: a minor bump may break).

## Unreleased

- `MfaTheme` and `MfaThemeData` (light and dark defaults meeting WCAG AA),
  with Material and Cupertino adapters in `material.dart` and `cupertino.dart`.
- `MfaLocalizations` (English, Hindi, Arabic). Widgets fall back to English
  when the delegate is not registered.
- `OtpCodeField`: one accessible text field drawn as digit boxes, with
  paste, one-time-code autofill, numeric keyboard and announced errors.
- `OtpCodeDisplay` (grouped, read digit by digit, tap to copy, hidden mode),
  `OtpCountdownRing` and `MfaStatusBadge` (icon and text).
- `OtpAccountTile` and `OtpAccountList` (driven by `MfaClient.watchAccounts()`).

## 0.1.0-dev.1

- Initial package skeleton (not yet published).
