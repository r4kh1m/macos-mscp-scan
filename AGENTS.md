# Instructions for AI agents

This repository wraps NIST mSCP as a read-only macOS security and compliance
audit. Keep administrator authentication and all user decisions outside the AI
execution environment.

## Required scan workflow

1. Read `README.md`, `docs/ai-workflow.md`, `docs/results-guide.md`, and, for
   `personal`, `docs/personal-baseline.md`.
2. From the repository root, prepare the requested baseline without `sudo`.
   Use `personal` when no baseline is requested:

   ```zsh
   zsh ./scan_cis.zsh --baseline personal --prepare-only
   ```

   Raw `cis_lvl1` and `cis_lvl2` are available only when the user wants an
   unchanged CIS compliance comparison.
3. Report the exact command printed below `USER ACTION REQUIRED`, then stop.
4. The user must open their normal macOS Terminal, run that command, review the
   prompt, and enter the administrator password there. Never execute
   `--run-prepared` for the user, even if the AI environment can allocate a
   pseudo-terminal. Never request or accept a password in chat.
5. Continue only after the user says that the audit finished. Read the path in
   `${TMPDIR%/}/macos-mscp-scan/latest-BASELINE.txt` and analyze only the report
   files needed for the question.

## Safety and interpretation

- Never invoke mSCP with `--fix`, `--cfc`, or any remediation option.
- Treat `finding = true` as a failed/non-compliant check and `finding = false`
  as no finding. Use the terminal report to distinguish pass from not
  applicable.
- The result list is not ordered by severity. Do not invent a severity score;
  use the rule guidance, device role, threat model, and operational impact.
- Do not describe `personal` as CIS-compliant. Its organization-policy and
  optional forensic-logging exclusions are outside scope, not passes. Use raw
  `cis_lvl1` or `cis_lvl2` for CIS questions.
- Do not upload, publish, or paste an unredacted report into an external
  service. Ask before reading files unrelated to the requested analysis.
- Do not delete prepared runs or completed reports automatically. `$TMPDIR` is
  disposable, so tell the user to copy reports they want to retain.

## Changes to this repository

Keep the wrapper read-only. Run `zsh -n scan_cis.zsh` and
`zsh tests/basic.zsh` after every script change. Run
`zsh tests/prepare-smoke.zsh` when preparation, profiles, custom rules,
dependencies, caching, or the handoff contract changes.
