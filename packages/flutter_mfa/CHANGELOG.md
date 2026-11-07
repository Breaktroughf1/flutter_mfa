# Changelog

All notable changes to this package are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this package uses
[Semantic Versioning](https://semver.org) (0.x: a minor bump may break).

## Unreleased

- iOS: the vault is wiped on the first launch after an install, so a
  reinstalled app does not regain an earlier installation's accounts
  (ADR-0012). **Upgrade note:** builds taken from git before this change
  have no install marker, so their first launch on this version also wipes
  the vault. No published version is affected; the first release ships
  with the marker.

## 0.1.0-dev.1

- Initial package skeleton (not yet published).
