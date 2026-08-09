# Interpreting scan results

The selected baseline determines the question the audit answers:

- `personal`: which selected protections are effectively enabled on this Mac
  without requiring organization-delivered enforcement;
- `cis_lvl1` or `cis_lvl2`: which unchanged CIS compliance checks found a
  non-compliant condition.

Neither report is a vulnerability scanner, universal risk score, or
automatically prioritized remediation plan. The personal profile is not a CIS
Benchmark assessment. Read its [scope and exclusions](personal-baseline.md).

## Result meanings

The structured `scan-output.audit.plist` maps rule identifiers to a `finding`
boolean:

- `finding = true` means the check found a non-compliant condition;
- `finding = false` means the check did not find one.

Some rules that are not applicable to the current architecture can also be
stored as `false`. Use `*_check.txt` to distinguish an explicit pass from
`N/A`, an execution error, or a check that requires manual review. Do not count
every `false` value as an independently verified pass.

The plist is a flat result set. Its order and rule number do not indicate
severity, exploitability, urgency, or remediation cost.

For the personal profile, excluded organization-policy, forensic logging,
global password-policy and privacy-choice rules are outside scope. They do not
appear in the plist and must not be counted as passes. Use a raw CIS baseline
when those controls are part of the question being assessed.

## Which files to use

| File | Purpose |
| --- | --- |
| `*_check.txt` | Human-readable run output; start here for pass, fail, N/A and errors. |
| `scan-output.audit.plist` | Structured per-rule findings for filtering and counting. |
| `baseline.yaml` | Exact rule selection used for this run. |
| `profile-definition.yaml` | Personal exclusions and override inventory. |
| `custom-rules/*.yaml` | Exact local-state checks used by `personal`. |
| `*.html` / `*.pdf` | Rule rationale, check, remediation, impact and references. |
| `provenance.txt` | macOS, wrapper, mSCP and dependency provenance. |
| `audit-completed.txt` | Completion time and audit process exit status. |
| `scan-output_baseline.log` | Detailed mSCP runtime log when generated. |

The profile/customization files are present only for `personal`. If
`audit-completed.txt` is absent, do not treat the run as completed. A non-zero
`audit_exit_status` or errors in the terminal/log output must be resolved before
using pass/fail totals.

## A practical triage order

1. Validate the run: check completion status, errors, `N/A` and manual checks.
2. For each `finding = true`, search the exact rule identifier in the generated
   guidance and read its rationale, remediation and impact.
3. Establish context: personal or MDM-managed Mac, device role, exposed
   services, data sensitivity, compensating controls and business constraints.
4. Prioritize high-impact boundaries first when they apply—for example disk
   encryption, OS security protections and updates, firewall/exposed services,
   remote access/sharing, privileged accounts and authentication controls.
   This is a triage heuristic, not an mSCP or CIS severity score.
5. Pilot one change at a time, record exceptions, and rescan. Prefer the
   organization's MDM/configuration process on managed Macs.

Run raw CIS when enforcement matters. For example, personal FileVault passes
when `fdesetup status` reports that encryption is on; raw CIS may still report a
finding when `dontAllowFDEDisable` is not centrally enforced. Both results are
correct for their different questions.

This repository intentionally does not automate remediation.

## Privacy

Reports can reveal account names, paths, installed software and security
configuration. Keep the report directory private. Before sharing excerpts,
remove host names, user names, serial numbers, IP addresses, application
inventory, tokens and other identifiers. Never publish the full unredacted
report in a GitHub issue or send it to an external AI service without explicit
authorization.
