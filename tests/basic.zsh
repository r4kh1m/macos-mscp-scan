#!/bin/zsh

set -euo pipefail

typeset -r test_dir="${0:A:h}"
typeset -r repo_dir="${test_dir:h}"
typeset -r scan_script="$repo_dir/scan_cis.zsh"
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
[[ "$(zsh "$scan_script" --version)" == "scan_cis.zsh 0.2.0-dev" ]] \
  || fail "unexpected version"

expect_status 64 zsh "$scan_script" --baseline unsupported
expect_status 64 zsh "$scan_script" --clear-cache --prepare-only
expect_status 64 zsh "$scan_script" --run-prepared /private/tmp/not-a-run --baseline cis_lvl1

mkdir -p "$state_dir/cache/sentinel" "$state_dir/runs/saved"
TMPDIR="$test_root/" zsh "$scan_script" --clear-cache >/dev/null
[[ ! -e "$state_dir/cache" ]] || fail "--clear-cache left its cache directory"
[[ -d "$state_dir/runs/saved" ]] || fail "--clear-cache removed a saved run"

mkdir -p "$state_dir/runs/cis_lvl1.parent/nested"
expect_status 64 env TMPDIR="$test_root/" zsh "$scan_script" \
  --run-prepared "$state_dir/runs/cis_lvl1.parent/nested"

ln -s "$state_dir/runs/saved" "$state_dir/runs/cis_lvl1.link"
expect_status 64 env TMPDIR="$test_root/" zsh "$scan_script" \
  --run-prepared "$state_dir/runs/cis_lvl1.link"

print "basic tests passed"
