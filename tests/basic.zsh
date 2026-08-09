#!/bin/zsh

set -euo pipefail

typeset -r test_dir="${0:A:h}"
typeset -r repo_dir="${test_dir:h}"
typeset -r scan_script="$repo_dir/scan_cis.zsh"
typeset -r profile_file="$repo_dir/profiles/personal/profile.yaml"
typeset -r profile_rules="$repo_dir/profiles/personal/rules"
typeset -r test_root="$(mktemp -d /private/tmp/macos-mscp-scan-basic.XXXXXX)"
typeset -r state_dir="$test_root/macos-mscp-scan"

cleanup() {
  case "$test_root" in
    /private/tmp/macos-mscp-scan-basic.*)
      rm -rf -- "$test_root"
      ;;
  esac
}
trap cleanup EXIT

fail() {
  print -u2 "FAIL: $*"
  exit 1
}

expect_status() {
  local expected_status="$1"
  shift
  local actual_status=0

  set +e
  "$@" >/dev/null 2>&1
  actual_status=$?
  set -e
  [[ "$actual_status" == "$expected_status" ]] \
    || fail "expected status $expected_status, got $actual_status: $*"
}

zsh -n "$scan_script"
zsh "$scan_script" --help | grep -F -- "--prepare-only" >/dev/null
zsh "$scan_script" --help | grep -F -- "--run-prepared" >/dev/null
zsh "$scan_script" --help | grep -F -- "personal|cis_lvl1|cis_lvl2" >/dev/null
[[ "$(zsh "$scan_script" --version)" == "scan_cis.zsh 0.4.0" ]] \
  || fail "unexpected version"

[[ -s "$profile_file" && ! -L "$profile_file" ]] \
  || fail "personal profile is missing or unsafe"
for rule_id in \
  audit_acls_files_configure \
  audit_acls_folders_configure \
  audit_auditd_enabled \
  audit_control_acls_configure \
  audit_control_group_configure \
  audit_control_mode_configure \
  audit_control_owner_configure \
  audit_files_group_configure \
  audit_files_mode_configure \
  audit_files_owner_configure \
  audit_folder_group_configure \
  audit_folder_owner_configure \
  audit_folders_mode_configure \
  audit_retention_configure; do
  grep -Fx "  - $rule_id" "$profile_file" >/dev/null \
    || fail "personal profile retained audit rule: $rule_id"
done
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
  grep -Fx "  - $rule_id" "$profile_file" >/dev/null \
    || fail "personal profile retained an agreed out-of-scope rule: $rule_id"
done
[[ ! -e "$profile_rules/system_settings_time_server_configure.yaml" ]] \
  || fail "excluded time-server configuration still has a custom rule"
for rule_id in \
  os_gatekeeper_enable \
  os_software_update_app_update_enforce \
  os_sudo_timeout_configure \
  os_terminal_secure_keyboard_enable \
  system_settings_bluetooth_sharing_disable \
  system_settings_filevault_enforce \
  system_settings_firewall_enable \
  system_settings_guest_account_disable \
  system_settings_password_hints_disable \
  system_settings_rae_disable \
  system_settings_smbd_disable; do
  [[ -s "$profile_rules/$rule_id.yaml" && ! -L "$profile_rules/$rule_id.yaml" ]] \
    || fail "missing personal custom rule: $rule_id"
done

# Most upstream rules expect the literal string "true", not numeric 1. Keep
# the custom check output aligned with that contract or every pass becomes a
# false finding in the generated compliance script.
for rule_id in \
  os_software_update_app_update_enforce \
  os_terminal_secure_keyboard_enable \
  system_settings_automatic_login_disable \
  system_settings_diagnostics_reports_disable \
  system_settings_firewall_enable \
  system_settings_firewall_stealth_mode_enable \
  system_settings_guest_account_disable \
  system_settings_internet_sharing_disable \
  system_settings_screensaver_ask_for_password_delay_enforce \
  system_settings_screensaver_password_enforce \
  system_settings_screensaver_timeout_enforce \
  system_settings_time_server_enforce; do
  rule_file="$profile_rules/$rule_id.yaml"
  grep -F "string: 'true'" "$rule_file" >/dev/null \
    || fail "boolean custom rule has the wrong expected type: $rule_id"
  if grep -Eq 'echo "[01]"|\? 1 : 0' "$rule_file"; then
    fail "boolean custom rule emits a numeric result: $rule_id"
  fi
done
for rule_contract in \
  os_sudo_timeout_configure:1 \
  system_settings_bluetooth_sharing_disable:0 \
  system_settings_password_hints_disable:0 \
  system_settings_rae_disable:1 \
  system_settings_smbd_disable:1; do
  rule_id="${rule_contract%%:*}"
  expected_result="${rule_contract##*:}"
  rule_file="$profile_rules/$rule_id.yaml"
  grep -F "integer: $expected_result" "$rule_file" >/dev/null \
    || fail "numeric custom rule has the wrong expected type: $rule_id"
  if grep -Eq 'echo "(true|false)"|string: .true.' "$rule_file"; then
    fail "numeric custom rule emits a boolean string: $rule_id"
  fi
done
grep -F 'com.apple.commerce AutoUpdate' \
  "$profile_rules/os_software_update_app_update_enforce.yaml" >/dev/null \
  || fail "App Store update check does not use the active user preference"
grep -F 'Authentication timestamp timeout:' \
  "$profile_rules/os_sudo_timeout_configure.yaml" >/dev/null \
  || fail "sudo timeout check does not read the effective configuration"
grep -F 'value <= 2' "$profile_rules/os_sudo_timeout_configure.yaml" >/dev/null \
  || fail "sudo timeout check does not enforce the two-minute maximum"
grep -F 'com.apple.Terminal SecureKeyboardEntry' \
  "$profile_rules/os_terminal_secure_keyboard_enable.yaml" >/dev/null \
  || fail "Terminal check does not use the active user preference"
grep -F 'PrefKeyServicesEnabled' \
  "$profile_rules/system_settings_bluetooth_sharing_disable.yaml" >/dev/null \
  || fail "Bluetooth Sharing effective-state check is missing"
grep -F 'RetriesUntilHint' \
  "$profile_rules/system_settings_password_hints_disable.yaml" >/dev/null \
  || fail "password-hint effective-state check is missing"
grep -F -- '-iTCP:3031' "$profile_rules/system_settings_rae_disable.yaml" >/dev/null \
  || fail "Remote Apple Events listener check is missing"
grep -F -- '-iTCP:139 -iTCP:445' "$profile_rules/system_settings_smbd_disable.yaml" >/dev/null \
  || fail "SMB listener check is missing"
grep -F "string: 'true'" "$profile_rules/os_gatekeeper_enable.yaml" >/dev/null \
  || fail "Gatekeeper common result is not boolean"
[[ "$(grep -Fc 'State = [12]' "$profile_rules/system_settings_firewall_enable.yaml")" == 2 ]] \
  || fail "Firewall check does not accept enabled and Block All states"
for rule_id in \
  system_settings_screensaver_ask_for_password_delay_enforce \
  system_settings_screensaver_password_enforce; do
  grep -F '/usr/bin/sudo -u "$CURRENT_USER" /usr/sbin/sysadminctl' \
    "$profile_rules/$rule_id.yaml" >/dev/null \
    || fail "screen-lock check does not use the active user: $rule_id"
done
if grep -Eq '^[[:space:]]+status=' "$profile_rules/"*.yaml; then
  fail "custom rule assigns zsh's read-only status parameter"
fi

expect_status 64 zsh "$scan_script" --baseline unsupported
expect_status 64 zsh "$scan_script" --clear-cache --prepare-only
expect_status 64 zsh "$scan_script" --run-prepared /private/tmp/not-a-run --baseline personal

mkdir -p "$state_dir/cache/sentinel" "$state_dir/runs/saved"
TMPDIR="$test_root/" zsh "$scan_script" --clear-cache >/dev/null
[[ ! -e "$state_dir/cache" ]] || fail "--clear-cache left its cache directory"
[[ -d "$state_dir/runs/saved" ]] || fail "--clear-cache removed a saved run"

mkdir -p "$state_dir/runs/personal.parent/nested"
expect_status 64 env TMPDIR="$test_root/" zsh "$scan_script" \
  --run-prepared "$state_dir/runs/personal.parent/nested"

ln -s "$state_dir/runs/saved" "$state_dir/runs/personal.link"
expect_status 64 env TMPDIR="$test_root/" zsh "$scan_script" \
  --run-prepared "$state_dir/runs/personal.link"

print "basic tests passed"
