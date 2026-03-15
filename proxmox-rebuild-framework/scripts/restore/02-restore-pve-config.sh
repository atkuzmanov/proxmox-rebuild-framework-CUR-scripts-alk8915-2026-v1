#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT_DIR/lib/common.sh"

PVE_BACKUP="${RESTORE_SNAPSHOT_DIR:?}/pve-config"
[[ -d "$PVE_BACKUP" ]] || { log_warn "No pve-config in snapshot, skipping PVE restore"; exit 0; }

log_section "Restore Proxmox VE configuration"

# Restore cluster database (repopulates /etc/pve)
if [[ -f "$PVE_BACKUP/config.db" ]]; then
  log_info "Stopping pve-cluster..."
  if [[ "$(id -u)" -eq 0 ]]; then
    systemctl stop pve-cluster
    cp -a "$PVE_BACKUP/config.db" /var/lib/pve-cluster/config.db
    systemctl start pve-cluster
  else
    sudo systemctl stop pve-cluster
    sudo cp -a "$PVE_BACKUP/config.db" /var/lib/pve-cluster/config.db
    sudo systemctl start pve-cluster
  fi
  log_info "Cluster config restored; /etc/pve should be repopulated."
else
  log_warn "No config.db in snapshot. If you have etc-pve.tar you can extract it manually after stopping pve-cluster (advanced)."
fi

# Optional: if we only have etc-pve.tar (e.g. from another node), we could extract
# after stopping pve-cluster and replacing config.db. For same-node restore, config.db is enough.
if [[ -f "$PVE_BACKUP/etc-pve.tar" ]] && [[ "${RESTORE_ETC_PVE_TAR:-0}" -eq 1 ]]; then
  log_info "RESTORE_ETC_PVE_TAR=1: extract etc-pve.tar over /etc/pve (use only if not using config.db)"
  if [[ "$(id -u)" -eq 0 ]]; then
    systemctl stop pve-cluster
    tar -C / -xf "$PVE_BACKUP/etc-pve.tar"
    systemctl start pve-cluster
  else
    sudo systemctl stop pve-cluster
    sudo tar -C / -xf "$PVE_BACKUP/etc-pve.tar"
    sudo systemctl start pve-cluster
  fi
fi

log_info "PVE config restore step complete."
