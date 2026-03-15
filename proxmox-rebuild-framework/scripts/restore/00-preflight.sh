#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT_DIR/lib/common.sh"

log_info "Running restore preflight checks"
require_command bash
require_command tar
require_command cp

if [[ -z "${RESTORE_SNAPSHOT_DIR:-}" ]]; then
  die "RESTORE_SNAPSHOT_DIR is not set (rebuild.sh should set it)"
fi

if [[ ! -d "$RESTORE_SNAPSHOT_DIR" ]]; then
  die "Snapshot directory not found: $RESTORE_SNAPSHOT_DIR"
fi

if [[ ! -d /etc/pve ]]; then
  die "This does not appear to be a Proxmox VE host: /etc/pve not found"
fi

[[ "$(id -u)" -eq 0 ]] || { require_command sudo; run_cmd sudo -v; }

log_info "Restoring from: $RESTORE_SNAPSHOT_DIR"
log_info "Profile: ${PROFILE:-default}"
