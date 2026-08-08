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
typeset -r prepared_pointer="$state_dir/latest-prepared-cis_lvl1.txt"
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
    && "${run_dir:t}" == cis_lvl1.* ]]; then
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
  --baseline cis_lvl1 --prepare-only | tee "$output_file"

grep -F "PREPARATION COMPLETE — USER ACTION REQUIRED" "$output_file" >/dev/null \
  || fail "preparation did not print the user handoff"
[[ -f "$prepared_pointer" && ! -L "$prepared_pointer" ]] \
  || fail "prepared-run pointer is missing or unsafe"
run_dir="$(< "$prepared_pointer")"
[[ -d "$run_dir/report" ]] || fail "prepared report directory is missing"
[[ "${run_dir:A:h}" == "${state_dir:A}/runs" ]] || fail "run is outside the run root"

for expected_file in \
  baseline.yaml prepared-state.txt provenance.txt python-packages.txt ruby-gems.txt script.sha256; do
  [[ -s "$run_dir/report/$expected_file" ]] || fail "missing report/$expected_file"
done
audit_script_relative="$(awk -F= '$1 == "audit_script_relative" {print $2}' "$run_dir/report/prepared-state.txt")"
audit_script_path="$run_dir/macos_security/$audit_script_relative"
[[ -f "$audit_script_path" ]] || fail "generated audit script is missing"
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
