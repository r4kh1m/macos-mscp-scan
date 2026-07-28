# macos-cis-scan

Run a **read-only** CIS security audit with the NIST
[macOS Security Compliance Project (mSCP)](https://pages.nist.gov/macos_security/).
The generated mSCP audit runs only with `--check`, never `--fix` or
`--cfc`.

## Run a CIS Level 1 check

Copy this entire block into a terminal. It downloads and verifies release
`v0.1.0` in `/tmp`, runs the audit, then removes only the downloaded release
files. The report remains in a separate `/tmp/mscp_…` directory so you can
read it.

```zsh
(
  set -e
  work_dir="$(mktemp -d /tmp/macos-cis-scan-v0.1.0.XXXXXX)"
  trap 'rm -rf "$work_dir"' EXIT
  cd "$work_dir"

  curl -fLO https://github.com/r4kh1m/macos-cis-scan/releases/download/v0.1.0/scan_cis.zsh
  curl -fLO https://github.com/r4kh1m/macos-cis-scan/releases/download/v0.1.0/SHA256SUMS
  curl -fLO https://github.com/r4kh1m/macos-cis-scan/releases/download/v0.1.0/SHA256SUMS.sig
  curl -fLO https://github.com/r4kh1m/macos-cis-scan/releases/download/v0.1.0/r4kh1m-release-signing-key.pub

  shasum -a 256 -c SHA256SUMS
  {
    printf 'r4kh1m-release namespaces="file" '
    cat r4kh1m-release-signing-key.pub
  } > allowed_signers
  ssh-keygen -Y verify -f allowed_signers -I r4kh1m-release -n file -s SHA256SUMS.sig < SHA256SUMS

  # Change cis_lvl1 to cis_lvl2 only after a pilot.
  zsh scan_cis.zsh --baseline cis_lvl1
)
```

The block stops if a download or verification fails. The parentheses run it in
a separate shell, so its cleanup does not affect your terminal.

## Before you run

- macOS 14 Sonoma, 15 Sequoia, or 26 Tahoe; macOS 13 and earlier are not
  supported by this release;
- an administrator account;
- bundled `zsh`, `curl`, `tar`, `shasum`, and `ssh-keygen`;
- `git`, and the system `ruby` and `gem` commands;
- HTTPS access to GitHub, PyPI, and RubyGems; and
- about 1 GB free on the volume backing `/tmp`.

You do not need to install Python, pip, a virtual environment, Bundler, or Ruby
gems in advance. The script puts them in its temporary run directory. It uses
the system Ruby interpreter without installing packages into system or user gem
directories.

## Baselines

- `cis_lvl1` — default; a practical starting point for a personal or standard
  work Mac.
- `cis_lvl2` — substantially stricter; pilot it before broad use.

## Find and delete the report

At the end, the script prints a directory such as:

```text
/tmp/mscp-cis_lvl1.A1b2C3
```

Inside it:

```text
report/
├── cis_lvl1_check.txt  # main report: passed and failed rules
└── provenance.txt      # versions, hashes, and the mSCP commit used
```

Read or copy what you need, then delete the **exact path printed by your run**:

```zsh
rm -rf /tmp/mscp-cis_lvl1.A1b2C3
```

## What changes on the Mac?

The audit reads configuration with `sudo`; it does not remediate settings.
During the audit, mSCP temporarily writes one plist under
`/Library/Preferences` and one log under `/Library/Logs`. The wrapper
restores existing files or removes ones created by the run before it exits.

macOS still records normal system events such as `sudo` authentication and
process execution. Those records are intentionally left intact.

## Trust and support

The command verifies the release SHA-256 manifest and its detached SSH
signature before the audit runs. The script pins the mSCP commit and verifies
the portable Python archive it downloads; `provenance.txt` records those
inputs for the completed run.

Questions and compatibility reports belong in
[GitHub Discussions](https://github.com/r4kh1m/macos-cis-scan/discussions).
For reproducible bugs, use [GitHub Issues](https://github.com/r4kh1m/macos-cis-scan/issues).
Do not post an unredacted report publicly. For a vulnerability in this wrapper,
follow [SECURITY.md](SECURITY.md).

The wrapper and its documentation are released under the [MIT License](LICENSE).
