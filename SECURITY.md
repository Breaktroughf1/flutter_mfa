# Security Policy

## Supported versions
During 0.x only the latest minor release receives security fixes.

## Reporting a vulnerability
Please **do not** open a public issue.

- Preferred: [Report privately via GitHub Security Advisories](https://github.com/Breaktroughf1/flutter_mfa/security/advisories/new)
- Email: security@breaktroughf1.com  <!-- decision D6: confirm address before publishing -->

Include affected package and version, platform, impact, and reproduction steps using test vectors only — never real secrets.

## What to expect
| Step | Target |
|---|---|
| Acknowledgement | within 3 business days |
| Initial assessment | within 7 days |
| Fix for high/critical issues | within 30 days |
| Coordinated public disclosure | within 90 days of the report, or earlier once a fix is released |

Reporters are credited in the advisory and CHANGELOG unless they prefer otherwise. Affected pub.dev versions will be retracted where possible.

## Scope
In scope: all packages in this repository and the example app as a reference integration. Out of scope: vulnerabilities in apps that integrate flutter_mfa (report those to the app owner), denial of service by device owners, and attacks requiring a compromised OS beyond what `docs/04_SECURITY_DESIGN.md` claims to resist.
