#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT_DIR/lib/common.sh"

DEST="${SNAPSHOT_DIR:?SNAPSHOT_DIR not set}"
DIAG_DIR="$DEST/diagnostics"

log_section "Snapshot diagnostics (ZFS, storage, versions)"

ensure_dir "$DIAG_DIR"

run_if_cmd() {
  local cmd="$1"; shift
  local out_file="$1"; shift

  if ! command -v "$cmd" >/dev/null 2>&1; then
    log_warn "Command not found, skipping: $cmd"
    return 0
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_info "Dry run: would run '$cmd $*' > $out_file"
    return 0
  fi

  log_info "Collecting diagnostics: $cmd $*"
  {
    echo "# $cmd $*"
    echo "# collected_at=$(date +%Y-%m-%d-%H%M%S)"
    echo
    "$cmd" "$@"
  } > "$out_file" 2>&1 || true
}

# ZFS pool/filesystem state (matches your manual backups)
run_if_cmd zpool "$DIAG_DIR/zpool-status.txt" status
run_if_cmd zpool "$DIAG_DIR/zpool-get-all.txt" get all
run_if_cmd zfs   "$DIAG_DIR/zfs-list.txt" list -t all -o name,used,avail,refer,mountpoint
run_if_cmd zfs   "$DIAG_DIR/zfs-get-all.txt" get all

# Proxmox storage config (plain-text copy for quick reference)
if [[ -f /etc/pve/storage.cfg ]]; then
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_info "Dry run: would copy /etc/pve/storage.cfg to diagnostics/storage.cfg"
  else
    if [[ "$(id -u)" -eq 0 ]]; then
      cp -a /etc/pve/storage.cfg "$DIAG_DIR/storage.cfg"
    else
      sudo cp -a /etc/pve/storage.cfg "$DIAG_DIR/storage.cfg"
    fi
    log_info "Copied /etc/pve/storage.cfg to diagnostics/storage.cfg"
  fi
fi

# Proxmox / system versions
run_if_cmd pveversion "$DIAG_DIR/pveversion-v.txt" -v
run_if_cmd pveperf    "$DIAG_DIR/pveperf.txt"
run_if_cmd proxmox-boot-tool "$DIAG_DIR/proxmox-boot-status.txt" status

log_info "Diagnostics snapshot complete (see diagnostics/ directory in snapshot)"

