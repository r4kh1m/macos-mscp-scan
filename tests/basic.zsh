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
[[ "$(zsh "$scan_script" --version)" == "scan_cis.zsh 0.3.0" ]] \
  || fail "unexpected version"

[[ -s "$profile_file" && ! -L "$profile_file" ]] \
  || fail "personal profile is missing or unsafe"
for rule_id in \
  os_gatekeeper_enable \
  system_settings_filevault_enforce \
  system_settings_firewall_enable \
  system_settings_guest_account_disable; do
  [[ -s "$profile_rules/$rule_id.yaml" && ! -L "$profile_rules/$rule_id.yaml" ]] \
    || fail "missing personal custom rule: $rule_id"
done

# Most upstream rules expect the literal string "true", not numeric 1. Keep
# the custom check output aligned with that contract or every pass becomes a
# false finding in the generated compliance script.
for rule_id in \
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
grep -F "string: 'true'" "$profile_rules/os_gatekeeper_enable.yaml" >/dev/null \
  || fail "Gatekeeper common result is not boolean"
grep -F 'string: $ODV' "$profile_rules/system_settings_time_server_configure.yaml" >/dev/null \
  || fail "time-server rule does not emit the configured server"
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
