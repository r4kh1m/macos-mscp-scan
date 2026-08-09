# AI-assisted workflow

The workflow has a deliberate trust boundary: an AI agent may download pinned
inputs, build the audit and prepare the guidance, but only the user may approve
and start the privileged audit.

## 1. AI preparation phase

From the repository root, the AI prepares the requested baseline. For a
personally administered Mac not enrolled in organizational MDM, use the default
`personal` profile:

```zsh
zsh ./scan_cis.zsh --baseline personal --prepare-only
```

Use `cis_lvl1` or `cis_lvl2` only when the user asks for the unchanged upstream
CIS compliance view.

Preparation does not use `sudo`, does not inspect system security settings and
does not run the audit. It creates a private, uniquely named run under:

```text
${TMPDIR%/}/macos-mscp-scan/runs/
```

The script validates pinned inputs, installs isolated dependencies, generates
the selected baseline, builds HTML/PDF guidance, hashes the generated audit
script and writes a stable pointer such as:

```text
${TMPDIR%/}/macos-mscp-scan/latest-prepared-personal.txt
```

For `personal`, the report also records the exact profile definition, custom
rules, and customization hashes. The script then prints
`USER ACTION REQUIRED` and one fully quoted command. The AI must show it to the
user and stop.

## 2. User-only audit phase

The user opens the normal macOS Terminal and runs the exact command printed by
the preparation phase. It has this form:

```zsh
zsh /absolute/path/to/scan_cis.zsh --run-prepared /private/.../runs/personal.XXXXXX
```

The wrapper verifies that the prepared run, wrapper, pinned mSCP commit and
generated audit script have not changed. It then explains the action and asks
for confirmation before macOS requests the administrator password. Only
mSCP's read-only `--check` mode is used.

Do not paste the password into an AI chat or an AI-controlled terminal. If the
command says that preparation is stale or invalid, do not bypass the check;
prepare a new run.

## 3. AI analysis phase

After the user confirms that the audit finished, the AI can locate the report
without guessing its unique directory name:

```zsh
run_dir="$(cat "${TMPDIR%/}/macos-mscp-scan/latest-personal.txt")"
```

Start with `report/personal_check.txt` and
`report/scan-output.audit.plist`, then use `report/baseline.yaml`,
`report/profile-definition.yaml`, `report/custom-rules/`, and the generated
guidance for rule details. Follow [Results guide](results-guide.md) instead of
interpreting the result order as risk priority.

Completed reports and dependency caches remain under `$TMPDIR`, which macOS may
purge. Copy a report to a user-chosen permanent directory if it must be kept.
The wrapper never stores reports in `~/Library`.
