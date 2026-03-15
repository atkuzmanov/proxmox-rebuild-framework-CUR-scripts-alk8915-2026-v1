#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT_DIR/lib/common.sh"

# Snapshot destination from parent (snapshot.sh sets SNAPSHOT_DIR)
DEST="${SNAPSHOT_DIR:?SNAPSHOT_DIR not set}"
PVE_BACKUP="$DEST/pve-config"

log_section "Snapshot Proxmox VE configuration"

ensure_dir "$PVE_BACKUP"

# 1) Cluster database (source of truth for /etc/pve)
if [[ -f /var/lib/pve-cluster/config.db ]]; then
  if [[ "$(id -u)" -eq 0 ]]; then
    run_cmd cp -a /var/lib/pve-cluster/config.db "$PVE_BACKUP/config.db"
  else
    run_cmd_sudo cp -a /var/lib/pve-cluster/config.db "$PVE_BACKUP/config.db"
  fi
  log_info "Backed up /var/lib/pve-cluster/config.db"
else
  log_warn "config.db not found (single-node or not yet initialized)"
fi

# 2) Copy of /etc/pve (VM/CT configs, storage.cfg, firewall, etc.)
#    Configs only; disk images live in storage and are not included.
ETC_PVE_TAR="$PVE_BACKUP/etc-pve.tar"
if [[ "$(id -u)" -eq 0 ]]; then
  run_cmd tar -C / -cf "$ETC_PVE_TAR" etc/pve 2>/dev/null || true
else
  run_cmd_sudo tar -C / -cf "$ETC_PVE_TAR" etc/pve 2>/dev/null || true
fi
log_info "Backed up /etc/pve to etc-pve.tar"

# 3) List VM and CT IDs for manifest
ensure_dir "$PVE_BACKUP/lists"
for dir in /etc/pve/qemu-server /etc/pve/lxc; do
  if [[ -d "$dir" ]]; then
    if [[ "$(id -u)" -eq 0 ]]; then
      ls -1 "$dir" 2>/dev/null | sed 's/\.conf$//' > "$PVE_BACKUP/lists/$(basename "$dir").txt" || true
    else
      sudo ls -1 "$dir" 2>/dev/null | sed 's/\.conf$//' > "$PVE_BACKUP/lists/$(basename "$dir").txt" || true
    fi
  fi
done
log_info "VM/CT ID lists written to pve-config/lists/"
