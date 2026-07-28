#!/bin/zsh
# Read-only macOS CIS compliance scan using NIST mSCP 2.0.
# It never invokes --fix or --cfc. Everything it creates is kept in one
# uniquely named /tmp directory, apart from two mSCP runtime files which are
# copied into the report and then restored or removed before exit.

set -euo pipefail

typeset -r REPO_URL="https://github.com/usnistgov/macos_security.git"
typeset -r MSCP_COMMIT="5b3d76a532d8a0ddb34d9c5dcb7fa8e191bc40be"
typeset -r PYTHON_RELEASE="20260610"
typeset -r PYTHON_VERSION="3.13.14"
typeset -r SCRIPT_VERSION="0.1.0"
typeset script_path="${0:A}"
typeset -r script_name="${0:t}"
typeset baseline="cis_lvl1"

usage() {
  print "Usage: zsh $script_name [--baseline cis_lvl1|cis_lvl2]"
  print "  --baseline NAME  CIS baseline to check (default: cis_lvl1)."
  print "  --version        Print the script version and exit."
  print "  The scan is read-only and asks for an administrator password."
}

while (( $# )); do
  case "$1" in
    --baseline)
      if (( $# < 2 )); then
        usage
        exit 64
      fi
      baseline="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --version)
      print "$script_name $SCRIPT_VERSION"
      exit 0
      ;;
    *)
      usage
      exit 64
      ;;
  esac
done

case "$baseline" in
  cis_lvl1|cis_lvl2)
    ;;
  *)
    print -u2 "Unsupported baseline: $baseline"
    print -u2 "Supported baselines: cis_lvl1, cis_lvl2"
    exit 64
    ;;
esac

typeset -r RUN_DIR="$(mktemp -d /tmp/mscp-${baseline}.XXXXXX)"
typeset -r REPO_DIR="$RUN_DIR/macos_security"
typeset -r REPORT_DIR="$RUN_DIR/report"
typeset -r PIP_CACHE_DIR="$RUN_DIR/pip-cache"
typeset -r RUBY_GEM_HOME="$RUN_DIR/ruby-gems"
typeset -r RUBY_SPEC_CACHE="$RUN_DIR/ruby-spec-cache"
typeset -r BUNDLER_USER_HOME="$RUN_DIR/bundler-user"
typeset system_outputs_active=0
typeset audit_plist=""
typeset audit_log=""
typeset audit_plist_existed=0
typeset audit_log_existed=0
typeset audit_plist_backup=""
typeset audit_log_backup=""
restore_system_outputs() {
  local original_status=$?

  (( system_outputs_active )) || return "$original_status"
  set +e

  if (( audit_plist_existed )); then
    sudo cp -p "$audit_plist_backup" "$audit_plist"
  else
    sudo rm -f -- "$audit_plist"
  fi

  if (( audit_log_existed )); then
    sudo cp -p "$audit_log_backup" "$audit_log"
  else
    sudo rm -f -- "$audit_log"
  fi

  return "$original_status"
}

trap restore_system_outputs EXIT

if [[ "$(uname -s)" != "Darwin" ]]; then
  print -u2 "This script must run on macOS."
  exit 1
fi

typeset -r os_full_version="$(sw_vers -productVersion)"
typeset -r os_version="${os_full_version%%.*}.0"
case "$os_version" in
  14.0|15.0|26.0)
    ;;
  *)
    print -u2 "Unsupported macOS version: $os_full_version"
    print -u2 "This mSCP 2.0 release supports macOS 14, 15, and 26 only."
    print -u2 "macOS 13 and earlier require a separately tested mSCP 1.0 workflow."
    exit 1
    ;;
esac

for command_name in curl git ruby gem shasum tar; do
  if ! command -v "$command_name" >/dev/null; then
    print -u2 "Missing required command: $command_name"
    exit 1
  fi
done

mkdir -p "$REPORT_DIR"
if [[ -f "$script_path" ]]; then
  shasum -a 256 "$script_path" > "$REPORT_DIR/script.sha256"
fi

# Fetch only the pinned commit and its working-tree content, not the complete
# mSCP history. This keeps the download and all Git objects in RUN_DIR small.
git init -q "$REPO_DIR"
git -C "$REPO_DIR" remote add origin "$REPO_URL"
git -C "$REPO_DIR" fetch --no-tags --depth=1 --filter=blob:none origin "$MSCP_COMMIT"
git -C "$REPO_DIR" checkout -q --detach "$MSCP_COMMIT"
if [[ "$(git -C "$REPO_DIR" rev-parse HEAD)" != "$MSCP_COMMIT" ]]; then
  print -u2 "The downloaded mSCP source does not match the expected commit."
  exit 1
fi

case "$(uname -m)" in
  arm64)
    python_asset="cpython-${PYTHON_VERSION}+${PYTHON_RELEASE}-aarch64-apple-darwin-install_only_stripped.tar.gz"
    python_sha256="79daa8e9dea1e64ad50aebb05a807289023a474c2020b72361eb44d67fa2401e"
    ;;
  x86_64)
    python_asset="cpython-${PYTHON_VERSION}+${PYTHON_RELEASE}-x86_64-apple-darwin-install_only_stripped.tar.gz"
    python_sha256="064731aded38b1a12909088d40d9e0e385dc989e38a1e1de9917610254194962"
    ;;
  *)
    print -u2 "Unsupported macOS architecture: $(uname -m)"
    exit 1
    ;;
esac

typeset -r PYTHON_ARCHIVE="$RUN_DIR/$python_asset"
typeset -r PYTHON_URL="https://github.com/astral-sh/python-build-standalone/releases/download/${PYTHON_RELEASE}/${python_asset}"
print "Downloading temporary CPython $PYTHON_VERSION..."
curl --fail --location --output "$PYTHON_ARCHIVE" "$PYTHON_URL"
if [[ "$(shasum -a 256 "$PYTHON_ARCHIVE" | awk '{print $1}')" != "$python_sha256" ]]; then
  print -u2 "The downloaded CPython archive does not match its expected SHA-256."
  exit 1
fi
tar -xzf "$PYTHON_ARCHIVE" -C "$RUN_DIR"

typeset python_bin=""
for candidate in "$RUN_DIR/python/bin/python3.13" "$RUN_DIR/python/bin/python3"; do
  if [[ -x "$candidate" ]] \
    && "$candidate" -c 'import sys; sys.exit(0 if sys.version_info[:2] == (3, 13) else 1)'; then
    python_bin="$candidate"
    break
  fi
done
if [[ -z "$python_bin" ]]; then
  print -u2 "The verified CPython archive did not contain a usable Python 3.13 executable."
  exit 1
fi

cd "$REPO_DIR"
export PIP_CACHE_DIR
export PIP_DISABLE_PIP_VERSION_CHECK=1
"$python_bin" -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip setuptools wheel
python -m pip install --upgrade -r requirements.txt

# Ruby has no venv equivalent. Isolate its gems, metadata cache, and Bundler
# user state in RUN_DIR. GEM_PATH retains Ruby's read-only default gems.
typeset ruby_default_gem_dir="$(ruby -e 'print Gem.default_dir')"
export GEM_HOME="$RUBY_GEM_HOME"
export GEM_PATH="$RUBY_GEM_HOME:$ruby_default_gem_dir"
export GEM_SPEC_CACHE="$RUBY_SPEC_CACHE"
export BUNDLE_USER_HOME="$BUNDLER_USER_HOME"
export BUNDLE_DISABLE_SHARED_GEMS=true

typeset bundle_command=""
if command -v bundle >/dev/null && bundle --version >/dev/null; then
  bundle_command="$(command -v bundle)"
else
  print "Installing Bundler into the temporary run directory..."
  gem install --no-document --install-dir "$RUBY_GEM_HOME" bundler
  bundle_command="$RUBY_GEM_HOME/bin/bundle"
fi

# Keep Bundler's configuration and downloaded gems inside this temporary
# project, rather than in the user's global Bundler configuration or gem path.
"$bundle_command" config --local path mscp_gems
"$bundle_command" config --local bin mscp_gems/bin
"$bundle_command" install
"$bundle_command" binstubs --all

{
  print "scan_started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  print "script_version=$SCRIPT_VERSION"
  print "macos_version=$os_full_version"
  print "mscp_target_os_version=$os_version"
  print "python_executable=$python_bin"
  print "python_version=$(python --version)"
  print "python_source=$PYTHON_URL"
  print "python_sha256=$python_sha256"
  print "mscp_repository=$REPO_URL"
  print "mscp_commit=$MSCP_COMMIT"
  print "script_sha256=$(cut -d ' ' -f 1 "$REPORT_DIR/script.sha256" 2>/dev/null)"
  print "mode=read-only --check"
} > "$REPORT_DIR/provenance.txt"
python -m pip freeze > "$REPORT_DIR/python-packages.txt"
"$bundle_command" list > "$REPORT_DIR/ruby-gems.txt"

./mscp.py --os_name macos --os_version "$os_version" baseline -k "$baseline"

baseline_file="$(find custom/baselines -maxdepth 1 -type f -name "${baseline}_macos_*.yaml" -print -quit)"
if [[ -z "$baseline_file" ]]; then
  print -u2 "Could not find the generated $baseline baseline."
  exit 1
fi

./mscp.py guidance "$baseline_file" -s

audit_script="$(find build -type f -name "${baseline}_macos_*_compliance.sh" -print -quit)"
if [[ -z "$audit_script" ]]; then
  print -u2 "Could not find the generated compliance script."
  exit 1
fi

baseline_id="${audit_script:t:r}"
baseline_id="${baseline_id%_compliance}"
audit_plist="/Library/Preferences/org.${baseline_id}.audit.plist"
audit_log="/Library/Logs/${baseline_id}_baseline.log"
audit_plist_backup="$REPORT_DIR/pre-scan.audit.plist"
audit_log_backup="$REPORT_DIR/pre-scan_baseline.log"

# mSCP documents that --check writes these two files. Preserve existing ones,
# then restore them (or remove newly-created files) when the scan finishes.
print "\nThis will run a read-only $baseline audit with administrator access."
print "Only mSCP's --check mode will be used; no settings will be remediated.\n"
sudo -v
if sudo test -e "$audit_plist"; then
  sudo cp -p "$audit_plist" "$audit_plist_backup"
  audit_plist_existed=1
fi
if sudo test -e "$audit_log"; then
  sudo cp -p "$audit_log" "$audit_log_backup"
  audit_log_existed=1
fi
system_outputs_active=1

print "\nRunning read-only $baseline checks. macOS may ask for your administrator password.\n"
set +e
sudo zsh "$audit_script" --check | tee "$REPORT_DIR/${baseline}_check.txt"
scan_status=${pipestatus[1]}
set -e

cp "$baseline_file" "$REPORT_DIR/baseline.yaml"
cp "${audit_script:h}/"*.html "$REPORT_DIR/" 2>/dev/null || true
cp "${audit_script:h}/"*.pdf "$REPORT_DIR/" 2>/dev/null || true

if sudo test -e "$audit_plist"; then
  sudo cp -p "$audit_plist" "$REPORT_DIR/scan-output.audit.plist"
fi
if sudo test -e "$audit_log"; then
  sudo cp -p "$audit_log" "$REPORT_DIR/scan-output_baseline.log"
fi

print "\nAll temporary files and the report are in: $RUN_DIR"
print "Terminal report:                         $REPORT_DIR/${baseline}_check.txt"
print "Provenance and dependency versions:      $REPORT_DIR/provenance.txt"
print "Delete everything after reading:         rm -rf $RUN_DIR"

exit "$scan_status"
