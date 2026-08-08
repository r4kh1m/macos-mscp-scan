# Compatibility

`macos-mscp-scan` version 0.1.0 and the current development version pin mSCP 2.0
commit `5b3d76a532d8a0ddb34d9c5dcb7fa8e191bc40be`. Its macOS rule library
contains targets for macOS 14.0, 15.0, and 26.0 only.

| macOS version | Tool behavior | Validation status |
| --- | --- | --- |
| 26 Tahoe | Supported | End-to-end audit run on Apple Silicon |
| 15 Sequoia | Supported | Community validation requested |
| 14 Sonoma | Supported | Community validation requested |
| 13 Ventura and earlier | Rejected before downloads | Requires a separate mSCP 1.0 workflow |

The script supports `arm64` and `x86_64` portable CPython archives. It does
not claim that every individual CIS rule applies unchanged to every hardware,
MDM, or organisational configuration.

Please report successful and unsuccessful runs in GitHub Discussions with the
baseline, macOS version, architecture, and sanitized rule identifiers.

The two-phase preparation path is exercised by the repository smoke test. An
end-to-end audit still requires a user-controlled interactive Terminal because
the project does not automate administrator authentication.
