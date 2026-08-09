# Personal Mac Security Baseline

The `personal` report answers a different question from raw CIS:

> Does this Mac currently have the selected security protections enabled?

It is intended for personally administered Macs that are not enrolled in
organizational MDM. It does not require an MDM enrollment or claim that a user
is prevented from changing a setting later. It is derived from the mSCP CIS Level 1 rule selection, but it is not a
CIS Benchmark assessment and must not be presented as CIS compliance.

## How the profile is built

At preparation time the wrapper:

1. generates the pinned upstream `cis_lvl1` baseline for the target macOS;
2. removes policy-only rules listed in `profiles/personal/profile.yaml`;
3. copies the bundled custom rule overrides into mSCP's `custom/rules/`;
4. generates a new `personal_macos_VERSION` baseline and audit; and
5. records the profile, custom rules and their SHA-256 hashes in the report.

Raw `cis_lvl1` and `cis_lvl2` runs use fresh mSCP trees without these overrides.

## Local-state replacements

The profile currently replaces these managed-preference checks with effective
local-state checks:

| Area | Effective state used by the personal report |
| --- | --- |
| FileVault | `fdesetup status`; no `dontAllowFDEDisable` requirement |
| Gatekeeper | `spctl --status` |
| Application Firewall | `socketfilterfw --getglobalstate` |
| Firewall stealth mode | `socketfilterfw --getstealthmode` |
| Automatic login | effective `autoLoginUser` and `/etc/kcpassword` state |
| Guest account | `sysadminctl -guestAccount status` |
| Internet Sharing | whether the `InternetSharing` process is running |
| Diagnostic submission | effective `AutoSubmit` choice, without an MDM restriction |
| Screen lock | effective `sysadminctl -screenLock status` |
| Inactivity timeout | effective `pmset` display-sleep timers for every power source |
| Network time | effective `systemsetup` network-time state and server |

The complete, machine-readable list is `overridden_rules` in
`profiles/personal/profile.yaml`; the exact checks are in
`profiles/personal/rules/`.

## Policy-only exclusions

Rules are removed when their check only proves that an organization delivered
a restriction, and there is no reliable, version-stable local-state interface
that measures the same outcome. Current exclusions include:

- the MDM-enrollment requirement;
- configuration-profile-only Safari checks;
- managed restrictions for AirDrop, AirPlay Receiver, Siri, Writing Tools,
  Apple Intelligence integrations, Mail/Notes summaries and transcription;
- software-update deferral policy;
- an organization login-window banner; and
- the CIS supplemental organizational questionnaire.

An excluded rule is **not a pass**. It is outside the scope of this report. Use
a raw CIS report when central enforcement or one of these policies matters.

## Interpreting findings

For `personal`, a failed customized check means the effective local protection
was not observed at scan time. For example:

```text
FileVault is On                       -> pass
FileVault is On, no MDM enforcement   -> pass
FileVault is Off                      -> finding
```

The profile measures current state, not persistence. A later user or
administrator change can create drift. Rescan after material configuration or
macOS changes.

This remains a configuration audit. It does not enumerate listening ports,
test external reachability, inventory vulnerabilities, verify backup restores,
or provide a universal security score.
