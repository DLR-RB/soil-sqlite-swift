# Security Policy

## Supported Versions

SOIL Core in Swift is under active development. Please report any security
issue regardless of the version it was found in.

## Reporting a vulnerability

Do **not** open a public issue for a security concern. Public issues are
visible to everyone and can escalate a security problem before it has been
addressed.

Instead, report the issue [privately to the maintainers through Github](https://docs.github.com/en/code-security/how-tos/report-and-fix-vulnerabilities/report-privately), or by email to [christoph.hagen@dlr.de](mailto:christoph.hagen@dlr.de) if you have one.
When reporting, please include as much of
the following as you can — the more detail, the faster we can triage and fix:

- A clear description of the vulnerability and its impact
- Steps to reproduce, or a minimal reproduction (code, payload, or trace)
- Affected versions and the transports/encodings involved (e.g. socket
  transports, JSON/compact-JSON encodings)
- Your assessment of severity, if any (e.g. DoS, information disclosure,
  corruption of received data)
- Any suggested mitigation

We will acknowledge receipt, and keep you informed of progress. We aim to
respond as quickly as possible and to communicate a fix and disclosure timeline
once the issue is understood.

## Disclosure

When a vulnerability is confirmed, we will ship a fix in the earliest
available release, credit the reporter (unless anonymity is requested), and
update the [CHANGELOG](CHANGELOG.md) and relevant security advisories.

> This project follows [GitHub's responsible disclosure guidance](https://docs.github.com/en/code-security/concepts/vulnerability-reporting-and-management/coordinated-disclosure).
