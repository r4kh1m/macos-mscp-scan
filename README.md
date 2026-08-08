# macos-mscp-scan

Run a **read-only** CIS security audit with the NIST
[macOS Security Compliance Project (mSCP)](https://pages.nist.gov/macos_security/).
The wrapper generates and invokes only mSCP's `--check` mode; it never uses
`--fix` or `--cfc`.

## AI-assisted quick start (current source)

Give the repository to an AI agent and ask it to follow `AGENTS.md`. The agent
may prepare the scan without administrator access:

```zsh
zsh ./scan_cis.zsh --baseline cis_lvl1 --prepare-only
```

When preparation finishes, the script prints:

```text
PREPARATION COMPLETE — USER ACTION REQUIRED
```

The AI must stop and show the exact `--run-prepared` command. Open your normal
macOS Terminal and run that command yourself. Review the confirmation prompt
and enter the administrator password only there. After the audit finishes, the
AI can find the report through the stable `latest-cis_lvl1.txt` pointer and
help interpret it.

The separation is enforced by the interface: preparation is always the default
phase, while the audit starts only with an explicit `--run-prepared RUN_DIR` in
an interactive terminal. See the [AI-assisted workflow](docs/ai-workflow.md)
and [results guide](docs/results-guide.md).

## Run without an AI

The same two phases apply. First prepare Level 1 (the default):

```zsh
zsh ./scan_cis.zsh --baseline cis_lvl1
```

Then copy the one command printed under `USER ACTION REQUIRED` into your normal
Terminal. The second phase checks the prepared files, asks for confirmation,
then lets macOS request administrator authentication.

Use `cis_lvl2` only after testing its stricter controls:

```zsh
zsh ./scan_cis.zsh --baseline cis_lvl2 --prepare-only
```

## Requirements

- macOS 14 Sonoma, 15 Sequoia, or 26 Tahoe;
- Apple Silicon or Intel Mac;
- an administrator account for the separate audit phase;
- bundled macOS command-line tools plus `git`, system `ruby`, and `gem`;
- HTTPS access to GitHub, PyPI, and RubyGems; and
- about 1 GB free on the volume backing `$TMPDIR`.

Python, pip packages, Bundler and Ruby gems are isolated under the temporary
run/cache directories. Nothing is installed in system or user gem locations.

## Reports and cache

Current source stores everything it owns under the current user's macOS
temporary directory, not under `~/Library`:

```text
${TMPDIR%/}/macos-mscp-scan/
├── cache/v1-…/                         # reusable, disposable dependencies
├── runs/cis_lvl1.A1b2C3/report/        # one isolated prepared/completed run
├── latest-prepared-cis_lvl1.txt        # run waiting for the user
└── latest-cis_lvl1.txt                 # latest completed run
```

The report can contain:

```text
report/
├── cis_lvl1_check.txt
├── scan-output.audit.plist
├── scan-output_baseline.log
├── baseline.yaml
├── *.html and *.pdf
├── prepared-state.txt
├── audit-completed.txt
├── provenance.txt
├── python-packages.txt
├── ruby-gems.txt
└── script.sha256
```

Each run has a unique directory; stable pointer files remove the need to guess
that name. The cached CPython archive is checked against its pinned SHA-256
before every extraction. pip download data and Bundler packages are reused,
although every run still gets an isolated virtual environment and gem
installation. To remove dependencies without deleting reports:

```zsh
zsh ./scan_cis.zsh --clear-cache
```

`$TMPDIR` is deliberately disposable: macOS may purge it after a restart,
during maintenance, or under storage pressure. Copy any report you need to
retain to a permanent location you choose. Do not post an unredacted report.

## What changes on the Mac?

Preparation does not use `sudo` and does not inspect system security settings.
The user-only audit reads configuration with `sudo`; it does not remediate it.
mSCP temporarily writes a plist under `/Library/Preferences` and a log under
`/Library/Logs`. The wrapper copies current results into the private report,
then restores the pre-scan files or removes files created by the run.

macOS still records normal events such as `sudo` authentication and process
execution. Those system records are intentionally left intact.

## Signed stable release

The latest signed release is **v0.1.0**. It predates the two-phase workflow and
temporary dependency cache: its single command prepares and immediately runs
the audit, and its report layout differs from current source. Download and
verify it with the complete block in [v0.1.0 release notes](docs/releases/v0.1.0.md).

The root `SHA256SUMS`, `SHA256SUMS.sig`, and release public key attest the
v0.1.0 release artifact only. They do not attest an edited development
worktree. A future release must publish a new manifest and signature.

## Trust, support and development

The wrapper pins the mSCP commit and portable CPython archive; every run records
its inputs in `provenance.txt`. See [Compatibility](docs/compatibility.md) for
the tested matrix.

Questions belong in
[GitHub Discussions](https://github.com/r4kh1m/macos-mscp-scan/discussions),
reproducible bugs in
[GitHub Issues](https://github.com/r4kh1m/macos-mscp-scan/issues), and security
reports follow [SECURITY.md](SECURITY.md). Development guidance is in
[CONTRIBUTING.md](CONTRIBUTING.md). The repository uses the [MIT License](LICENSE).
