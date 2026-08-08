# Instructions for AI agents

This repository wraps NIST mSCP as a read-only macOS compliance audit. Keep
administrator authentication and all user decisions outside the AI execution
environment.

## Required scan workflow

1. Read `README.md`, `docs/ai-workflow.md`, and `docs/results-guide.md`.
2. From the repository root, prepare the requested baseline without `sudo`:

   ```zsh
   zsh ./scan_cis.zsh --baseline cis_lvl1 --prepare-only
   ```

3. Report the exact command printed below `USER ACTION REQUIRED`, then stop.
4. The user must open their normal macOS Terminal, run that command, review the
   prompt, and enter the administrator password there. Never execute
   `--run-prepared` for the user, even if the AI environment can allocate a
   pseudo-terminal. Never request or accept a password in chat.
5. Continue only after the user says that the audit finished. Read the path in
   `${TMPDIR%/}/macos-mscp-scan/latest-cis_lvl1.txt` (or the Level 2 equivalent)
   and analyze only the report files needed for the question.

## Safety and interpretation

- Never invoke mSCP with `--fix`, `--cfc`, or any remediation option.
- Treat `finding = true` as a failed/non-compliant check and `finding = false`
  as no finding. Use the terminal report to distinguish pass from not
  applicable.
- The result list is not ordered by severity. Do not invent a severity score;
  use the rule guidance, device role, threat model, and operational impact.
- Do not upload, publish, or paste an unredacted report into an external
  service. Ask before reading files unrelated to the requested analysis.
- Do not delete prepared runs or completed reports automatically. `$TMPDIR` is
  disposable, so tell the user to copy reports they want to retain.

## Changes to this repository

Keep the wrapper read-only. Run `zsh -n scan_cis.zsh` and `zsh tests/basic.zsh`
after every script change. Run `zsh tests/prepare-smoke.zsh` when preparation,
dependencies, caching, or the handoff contract changes.
