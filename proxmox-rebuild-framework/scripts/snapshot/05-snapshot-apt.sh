#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT_DIR/lib/common.sh"

DEST="${SNAPSHOT_DIR:?SNAPSHOT_DIR not set}"
APT_DIR="$DEST/apt"

log_section "Snapshot APT state (packages/manually-installed)"

ensure_dir "$APT_DIR"

run_if_cmd() {
  local cmd="$1"; shift
  local out_file="$1"; shift

  if ! command -v "$cmd" >/dev/null 2>&1; then
    log_warn "APT command not found, skipping: $cmd"
    return 0
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_info "Dry run: would run '$cmd $*' > $out_file"
    return 0
  fi

  log_info "Collecting APT info: $cmd $*"
  {
    echo "# $cmd $*"
    echo "# collected_at=$(date +%Y-%m-%d-%H%M%S)"
    echo
    "$cmd" "$@"
  } > "$out_file" 2>&1 || true
}

# Full dpkg selections (informational; not replayed directly)
run_if_cmd dpkg "$APT_DIR/dpkg-selections.txt" --get-selections

# Manually installed packages (useful as a base to reinstall on restore)
run_if_cmd apt-mark "$APT_DIR/apt-manual-packages.txt" showmanual

log_info "APT snapshot complete (see apt/ directory in snapshot)"

