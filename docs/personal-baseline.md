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
2. removes out-of-scope rules listed in `profiles/personal/profile.yaml`;
3. copies the bundled custom rule overrides into mSCP's `custom/rules/`;
4. generates a new `personal_macos_VERSION` baseline and audit; and
5. records the profile, custom rules and their SHA-256 hashes in the report.

Raw `cis_lvl1` and `cis_lvl2` runs use fresh mSCP trees without these overrides.

## Local-state replacements

The profile currently replaces these upstream checks with effective local-state
checks:

| Area | Effective state used by the personal report |
| --- | --- |
| FileVault | `fdesetup status`; no `dontAllowFDEDisable` requirement |
| Gatekeeper | `spctl --status` |
| App Store updates | active user's automatic-update preference; unset retains the enabled default |
| Sudo credential cache | effective authentication timeout; values from zero through two minutes pass |
| Terminal input | active user's Secure Keyboard Entry preference |
| Application Firewall | `socketfilterfw --getglobalstate`; enabled and Block All states pass |
| Firewall stealth mode | `socketfilterfw --getstealthmode` |
| Automatic login | effective `autoLoginUser` and `/etc/kcpassword` state |
| Guest account | `sysadminctl -guestAccount status` |
| Internet Sharing | whether the `InternetSharing` process is running |
| Bluetooth Sharing | active user's effective sharing preference; unset is off |
| Remote Apple Events | whether TCP port 3031 has a listener |
| SMB File Sharing | whether TCP ports 139 or 445 have a listener |
| Diagnostic submission | effective `AutoSubmit` choice, without an MDM restriction |
| Password hints | effective `RetriesUntilHint`; unset is off |
| Screen lock | active user's effective `sysadminctl -screenLock status` |
| Inactivity timeout | effective `pmset` display-sleep timers for every power source |
| Network time | whether automatic network time is effectively enabled |

The complete, machine-readable list is `overridden_rules` in
`profiles/personal/profile.yaml`; the exact checks are in
`profiles/personal/rules/`.

## Out-of-scope exclusions

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

The default profile also excludes controls that do not answer its current-state
security question:

- traditional macOS BSM `auditd`, install-log retention and explicit sudo
  logging, which provide a forensic or compliance trail but are not preventive
  security boundaries;
- global CIS password-policy enforcement, which does not measure the strength
  of the current local password and includes rotation/history requirements that
  are not appropriate as universal personal-device guidance;
- a fixed organization time server and authorization-database hardening for
  system preference panes; and
- optional analytics contribution and location-menu visibility preferences,
  which are privacy choices rather than core protective controls.

The profile also excludes the cross-user screen-unlock authorization rule. It
addresses a multi-user administrator scenario rather than the default
single-user personal Mac threat model.

Requiring a login window with separate user-name and password fields is also
outside the default scope. Hiding the account list provides only marginal
account-name privacy on a single-user Mac while requiring the user name at
every login; users can still choose that stricter interface as a preference.

`auditd` is not enabled by default on macOS 14 and later. A future opt-in
forensic or privacy profile can add the relevant groups back for users who need
them.

An excluded rule is **not a pass**. It is outside the scope of this report. Use
a raw CIS report when central enforcement, formal compliance or forensic audit
logging matters.

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
