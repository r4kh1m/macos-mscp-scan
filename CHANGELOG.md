# Changelog

All notable changes are documented here.

## [Unreleased]

## [0.3.0] - 2026-08-09

### Changed

- Make the `personal` security-posture baseline the default for personally administered
  Macs outside organizational MDM; unchanged `cis_lvl1` and `cis_lvl2` reports remain
  available explicitly.
- Split every scan into a non-privileged preparation phase and an explicit,
  user-only interactive audit phase.
- Keep scan runs and reusable dependency caches under the current user's
  `$TMPDIR/macos-mscp-scan` directory instead of redownloading every dependency
  for every run.
- Reverify the cached CPython archive before every extraction and automatically
  remove obsolete cache generations when pinned inputs change.
- Record the latest completed run in a stable per-baseline pointer file.
- Install Bundler dependencies before populating the reusable package cache.

### Added

- Add a personal profile derived from CIS Level 1 that replaces selected
  MDM/configuration-profile checks with effective local-state checks and removes
  policy-only controls. It is explicitly not a CIS Benchmark assessment.
- Record the personal profile definition, exact custom rules, and their
  SHA-256 hashes in every prepared personal report.
- Add `--clear-cache` to delete cached dependencies without deleting reports.
- Add `--prepare-only` and validated `--run-prepared RUN_DIR` interfaces.
- Add an AI-agent contract, an AI workflow, a results interpretation guide,
  interface tests, and a full preparation smoke test.
- Document the complete report contents and the disposable nature of `$TMPDIR`.

## [0.1.0] - 2026-07-29

### Added

- Read-only CIS Level 1 and Level 2 audit wrapper for NIST mSCP 2.0.
- Temporary, checksum-verified CPython 3.13 runtime and isolated dependencies.
- Audit provenance report and cleanup of mSCP runtime outputs.
- Release checksum manifest, SSH signing key, signed Git history, and feedback
  and security-reporting guidance.
