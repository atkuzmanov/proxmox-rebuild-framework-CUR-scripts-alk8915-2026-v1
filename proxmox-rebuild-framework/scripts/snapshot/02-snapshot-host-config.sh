#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT_DIR/lib/common.sh"

DEST="${SNAPSHOT_DIR:?SNAPSHOT_DIR not set}"
HOST_BACKUP="$DEST/host-config"

log_section "Snapshot host configuration (GPU passthrough, kernel, network)"

ensure_dir "$HOST_BACKUP"

copy_sudo() {
  local src="$1"
  local dest="$2"
  if [[ -e "$src" ]]; then
    if [[ "$(id -u)" -eq 0 ]]; then
      run_cmd cp -a "$src" "$dest"
    else
      run_cmd_sudo cp -a "$src" "$dest"
    fi
  fi
}

# GRUB (IOMMU, GPU passthrough kernel params)
if [[ -f /etc/default/grub ]]; then
  copy_sudo /etc/default/grub "$HOST_BACKUP/grub"
  log_info "Backed up /etc/default/grub"
fi
if [[ -d /etc/default/grub.d ]]; then
  if [[ "$(id -u)" -eq 0 ]]; then
    run_cmd cp -a /etc/default/grub.d "$HOST_BACKUP/grub.d"
  else
    run_cmd_sudo cp -a /etc/default/grub.d "$HOST_BACKUP/grub.d"
  fi
  log_info "Backed up /etc/default/grub.d"
fi

# Kernel modules (vfio, etc.)
if [[ -f /etc/modules ]]; then
  copy_sudo /etc/modules "$HOST_BACKUP/modules"
  log_info "Backed up /etc/modules"
fi

# Modprobe configs (vfio-pci ids, blacklist, kvm)
if [[ -d /etc/modprobe.d ]]; then
  if [[ "$(id -u)" -eq 0 ]]; then
    run_cmd cp -a /etc/modprobe.d "$HOST_BACKUP/modprobe.d"
  else
    run_cmd_sudo cp -a /etc/modprobe.d "$HOST_BACKUP/modprobe.d"
  fi
  log_info "Backed up /etc/modprobe.d"
fi

# Network (interfaces or netplan)
if [[ -f /etc/network/interfaces ]]; then
  copy_sudo /etc/network/interfaces "$HOST_BACKUP/network-interfaces"
  log_info "Backed up /etc/network/interfaces"
fi
if [[ -d /etc/netplan ]]; then
  if [[ "$(id -u)" -eq 0 ]]; then
    run_cmd cp -a /etc/netplan "$HOST_BACKUP/netplan"
  else
    run_cmd_sudo cp -a /etc/netplan "$HOST_BACKUP/netplan"
  fi
  log_info "Backed up /etc/netplan"
fi

# systemd (units, drop-ins, networkd configs, etc.)
if [[ -d /etc/systemd ]]; then
  if [[ "$(id -u)" -eq 0 ]]; then
    run_cmd cp -a /etc/systemd "$HOST_BACKUP/systemd"
  else
    run_cmd_sudo cp -a /etc/systemd "$HOST_BACKUP/systemd"
  fi
  log_info "Backed up /etc/systemd"
fi

# ZFS configuration (import behavior, ZED notifications, etc.)
if [[ -d /etc/zfs ]]; then
  if [[ "$(id -u)" -eq 0 ]]; then
    run_cmd cp -a /etc/zfs "$HOST_BACKUP/zfs"
  else
    run_cmd_sudo cp -a /etc/zfs "$HOST_BACKUP/zfs"
  fi
  log_info "Backed up /etc/zfs"
fi

# Optional: initramfs modules (some GPU passthrough setups use /etc/initramfs-tools/modules)
if [[ -f /etc/initramfs-tools/modules ]]; then
  copy_sudo /etc/initramfs-tools/modules "$HOST_BACKUP/initramfs-modules"
  log_info "Backed up /etc/initramfs-tools/modules"
fi

log_info "Host config snapshot complete"

# Optional: full /etc snapshot (can contain secrets; disabled by default)
if [[ "${SNAPSHOT_ETC_ALL:-0}" -eq 1 ]]; then
  log_section "Snapshot full /etc (opt-in)"
  ETC_TAR="$HOST_BACKUP/etc-full.tar.gz"
  # Exclude volatile/runtime mounts and Proxmox cluster fs view (we already snapshot PVE via config.db)
  # Note: /etc/pve is a FUSE-like view; including it inside a full /etc tar is usually unnecessary/noisy.
  TAR_EXCLUDES=(
    --exclude='./pve'
    --exclude='./mtab'
    --exclude='./resolv.conf'
    --exclude='./hosts'
    --exclude='./hostname'
    --exclude='./machine-id'
  )

  if [[ "$(id -u)" -eq 0 ]]; then
    run_cmd tar -C /etc -czf "$ETC_TAR" "${TAR_EXCLUDES[@]}" . 2>/dev/null || true
  else
    run_cmd_sudo tar -C /etc -czf "$ETC_TAR" "${TAR_EXCLUDES[@]}" . 2>/dev/null || true
  fi
  log_info "Backed up full /etc to host-config/etc-full.tar.gz (SNAPSHOT_ETC_ALL=1)"
fi
