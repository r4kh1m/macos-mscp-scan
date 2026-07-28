# Security policy

## Scope

Report vulnerabilities in this repository, including the shell wrapper,
release-signing process, checksum verification, and documentation that could
cause unsafe execution. Findings in NIST mSCP itself should also be reported to
the upstream project.

## Report privately

Use the repository's **Report a vulnerability** button on GitHub's Security
tab. Do not open a public issue for a suspected vulnerability or include an
unredacted audit report in a discussion.

Include a minimal reproduction, affected script version or commit, impact, and
safe proof of concept. Do not include passwords, private keys, tokens, serial
numbers, host names, or full audit output.

We aim to acknowledge reports within seven days. This is a best-effort
community project, not a support SLA.

## Supported release line

Security fixes are made against the latest tagged release and the `main`
branch. Users should upgrade to the latest release before reporting a problem.
