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

Keep changes small and explain their security impact. Run:

```zsh
zsh -n scan_cis.zsh
zsh tests/basic.zsh
```

Also run `zsh tests/prepare-smoke.zsh` after changing preparation,
dependencies, caching, generated artifacts, or the AI/user handoff. The smoke
test prepares a real pinned mSCP run but deliberately verifies that it cannot
cross into the non-interactive `sudo` phase.

Do not add remediation behavior: the generated mSCP script may be invoked only
with `--check`. Keep `--run-prepared` as a user-only interactive action; agents
must stop after preparation as specified in [AGENTS.md](AGENTS.md).

When updating pinned upstream software, update the expected checksum and
document the source, version, validation, and compatibility impact in the pull
request and changelog.
