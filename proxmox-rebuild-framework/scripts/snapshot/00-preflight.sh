#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT_DIR/lib/common.sh"

log_info "Running snapshot preflight checks"
require_command bash
require_command tar
require_command cp
require_command date

# Proxmox: need root or sudo for /etc/pve and /var/lib/pve-cluster
if [[ -d /etc/pve ]]; then
  if [[ ! -r /etc/pve ]]; then
    [[ "$(id -u)" -eq 0 ]] || { require_command sudo; run_cmd sudo -v; }
  fi
else
  die "This does not appear to be a Proxmox VE host: /etc/pve not found"
fi

if ! grep -qi proxmox /etc/os-release 2>/dev/null; then
  log_warn "OS does not report Proxmox in /etc/os-release (optional check)"
fi

log_info "Host: $(hostname)"
log_info "Profile: ${PROFILE:-default}"
