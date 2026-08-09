#!/bin/zsh

set -euo pipefail

typeset -r test_dir="${0:A:h}"
typeset -r repo_dir="${test_dir:h}"
typeset -r scan_script="$repo_dir/scan_cis.zsh"
typeset test_temp_root="${MSCP_TEST_TMPDIR:-${TMPDIR:-/tmp}}"
while [[ "$test_temp_root" != "/" && "$test_temp_root" == */ ]]; do
  test_temp_root="${test_temp_root%/}"
done
typeset -r state_dir="$test_temp_root/macos-mscp-scan"
typeset -r prepared_pointer="$state_dir/latest-prepared-personal.txt"
typeset -r output_file="$(mktemp /private/tmp/macos-mscp-scan-prepare-output.XXXXXX)"
typeset -r resume_output_file="$(mktemp /private/tmp/macos-mscp-scan-resume-output.XXXXXX)"
typeset run_dir=""
typeset previous_pointer=""
typeset previous_pointer_existed=0
typeset audit_script_relative=""
typeset audit_script_path=""

if [[ -f "$prepared_pointer" && ! -L "$prepared_pointer" ]]; then
  previous_pointer="$(< "$prepared_pointer")"
  previous_pointer_existed=1
fi

cleanup() {
  set +e
  if [[ -n "$run_dir" \
    && "${run_dir:A:h}" == "${state_dir:A}/runs" \
    && "${run_dir:t}" == personal.* ]]; then
    rm -rf -- "$run_dir"
  fi

  if (( previous_pointer_existed )); then
    print -r -- "$previous_pointer" > "$prepared_pointer"
    chmod 600 "$prepared_pointer"
  elif [[ -f "$prepared_pointer" && ! -L "$prepared_pointer" \
    && "$(< "$prepared_pointer")" == "$run_dir" ]]; then
    rm -f -- "$prepared_pointer"
  fi
  rm -f -- "$output_file" "$resume_output_file"
}
trap cleanup EXIT

fail() {
  print -u2 "FAIL: $*"
  exit 1
}

TMPDIR="$test_temp_root/" zsh "$scan_script" \
  --baseline personal --prepare-only | tee "$output_file"

grep -F "PREPARATION COMPLETE — USER ACTION REQUIRED" "$output_file" >/dev/null \
  || fail "preparation did not print the user handoff"
[[ -f "$prepared_pointer" && ! -L "$prepared_pointer" ]] \
  || fail "prepared-run pointer is missing or unsafe"
run_dir="$(< "$prepared_pointer")"
[[ -d "$run_dir/report" ]] || fail "prepared report directory is missing"
[[ "${run_dir:A:h}" == "${state_dir:A}/runs" ]] || fail "run is outside the run root"

for expected_file in \
  baseline.yaml profile-definition.yaml prepared-state.txt provenance.txt \
  python-packages.txt ruby-gems.txt script.sha256 personal-customizations.sha256; do
  [[ -s "$run_dir/report/$expected_file" ]] || fail "missing report/$expected_file"
done
[[ -d "$run_dir/report/custom-rules" ]] || fail "custom rule evidence is missing"
[[ "$(find "$run_dir/report/custom-rules" -type f -name '*.yaml' | wc -l | tr -d ' ')" -ge 10 ]] \
  || fail "too few custom rules were recorded"

grep -F "Personal Mac Security Baseline" "$run_dir/report/baseline.yaml" >/dev/null \
  || fail "prepared baseline has the wrong title"
grep -F "It is not a CIS Benchmark assessment" "$run_dir/report/baseline.yaml" >/dev/null \
  || fail "prepared baseline is missing its non-CIS disclaimer"
if grep -F -- "- os_mdm_require" "$run_dir/report/baseline.yaml" >/dev/null 2>&1; then
  fail "personal baseline retained the MDM enrollment rule"
fi
if grep -F -- "- audit_" "$run_dir/report/baseline.yaml" >/dev/null 2>&1; then
  fail "personal baseline retained traditional auditd rules"
fi
for rule_id in \
  os_install_log_retention_configure \
  os_sudo_log_enforce \
  pwpolicy_account_lockout_enforce \
  pwpolicy_account_lockout_timeout_enforce \
  pwpolicy_history_enforce \
  pwpolicy_max_lifetime_enforce \
  pwpolicy_minimum_length_enforce \
  system_settings_improve_assistive_voice_disable \
  system_settings_improve_search_disable \
  system_settings_improve_siri_dictation_disable \
  system_settings_location_services_menu_enforce \
  os_unlock_active_user_session_disable \
  system_settings_loginwindow_prompt_username_password_enforce \
  system_settings_system_wide_preferences_configure \
  system_settings_time_server_configure; do
  if grep -F -- "- $rule_id" "$run_dir/report/baseline.yaml" >/dev/null 2>&1; then
    fail "personal baseline retained out-of-scope rule: $rule_id"
  fi
done
[[ ! -e "$run_dir/report/custom-rules/system_settings_time_server_configure.yaml" ]] \
  || fail "excluded time-server configuration retained a custom rule"

audit_script_relative="$(awk -F= '$1 == "audit_script_relative" {print $2}' "$run_dir/report/prepared-state.txt")"
audit_script_path="$run_dir/macos_security/$audit_script_relative"
[[ -f "$audit_script_path" ]] || fail "generated audit script is missing"
zsh -n "$audit_script_path"

expect_generated_result() {
  local rule_id="$1"
  local expected="$2"
  /usr/bin/awk -v rule_marker="rule_id=$rule_id" \
    -v expected_marker="expected_result=\"$expected\"" '
      index($0, rule_marker) {
        getline
        if (index($0, expected_marker)) found = 1
      }
      END { exit !found }
    ' "$audit_script_path" \
    || fail "generated audit has the wrong expected result for $rule_id"
}

expect_generated_result os_sudo_timeout_configure 1
expect_generated_result system_settings_bluetooth_sharing_disable 0
expect_generated_result system_settings_password_hints_disable 0
expect_generated_result system_settings_rae_disable 1
expect_generated_result system_settings_smbd_disable 1

grep -F "/usr/bin/fdesetup status" "$audit_script_path" >/dev/null \
  || fail "FileVault local-state check is missing"
grep -F "/usr/sbin/spctl --status" "$audit_script_path" >/dev/null \
  || fail "Gatekeeper local-state check is missing"
grep -F "socketfilterfw --getglobalstate" "$audit_script_path" >/dev/null \
  || fail "Firewall local-state check is missing"
grep -F 'State = [12]' "$audit_script_path" >/dev/null \
  || fail "Firewall local-state check does not accept Block All"
grep -F '/usr/bin/sudo -u "$CURRENT_USER" /usr/sbin/sysadminctl' \
  "$audit_script_path" >/dev/null \
  || fail "screen-lock local-state check does not use the active user"
for required_marker in \
  'com.apple.commerce AutoUpdate' \
  'Authentication timestamp timeout:' \
  'value <= 2' \
  'com.apple.Terminal SecureKeyboardEntry' \
  'PrefKeyServicesEnabled' \
  'RetriesUntilHint' \
  '-iTCP:3031' \
  '-iTCP:139 -iTCP:445'; do
  grep -F -- "$required_marker" "$audit_script_path" >/dev/null \
    || fail "generated personal audit is missing effective-state marker: $required_marker"
done
for forbidden_marker in \
  dontAllowFDEDisable forceInternetSharingOff "MDM enrollment" \
  "/usr/bin/profiles -P" com.apple.applicationaccess com.apple.MCX \
  com.apple.security.firewall; do
  if grep -F "$forbidden_marker" "$audit_script_path" >/dev/null; then
    fail "generated personal audit retained policy-only marker: $forbidden_marker"
  fi
done

[[ ! -e "$run_dir/report/audit-completed.txt" ]] || fail "preparation marked the audit complete"
[[ ! -e "$run_dir/report/scan-output.audit.plist" ]] || fail "preparation produced audit results"

typeset resume_status=0
set +e
TMPDIR="$test_temp_root/" zsh "$scan_script" --run-prepared "$run_dir" \
  > "$resume_output_file" 2>&1
resume_status=$?
set -e
[[ "$resume_status" == 69 ]] \
  || fail "non-interactive audit boundary returned $resume_status instead of 69"
grep -F "The audit phase requires the user's interactive Terminal." \
  "$resume_output_file" >/dev/null || fail "missing non-interactive boundary message"

print "# smoke-test integrity change" >> "$audit_script_path"
set +e
TMPDIR="$test_temp_root/" zsh "$scan_script" --run-prepared "$run_dir" \
  > "$resume_output_file" 2>&1
resume_status=$?
set -e
[[ "$resume_status" == 1 ]] \
  || fail "modified audit script returned $resume_status instead of 1"
grep -F "Prepared audit script changed after preparation." \
  "$resume_output_file" >/dev/null || fail "modified audit script was not rejected"

print "prepare smoke test passed: $run_dir"
