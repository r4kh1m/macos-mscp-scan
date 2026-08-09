# Compatibility

`macos-mscp-scan` version 0.1.0 and the current development version pin mSCP 2.0
commit `5b3d76a532d8a0ddb34d9c5dcb7fa8e191bc40be`. Its macOS rule library
contains targets for macOS 14.0, 15.0, and 26.0 only.

| macOS version | Tool behavior | Validation status |
| --- | --- | --- |
| 26 Tahoe | Supported | CIS end-to-end audit; personal generation and script validation on Apple Silicon |
| 15 Sequoia | Supported | Personal generation and script validation; community audit validation requested |
| 14 Sonoma | Supported | Personal generation and script validation; community audit validation requested |
| 13 Ventura and earlier | Rejected before downloads | Requires a separate mSCP 1.0 workflow |

The script supports `arm64` and `x86_64` portable CPython archives. It does not
claim that every individual CIS rule applies unchanged to every hardware, MDM,
or organisational configuration.

The `personal` profile is derived from the matching CIS Level 1 rule selection
for each supported OS. Its custom rules use macOS command interfaces available
on all three targets, but an end-to-end privileged audit still needs community
validation on macOS 14 and 15. The profile is not a CIS Benchmark assessment.

Please report successful and unsuccessful runs in GitHub Discussions with the
baseline, macOS version, architecture, and sanitized rule identifiers.

The two-phase preparation path is exercised by the repository smoke test. An
end-to-end audit still requires a user-controlled interactive Terminal because
the project does not automate administrator authentication.
