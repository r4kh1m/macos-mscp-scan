# Changelog

All notable changes are documented here.

## [Unreleased]

## [0.4.0] - 2026-08-09

### Changed

- Exclude traditional macOS `auditd` and its dependent audit-file permission,
  ownership, ACL and retention checks from the default `personal` profile.
  These optional forensic/compliance controls remain available in unchanged
  raw CIS baselines and are reported as outside scope, not as passes.
- Treat Firewall Block All (`State = 2`) as enabled and query screen-lock state
  in the active user's context so privileged audits do not produce false
  findings for these effective local settings.
- Remove install/sudo forensic logging, global CIS password policy, fixed time
  server, authorization-database hardening, analytics contribution and
  location-menu visibility checks from the default `personal` scope.
- Exclude cross-user screen-unlock authorization from the single-user personal
  threat model and exclude mandatory user-name entry at the login window as a
  marginal privacy/usability choice. Replace App Store updates, Terminal Secure
  Keyboard Entry, Bluetooth Sharing, password hints, Remote Apple Events and
  SMB checks with effective active-user or listening-port checks.
- Replace the zero-minute CIS sudo timestamp with an effective maximum of two
  minutes in the personal profile, avoiding repeated prompts during a short
  administrative workflow while still limiting unattended credential reuse.
- Preserve upstream mSCP numeric result contracts in customized sudo,
  Bluetooth Sharing, password-hint, Remote Apple Events and SMB checks so
  effective-state passes are not misclassified as findings.

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
