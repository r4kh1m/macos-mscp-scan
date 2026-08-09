# macos-mscp-scan

Run a **read-only macOS security-configuration audit** with the NIST
[macOS Security Compliance Project (mSCP)](https://pages.nist.gov/macos_security/).
The default `personal` baseline is for personally administered Macs that are
not enrolled in organizational MDM. Unchanged CIS Level 1 and Level 2 reports
remain available for compliance comparison.

The repository answers: **which selected security protections are currently
enabled on this Mac?** It does not remediate settings, enumerate listening
ports, test external reachability, inventory vulnerabilities, or claim that the
`personal` profile is CIS compliant. The wrapper generates and invokes only
mSCP's `--check` mode; it never uses `--fix` or `--cfc`.

## Choose how to run

Both workflows use the same safety boundary:

1. preparation runs without `sudo` and does not inspect security settings;
2. only the user starts the read-only audit in a normal interactive Terminal;
3. the administrator password is entered only into the macOS prompt; and
4. preparation and audit results are stored under the current user's `$TMPDIR`.

### Option A — With an AI agent

1. Give the repository to an AI agent and ask it to follow `AGENTS.md`.
2. The agent reads the workflow and prepares the default profile:

   ```zsh
   zsh ./scan_cis.zsh --baseline personal --prepare-only
   ```

3. When the script prints `PREPARATION COMPLETE — USER ACTION REQUIRED`, the
   agent must stop and return the exact `--run-prepared` command.
4. Open your normal macOS Terminal, run that command, review the confirmation,
   and approve administrator authentication there.
5. Tell the agent when the audit is complete. It can locate the report through
   `latest-personal.txt` and help interpret the findings.

See the full [AI-assisted workflow](docs/ai-workflow.md), the
[results guide](docs/results-guide.md), and the agent contract in `AGENTS.md`.

### Option B — By yourself

1. From the repository root, prepare the default `personal` profile:

   ```zsh
   zsh ./scan_cis.zsh
   ```

2. Copy the one command printed below `USER ACTION REQUIRED` and run it in the
   same normal Terminal. The wrapper verifies the prepared files, asks for
   confirmation, and then lets macOS request administrator authentication.
3. Start with `report/personal_check.txt`, then open the generated HTML/PDF for
   the rationale and remediation guidance for each rule.

## Choosing a baseline

Use `personal` for a Mac that is not controlled through organizational MDM:

```zsh
zsh ./scan_cis.zsh --baseline personal --prepare-only
```

It starts from the mSCP CIS Level 1 rule selection, replaces selected
configuration-profile checks with checks of effective local state, and removes
rules whose only measurable state is an organization-delivered restriction. It
is **not** a CIS Benchmark assessment and does not claim CIS compliance. The
exact changes are documented in the
[Personal Mac Security Baseline guide](docs/personal-baseline.md).

Use the unchanged upstream baselines when the question is CIS compliance or
centrally enforced configuration:

```zsh
zsh ./scan_cis.zsh --baseline cis_lvl1 --prepare-only
zsh ./scan_cis.zsh --baseline cis_lvl2 --prepare-only
```

CIS Level 2 is stricter and can have larger usability or compatibility effects.
Test it before broad use.

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

Current source stores everything it owns under the current user's standard
macOS temporary directory, not under `~/Library`:

```text
${TMPDIR%/}/macos-mscp-scan/
├── cache/v1-…/                         # reusable, disposable dependencies
├── runs/personal.A1b2C3/report/       # one isolated prepared/completed run
├── latest-prepared-personal.txt       # run waiting for the user
└── latest-personal.txt                # latest completed run
```

The report can contain:

```text
report/
├── personal_check.txt
├── scan-output.audit.plist
├── scan-output_baseline.log
├── baseline.yaml
├── profile-definition.yaml             # personal profile policy
├── custom-rules/                        # exact local-state overrides
├── personal-customizations.sha256
├── *.html and *.pdf
├── prepared-state.txt
├── audit-completed.txt
├── provenance.txt
├── python-packages.txt
├── ruby-gems.txt
└── script.sha256
```

The profile/customization files are present only for `personal`. Each run has
a unique directory; stable pointer files remove the need to guess that name.
The cached CPython archive is checked against its pinned SHA-256 before every
extraction. pip download data and Bundler packages are reused, although every
run still gets an isolated virtual environment and gem installation. To remove
dependencies without deleting reports:

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

The latest signed release is **v0.3.0**. It includes the `personal` baseline,
the two-phase AI/user workflow, reusable dependency caches, stable report
pointers, and unchanged opt-in CIS Level 1 and Level 2 baselines.

Download and verification instructions are in the
[v0.3.0 release notes](docs/releases/v0.3.0.md). Every release publishes its
own source archive, SHA-256 manifest, detached SSH signature, and release public
key as GitHub release assets.

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
