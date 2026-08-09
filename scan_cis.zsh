#!/bin/zsh
# Read-only macOS security and CIS compliance scans using NIST mSCP 2.0.
# It never invokes --fix or --cfc. Runs and discardable download caches stay
# under the current user's temporary directory. Two mSCP runtime files are
# copied into the report and then restored or removed before exit.

set -euo pipefail

typeset -r REPO_URL="https://github.com/usnistgov/macos_security.git"
typeset -r MSCP_COMMIT="5b3d76a532d8a0ddb34d9c5dcb7fa8e191bc40be"
typeset -r PYTHON_RELEASE="20260610"
typeset -r PYTHON_VERSION="3.13.14"
typeset -r SCRIPT_VERSION="0.4.0"
typeset -r CACHE_FORMAT_VERSION="1"
typeset script_path="${0:A}"
typeset -r script_name="${0:t}"
typeset -r script_dir="${script_path:h}"
typeset -r personal_profile="$script_dir/profiles/personal/profile.yaml"
typeset -r personal_rules_dir="$script_dir/profiles/personal/rules"
typeset -r personal_builder="$script_dir/scripts/build_personal_baseline.py"
typeset baseline="personal"
typeset clear_cache=0
typeset prepare_only=0
typeset prepared_run=""
typeset baseline_was_set=0

usage() {
  print "Usage:"
  print "  zsh $script_name [--baseline personal|cis_lvl1|cis_lvl2] [--prepare-only]"
  print "  zsh $script_name --run-prepared RUN_DIR"
  print "  zsh $script_name --clear-cache"
  print ""
  print "  --baseline NAME     Baseline to check (default: personal)."
  print "  --prepare-only      Explicitly select the default preparation-only phase."
  print "  --run-prepared DIR  User-only interactive audit of a prepared run."
  print "  --clear-cache       Delete cached downloads without deleting reports."
  print "  --version           Print the script version and exit."
  print ""
  print "Preparation never requests administrator access. The read-only audit runs"
  print "only with --run-prepared in the user's interactive Terminal."
}

while (( $# )); do
  case "$1" in
    --baseline)
      if (( $# < 2 )); then
        usage
        exit 64
      fi
      baseline="$2"
      baseline_was_set=1
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
    --clear-cache)
      clear_cache=1
      shift
      ;;
    --prepare-only)
      prepare_only=1
      shift
      ;;
    --run-prepared)
      if (( $# < 2 )); then
        usage
        exit 64
      fi
      prepared_run="$2"
      shift 2
      ;;
    *)
      usage
      exit 64
      ;;
  esac
done

if (( clear_cache + prepare_only > 1 )) \
  || [[ -n "$prepared_run" && ( $clear_cache -eq 1 || $prepare_only -eq 1 ) ]]; then
  print -u2 -- "--clear-cache, --prepare-only, and --run-prepared are mutually exclusive."
  exit 64
fi
if [[ -n "$prepared_run" && $baseline_was_set -eq 1 ]]; then
  print -u2 -- "--run-prepared reads its baseline from the prepared run; do not combine it with --baseline."
  exit 64
fi

case "$baseline" in
  personal|cis_lvl1|cis_lvl2)
    ;;
  *)
    print -u2 "Unsupported baseline: $baseline"
    print -u2 "Supported baselines: personal, cis_lvl1, cis_lvl2"
    exit 64
    ;;
esac

if [[ "$baseline" == "personal" && -z "$prepared_run" && $clear_cache -eq 0 ]]; then
  if [[ ! -f "$personal_profile" || -L "$personal_profile" \
    || ! -f "$personal_builder" || -L "$personal_builder" \
    || ! -d "$personal_rules_dir" || -L "$personal_rules_dir" ]]; then
    print -u2 "The bundled personal profile is missing or unsafe."
    exit 1
  fi
fi

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

required_commands=(awk chmod cp cut date find git id mkdir mktemp mv rm shasum stat sudo tee uname)
if [[ -z "$prepared_run" && $clear_cache -eq 0 ]]; then
  required_commands+=(curl gem ruby tar)
fi
for command_name in $required_commands; do
  if ! command -v "$command_name" >/dev/null; then
    print -u2 "Missing required command: $command_name"
    exit 1
  fi
done

typeset python_asset=""
typeset python_sha256=""
if [[ -z "$prepared_run" && $clear_cache -eq 0 ]]; then
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
fi

# Keep completed runs and reusable download caches in the current user's macOS
# temporary directory. The operating system may purge them.
umask 077
typeset temp_root="${TMPDIR:-/tmp}"
while [[ "$temp_root" != "/" && "$temp_root" == */ ]]; do
  temp_root="${temp_root%/}"
done
if [[ "$temp_root" != /* || ! -d "$temp_root" || ! -w "$temp_root" ]]; then
  print -u2 "TMPDIR is not a writable absolute directory: $temp_root"
  exit 1
fi

typeset -r TEMP_ROOT="$temp_root"
typeset -r TEMP_STATE_DIR="$TEMP_ROOT/macos-mscp-scan"
typeset -r CACHE_ROOT="$TEMP_STATE_DIR/cache"
typeset -r CACHE_GENERATION="v${CACHE_FORMAT_VERSION}-py${PYTHON_VERSION}-${PYTHON_RELEASE}-mscp-${MSCP_COMMIT[1,12]}"
typeset -r CACHE_DIR="$CACHE_ROOT/$CACHE_GENERATION"
typeset -r CACHE_DOWNLOADS_DIR="$CACHE_DIR/downloads"
typeset -r RUNS_DIR="$TEMP_STATE_DIR/runs"
typeset -r current_uid="$(id -u)"
typeset LATEST_RUN_FILE=""
typeset LATEST_PREPARED_FILE=""
typeset RUN_DIR=""
typeset REPO_DIR=""
typeset REPORT_DIR=""
typeset PIP_CACHE_DIR=""
typeset RUBY_GEM_HOME=""
typeset RUBY_SPEC_CACHE=""
typeset BUNDLER_USER_HOME=""
typeset BUNDLER_USER_CACHE=""
typeset BUNDLER_PACKAGE_CACHE=""
typeset BUNDLER_CACHE_MARKER=""
typeset PYTHON_ARCHIVE=""
typeset PYTHON_URL=""
typeset baseline_file=""
typeset audit_script=""
typeset audit_plist=""
typeset audit_log=""
typeset audit_plist_backup=""
typeset audit_log_backup=""
typeset system_outputs_active=0
typeset audit_plist_existed=0
typeset audit_log_existed=0
typeset cache_download_tmp=""
typeset pointer_tmp=""
typeset preparation_in_progress=0

ensure_private_directory() {
  local directory_path="$1"
  local owner_uid=""

  if [[ -L "$directory_path" ]]; then
    print -u2 "Refusing to use a symbolic link as private storage: $directory_path"
    exit 1
  fi
  if [[ -e "$directory_path" && ! -d "$directory_path" ]]; then
    print -u2 "Private storage path is not a directory: $directory_path"
    exit 1
  fi
  if [[ ! -e "$directory_path" ]]; then
    mkdir -m 700 "$directory_path"
  fi

  owner_uid="$(stat -f %u "$directory_path")"
  if [[ "$owner_uid" != "$current_uid" ]]; then
    print -u2 "Refusing to use a directory owned by another user: $directory_path"
    exit 1
  fi
  chmod 700 "$directory_path"
}

set_baseline_paths() {
  LATEST_RUN_FILE="$TEMP_STATE_DIR/latest-${baseline}.txt"
  LATEST_PREPARED_FILE="$TEMP_STATE_DIR/latest-prepared-${baseline}.txt"
}

state_value() {
  local state_file="$1"
  local state_key="$2"
  awk -F= -v wanted_key="$state_key" '$1 == wanted_key {sub(/^[^=]*=/, ""); print; exit}' "$state_file"
}

write_pointer() {
  local pointer_file="$1"
  local pointer_value="$2"

  pointer_tmp="$(mktemp "$TEMP_STATE_DIR/.pointer.XXXXXX")"
  print -r -- "$pointer_value" > "$pointer_tmp"
  chmod 600 "$pointer_tmp"
  mv -f "$pointer_tmp" "$pointer_file"
  pointer_tmp=""
}

configure_audit_paths() {
  local baseline_id="${audit_script:t:r}"
  baseline_id="${baseline_id%_compliance}"
  audit_plist="/Library/Preferences/org.${baseline_id}.audit.plist"
  audit_log="/Library/Logs/${baseline_id}_baseline.log"
  audit_plist_backup="$REPORT_DIR/pre-scan.audit.plist"
  audit_log_backup="$REPORT_DIR/pre-scan_baseline.log"
}

cleanup() {
  local original_status=$?
  local restore_failed=0
  set +e

  case "$cache_download_tmp" in
    "$CACHE_DOWNLOADS_DIR"/.*)
      rm -f -- "$cache_download_tmp"
      ;;
  esac
  case "$pointer_tmp" in
    "$TEMP_STATE_DIR"/.pointer.*)
      rm -f -- "$pointer_tmp"
      ;;
  esac

  if (( preparation_in_progress )) \
    && [[ -n "$RUN_DIR" && "${RUN_DIR:A:h}" == "${RUNS_DIR:A}" \
      && "${RUN_DIR:t}" == ${baseline}.* && -d "$RUN_DIR" && ! -L "$RUN_DIR" ]] \
    && [[ "$(stat -f %u "$RUN_DIR")" == "$current_uid" ]]; then
    rm -rf -- "$RUN_DIR"
  fi

  if (( system_outputs_active )); then
    if (( audit_plist_existed )); then
      sudo cp -p "$audit_plist_backup" "$audit_plist" || restore_failed=1
    else
      sudo rm -f -- "$audit_plist" || restore_failed=1
    fi

    if (( audit_log_existed )); then
      sudo cp -p "$audit_log_backup" "$audit_log" || restore_failed=1
    else
      sudo rm -f -- "$audit_log" || restore_failed=1
    fi

    if (( restore_failed )); then
      print -u2 "Could not restore one or more pre-scan mSCP runtime files."
      print -u2 "Recovery copies, when present, remain in: $REPORT_DIR"
    else
      sudo rm -f -- "$audit_plist_backup" "$audit_log_backup"
    fi
  fi

  if (( original_status == 0 && restore_failed )); then
    trap - EXIT
    exit 1
  fi
  return "$original_status"
}

prepare_run() {
  local old_cache_dir=""
  local python_bin=""
  local candidate=""
  local ruby_default_gem_dir=""
  local bundle_command=""
  local bundle_definition_sha256=""
  local audit_script_relative=""
  local audit_script_sha256=""
  local script_sha256=""
  local source_baseline="$baseline"
  local source_baseline_file=""
  local custom_asset=""

  ensure_private_directory "$CACHE_ROOT"
  ensure_private_directory "$CACHE_DIR"
  ensure_private_directory "$CACHE_DOWNLOADS_DIR"
  ensure_private_directory "$CACHE_DIR/pip"
  ensure_private_directory "$CACHE_DIR/ruby-spec-cache"
  ensure_private_directory "$CACHE_DIR/bundler-user"
  ensure_private_directory "$CACHE_DIR/bundler-cache"
  ensure_private_directory "$CACHE_DIR/bundler-packages"
  ensure_private_directory "$RUNS_DIR"

  # A generation contains only reproducible downloads and metadata caches.
  for old_cache_dir in "$CACHE_ROOT"/*(N); do
    [[ "$old_cache_dir" == "$CACHE_DIR" ]] && continue
    if [[ -L "$old_cache_dir" || ! -d "$old_cache_dir" ]]; then
      print -u2 "Skipping unexpected cache entry: $old_cache_dir"
      continue
    fi
    if [[ "$(stat -f %u "$old_cache_dir")" != "$current_uid" ]]; then
      print -u2 "Skipping cache directory owned by another user: $old_cache_dir"
      continue
    fi
    rm -rf -- "$old_cache_dir"
  done

  RUN_DIR="$(mktemp -d "$RUNS_DIR/${baseline}.XXXXXX")"
  preparation_in_progress=1
  REPO_DIR="$RUN_DIR/macos_security"
  REPORT_DIR="$RUN_DIR/report"
  PIP_CACHE_DIR="$CACHE_DIR/pip"
  RUBY_GEM_HOME="$RUN_DIR/ruby-gems"
  RUBY_SPEC_CACHE="$CACHE_DIR/ruby-spec-cache"
  BUNDLER_USER_HOME="$CACHE_DIR/bundler-user"
  BUNDLER_USER_CACHE="$CACHE_DIR/bundler-cache"
  BUNDLER_PACKAGE_CACHE="$CACHE_DIR/bundler-packages"
  BUNDLER_CACHE_MARKER="$CACHE_DIR/bundler-packages.complete"
  PYTHON_ARCHIVE="$CACHE_DOWNLOADS_DIR/$python_asset"
  PYTHON_URL="https://github.com/astral-sh/python-build-standalone/releases/download/${PYTHON_RELEASE}/${python_asset}"

  mkdir -p "$REPORT_DIR"
  shasum -a 256 "$script_path" > "$REPORT_DIR/script.sha256"

  # Fetch only the pinned commit and its working-tree content.
  git init -q "$REPO_DIR"
  git -C "$REPO_DIR" remote add origin "$REPO_URL"
  git -C "$REPO_DIR" fetch --no-tags --depth=1 --filter=blob:none origin "$MSCP_COMMIT"
  git -C "$REPO_DIR" checkout -q --detach "$MSCP_COMMIT"
  if [[ "$(git -C "$REPO_DIR" rev-parse HEAD)" != "$MSCP_COMMIT" ]]; then
    print -u2 "The downloaded mSCP source does not match the expected commit."
    exit 1
  fi

  if [[ -L "$PYTHON_ARCHIVE" ]]; then
    print -u2 "Refusing to use a symbolic link as a cached download: $PYTHON_ARCHIVE"
    exit 1
  fi
  if [[ -e "$PYTHON_ARCHIVE" && ! -f "$PYTHON_ARCHIVE" ]]; then
    print -u2 "Cached download path is not a regular file: $PYTHON_ARCHIVE"
    exit 1
  fi

  if [[ -f "$PYTHON_ARCHIVE" ]] \
    && [[ "$(shasum -a 256 "$PYTHON_ARCHIVE" | awk '{print $1}')" == "$python_sha256" ]]; then
    print "Using verified cached CPython $PYTHON_VERSION archive."
  else
    print "Downloading CPython $PYTHON_VERSION into the temporary cache..."
    cache_download_tmp="$(mktemp "$CACHE_DOWNLOADS_DIR/.${python_asset}.XXXXXX")"
    curl --fail --location --output "$cache_download_tmp" "$PYTHON_URL"
    if [[ "$(shasum -a 256 "$cache_download_tmp" | awk '{print $1}')" != "$python_sha256" ]]; then
      print -u2 "The downloaded CPython archive does not match its expected SHA-256."
      exit 1
    fi
    chmod 600 "$cache_download_tmp"
    mv -f "$cache_download_tmp" "$PYTHON_ARCHIVE"
    cache_download_tmp=""
  fi

  if [[ "$(shasum -a 256 "$PYTHON_ARCHIVE" | awk '{print $1}')" != "$python_sha256" ]]; then
    print -u2 "The cached CPython archive does not match its expected SHA-256."
    exit 1
  fi
  tar -xzf "$PYTHON_ARCHIVE" -C "$RUN_DIR"

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

  ruby_default_gem_dir="$(ruby -e 'print Gem.default_dir')"
  export GEM_HOME="$RUBY_GEM_HOME"
  export GEM_PATH="$RUBY_GEM_HOME:$ruby_default_gem_dir"
  export GEM_SPEC_CACHE="$RUBY_SPEC_CACHE"
  export BUNDLE_USER_HOME="$BUNDLER_USER_HOME"
  export BUNDLE_USER_CACHE="$BUNDLER_USER_CACHE"
  export BUNDLE_DISABLE_SHARED_GEMS=true

  if command -v bundle >/dev/null && bundle --version >/dev/null; then
    bundle_command="$(command -v bundle)"
  else
    print "Installing Bundler into the temporary run directory..."
    gem install --no-document --install-dir "$RUBY_GEM_HOME" bundler
    bundle_command="$RUBY_GEM_HOME/bin/bundle"
  fi

  "$bundle_command" config --local path mscp_gems
  "$bundle_command" config --local bin mscp_gems/bin
  "$bundle_command" config --local cache_path "$BUNDLER_PACKAGE_CACHE"
  bundle_definition_sha256="$(shasum -a 256 Gemfile | awk '{print $1}')"
  if [[ -L "$BUNDLER_CACHE_MARKER" ]] \
    || [[ -e "$BUNDLER_CACHE_MARKER" && ! -f "$BUNDLER_CACHE_MARKER" ]]; then
    print -u2 "Bundler cache marker is not a safe regular file: $BUNDLER_CACHE_MARKER"
    exit 1
  fi
  if [[ -f "$BUNDLER_CACHE_MARKER" && ! -L "$BUNDLER_CACHE_MARKER" ]] \
    && [[ "$(< "$BUNDLER_CACHE_MARKER")" == "$bundle_definition_sha256" ]]; then
    print "Using reusable cached Bundler packages."
    if ! "$bundle_command" install --local; then
      print "The Bundler package cache was incomplete; refreshing it from RubyGems."
      rm -f -- "$BUNDLER_CACHE_MARKER"
      "$bundle_command" install
    fi
  else
    "$bundle_command" install
  fi
  "$bundle_command" cache
  print -r -- "$bundle_definition_sha256" > "$BUNDLER_CACHE_MARKER"
  chmod 600 "$BUNDLER_CACHE_MARKER"
  "$bundle_command" binstubs --all

  script_sha256="$(cut -d ' ' -f 1 "$REPORT_DIR/script.sha256")"
  {
    print "prepared_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    print "script_version=$SCRIPT_VERSION"
    print "macos_version=$os_full_version"
    print "mscp_target_os_version=$os_version"
    print "python_executable=$python_bin"
    print "python_version=$(python --version)"
    print "python_source=$PYTHON_URL"
    print "python_sha256=$python_sha256"
    print "mscp_repository=$REPO_URL"
    print "mscp_commit=$MSCP_COMMIT"
    print "temporary_root=$TEMP_ROOT"
    print "cache_generation=$CACHE_GENERATION"
    print "script_sha256=$script_sha256"
    print "mode=read-only --check"
  } > "$REPORT_DIR/provenance.txt"
  python -m pip freeze > "$REPORT_DIR/python-packages.txt"
  "$bundle_command" list > "$REPORT_DIR/ruby-gems.txt"

  if [[ "$baseline" == "personal" ]]; then
    source_baseline="cis_lvl1"
  fi
  ./mscp.py --os_name macos --os_version "$os_version" baseline -k "$source_baseline"

  if [[ "$baseline" == "personal" ]]; then
    source_baseline_file="$(find custom/baselines -maxdepth 1 -type f -name "${source_baseline}_macos_${os_version}.yaml" -print -quit)"
    if [[ -z "$source_baseline_file" ]]; then
      print -u2 "Could not find the generated $source_baseline source baseline."
      exit 1
    fi
    for custom_asset in "$personal_rules_dir/"*.yaml; do
      if [[ ! -f "$custom_asset" || -L "$custom_asset" ]]; then
        print -u2 "The bundled personal rule is missing or unsafe: $custom_asset"
        exit 1
      fi
    done
    mkdir -p custom/rules
    cp "$personal_rules_dir/"*.yaml custom/rules/
    baseline_file="custom/baselines/${baseline}_macos_${os_version}.yaml"
    python "$personal_builder" \
      --source "$source_baseline_file" \
      --profile "$personal_profile" \
      --output "$baseline_file"
    cp "$personal_profile" "$REPORT_DIR/profile-definition.yaml"
    mkdir -p "$REPORT_DIR/custom-rules"
    cp "$personal_rules_dir/"*.yaml "$REPORT_DIR/custom-rules/"
    for custom_asset in "$personal_builder" "$personal_profile" "$personal_rules_dir/"*.yaml; do
      print "$(shasum -a 256 "$custom_asset" | awk '{print $1}')  ${custom_asset#$script_dir/}"
    done > "$REPORT_DIR/personal-customizations.sha256"
  else
    baseline_file="$(find custom/baselines -maxdepth 1 -type f -name "${baseline}_macos_${os_version}.yaml" -print -quit)"
  fi
  if [[ -z "$baseline_file" ]]; then
    print -u2 "Could not find the generated $baseline baseline."
    exit 1
  fi

  ./mscp.py guidance "$baseline_file" -s
  audit_script_relative="$(find build -type f -name "${baseline}_macos_*_compliance.sh" -print -quit)"
  if [[ -z "$audit_script_relative" ]]; then
    print -u2 "Could not find the generated compliance script."
    exit 1
  fi

  cp "$baseline_file" "$REPORT_DIR/baseline.yaml"
  cp "${audit_script_relative:h}/"*.html "$REPORT_DIR/" 2>/dev/null || true
  cp "${audit_script_relative:h}/"*.pdf "$REPORT_DIR/" 2>/dev/null || true

  audit_script="$REPO_DIR/$audit_script_relative"
  baseline_file="$REPORT_DIR/baseline.yaml"
  audit_script_sha256="$(shasum -a 256 "$audit_script" | awk '{print $1}')"
  {
    print "baseline=$baseline"
    print "script_version=$SCRIPT_VERSION"
    print "script_sha256=$script_sha256"
    print "mscp_commit=$MSCP_COMMIT"
    print "audit_script_relative=$audit_script_relative"
    print "audit_script_sha256=$audit_script_sha256"
  } > "$REPORT_DIR/prepared-state.txt"

  configure_audit_paths
  set_baseline_paths
  write_pointer "$LATEST_PREPARED_FILE" "$RUN_DIR"
  preparation_in_progress=0
}

load_prepared_run() {
  local canonical_runs_dir="${RUNS_DIR:A}"
  local requested_run="${prepared_run:A}"
  local state_file=""
  local stored_script_version=""
  local stored_script_sha256=""
  local current_script_sha256=""
  local stored_mscp_commit=""
  local audit_script_relative=""
  local stored_audit_script_sha256=""

  if [[ -L "$prepared_run" ]]; then
    print -u2 "Prepared run must not be a symbolic link: $prepared_run"
    exit 64
  fi
  if [[ "${requested_run:h}" != "$canonical_runs_dir" ]]; then
    print -u2 "Prepared run must be a direct child of: $canonical_runs_dir"
    exit 64
  fi
  case "${requested_run:t}" in
    personal.*|cis_lvl1.*|cis_lvl2.*)
      ;;
    *)
      print -u2 "Prepared run has an unexpected directory name: ${requested_run:t}"
      exit 64
      ;;
  esac
  if [[ ! -d "$requested_run" ]]; then
    print -u2 "Prepared run is missing or is not a real directory: $requested_run"
    exit 1
  fi

  RUN_DIR="$requested_run"
  REPO_DIR="$RUN_DIR/macos_security"
  REPORT_DIR="$RUN_DIR/report"
  if [[ ! -d "$REPO_DIR" || -L "$REPO_DIR" || ! -d "$REPORT_DIR" || -L "$REPORT_DIR" ]]; then
    print -u2 "Prepared run is incomplete: $RUN_DIR"
    exit 1
  fi
  ensure_private_directory "$RUN_DIR"
  ensure_private_directory "$REPO_DIR"
  ensure_private_directory "$REPORT_DIR"

  state_file="$REPORT_DIR/prepared-state.txt"
  if [[ ! -f "$state_file" || -L "$state_file" ]]; then
    print -u2 "Prepared state is missing or unsafe: $state_file"
    exit 1
  fi
  if [[ -e "$REPORT_DIR/audit-completed.txt" ]]; then
    print -u2 "This prepared run has already been audited. Prepare a new run instead."
    exit 1
  fi

  baseline="$(state_value "$state_file" baseline)"
  case "$baseline" in
    personal|cis_lvl1|cis_lvl2)
      ;;
    *)
      print -u2 "Prepared run contains an unsupported baseline."
      exit 1
      ;;
  esac
  set_baseline_paths

  stored_script_version="$(state_value "$state_file" script_version)"
  stored_script_sha256="$(state_value "$state_file" script_sha256)"
  current_script_sha256="$(shasum -a 256 "$script_path" | awk '{print $1}')"
  stored_mscp_commit="$(state_value "$state_file" mscp_commit)"
  if [[ "$stored_script_version" != "$SCRIPT_VERSION" || "$stored_script_sha256" != "$current_script_sha256" ]]; then
    print -u2 "The wrapper changed after preparation. Prepare a new run with this script."
    exit 1
  fi
  if [[ "$stored_mscp_commit" != "$MSCP_COMMIT" ]] \
    || [[ "$(git -C "$REPO_DIR" rev-parse HEAD)" != "$MSCP_COMMIT" ]]; then
    print -u2 "Prepared mSCP source does not match the pinned commit."
    exit 1
  fi

  audit_script_relative="$(state_value "$state_file" audit_script_relative)"
  stored_audit_script_sha256="$(state_value "$state_file" audit_script_sha256)"
  case "$audit_script_relative" in
    build/${baseline}_macos_*_compliance.sh)
      ;;
    *)
      print -u2 "Prepared audit script path is invalid."
      exit 1
      ;;
  esac
  audit_script="$REPO_DIR/$audit_script_relative"
  if [[ ! -f "$audit_script" || -L "$audit_script" ]] \
    || [[ "${audit_script:A}" != "${REPO_DIR:A}"/build/* ]]; then
    print -u2 "Prepared audit script is missing or unsafe."
    exit 1
  fi
  if [[ "$(shasum -a 256 "$audit_script" | awk '{print $1}')" != "$stored_audit_script_sha256" ]]; then
    print -u2 "Prepared audit script changed after preparation."
    exit 1
  fi

  baseline_file="$REPORT_DIR/baseline.yaml"
  if [[ ! -f "$baseline_file" || -L "$baseline_file" ]]; then
    print -u2 "Prepared baseline is missing or unsafe."
    exit 1
  fi
  configure_audit_paths
}

print_user_handoff() {
  print "\nPREPARATION COMPLETE — USER ACTION REQUIRED"
  print "No administrator password was requested and no audit was run."
  print "The AI must stop here. In a normal user-controlled Terminal, run:"
  print ""
  print "  zsh ${(q)script_path} --run-prepared ${(q)RUN_DIR}"
  print ""
  print "Prepared run:                           $RUN_DIR"
  print "Prepared guidance:                      $REPORT_DIR"
  print "Prepared-run pointer:                   $LATEST_PREPARED_FILE"
}

run_audit() {
  local confirmation=""
  local scan_status=0
  local prepared_pointer_value=""

  if [[ ! -t 0 || ! -t 1 ]]; then
    print_user_handoff
    print -u2 "\nThe audit phase requires the user's interactive Terminal."
    exit 69
  fi

  print "\nUSER-CONTROLLED AUDIT"
  print "This will run a read-only $baseline audit with administrator access."
  print "Only mSCP's --check mode will be used; no settings will be remediated."
  read -r "confirmation?Continue and allow macOS to request your administrator password? [y/N] "
  print ""
  case "$confirmation" in
    y|Y|yes|YES|Yes)
      ;;
    *)
      print "Audit cancelled. The prepared run was kept for later."
      exit 130
      ;;
  esac

  print "audit_started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$REPORT_DIR/provenance.txt"
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

  print "\nRunning read-only $baseline checks.\n"
  set +e
  sudo zsh "$audit_script" --check | tee "$REPORT_DIR/${baseline}_check.txt"
  scan_status=${pipestatus[1]}
  set -e

  if sudo test -e "$audit_plist"; then
    sudo cat "$audit_plist" > "$REPORT_DIR/scan-output.audit.plist"
    chmod 600 "$REPORT_DIR/scan-output.audit.plist"
  fi
  if sudo test -e "$audit_log"; then
    sudo cat "$audit_log" > "$REPORT_DIR/scan-output_baseline.log"
    chmod 600 "$REPORT_DIR/scan-output_baseline.log"
  fi

  {
    print "audit_completed_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    print "audit_exit_status=$scan_status"
  } > "$REPORT_DIR/audit-completed.txt"
  write_pointer "$LATEST_RUN_FILE" "$RUN_DIR"

  if [[ -f "$LATEST_PREPARED_FILE" && ! -L "$LATEST_PREPARED_FILE" ]]; then
    prepared_pointer_value="$(< "$LATEST_PREPARED_FILE")"
    if [[ "$prepared_pointer_value" == "$RUN_DIR" ]]; then
      rm -f -- "$LATEST_PREPARED_FILE"
    fi
  fi

  print "\nTemporary run and report:                $RUN_DIR"
  print "Terminal report:                         $REPORT_DIR/${baseline}_check.txt"
  print "Structured results:                      $REPORT_DIR/scan-output.audit.plist"
  print "Provenance and dependency versions:      $REPORT_DIR/provenance.txt"
  print "Latest-run pointer:                      $LATEST_RUN_FILE"
  print "Reusable temporary cache:                $CACHE_DIR"
  print "Clear all cached downloads:              zsh ${(q)script_path} --clear-cache"
  print "Delete only this run:                    rm -rf -- ${(q)RUN_DIR}"

  return "$scan_status"
}

trap cleanup EXIT
ensure_private_directory "$TEMP_STATE_DIR"

if (( clear_cache )); then
  if [[ -e "$CACHE_ROOT" || -L "$CACHE_ROOT" ]]; then
    ensure_private_directory "$CACHE_ROOT"
    rm -rf -- "$CACHE_ROOT"
    print "Deleted temporary cache: $CACHE_ROOT"
  else
    print "Temporary cache is already empty: $CACHE_ROOT"
  fi
  print "Saved scan runs were not changed: $RUNS_DIR"
  exit 0
fi

ensure_private_directory "$RUNS_DIR"
if [[ -n "$prepared_run" ]]; then
  load_prepared_run
  run_audit
else
  set_baseline_paths
  prepare_run
  print_user_handoff
  exit 0
fi
