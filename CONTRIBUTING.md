# Contributing and feedback

Thank you for helping make a security-audit tool clearer and more reliable.

## Where to post

- **Questions, compatibility experience, and ideas:** open a GitHub Discussion.
- **Reproducible defects:** open a GitHub Issue using the bug-report form.
- **Security vulnerabilities in this repository:** use GitHub private
  vulnerability reporting as described in [SECURITY.md](SECURITY.md), never a
  public issue.

## Useful, safe feedback

Include the script version, baseline, macOS version, CPU architecture, and the
rule identifiers that failed or behaved unexpectedly. State whether the Mac is
personally owned or managed by MDM when that affects the result.

Do not publish an unredacted audit report, `provenance.txt`, host name, user
name, serial number, IP addresses, installed-app inventory, private keys,
tokens, or passwords. Redact paths and account names before sharing terminal
output.

## Code changes

Keep changes small, explain their security impact, and test `zsh -n
scan_cis.zsh`. Do not add remediation behavior to this project: its contract is
that the generated mSCP script is invoked only with `--check`.

When updating pinned upstream software, update the expected checksum and
document the source, version, validation, and compatibility impact in the pull
request and changelog.
