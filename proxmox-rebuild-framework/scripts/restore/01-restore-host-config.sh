#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT_DIR/lib/common.sh"

SRC="${RESTORE_SNAPSHOT_DIR:?}/host-config"
[[ -d "$SRC" ]] || { log_warn "No host-config in snapshot, skipping host restore"; exit 0; }

log_section "Restore host configuration (GRUB, modules, modprobe, network)"

cp_file() {
  local from="$1"
  local to="$2"
  [[ -f "$from" ]] || return 0
  if [[ "$(id -u)" -eq 0 ]]; then
    run_cmd cp -a "$from" "$to"
  else
    run_cmd_sudo cp -a "$from" "$to"
  fi
}

cp_dir() {
  local from="$1"
  local to="$2"
  [[ -d "$from" ]] || return 0
  if [[ "$(id -u)" -eq 0 ]]; then
    run_cmd rm -rf "$to"
    run_cmd cp -a "$from" "$to"
  else
    run_cmd_sudo rm -rf "$to"
    run_cmd_sudo cp -a "$from" "$to"
  fi
}

# GRUB
[[ -f "$SRC/grub" ]] && cp_file "$SRC/grub" /etc/default/grub && log_info "Restored /etc/default/grub"
[[ -d "$SRC/grub.d" ]] && cp_dir "$SRC/grub.d" /etc/default/grub.d && log_info "Restored /etc/default/grub.d"

# Kernel modules
[[ -f "$SRC/modules" ]] && cp_file "$SRC/modules" /etc/modules && log_info "Restored /etc/modules"

# Modprobe
[[ -d "$SRC/modprobe.d" ]] && cp_dir "$SRC/modprobe.d" /etc/modprobe.d && log_info "Restored /etc/modprobe.d"

# Network
[[ -f "$SRC/network-interfaces" ]] && cp_file "$SRC/network-interfaces" /etc/network/interfaces && log_info "Restored /etc/network/interfaces"
[[ -d "$SRC/netplan" ]] && cp_dir "$SRC/netplan" /etc/netplan && log_info "Restored /etc/netplan"

# systemd
[[ -d "$SRC/systemd" ]] && cp_dir "$SRC/systemd" /etc/systemd && log_info "Restored /etc/systemd"

# ZFS config
[[ -d "$SRC/zfs" ]] && cp_dir "$SRC/zfs" /etc/zfs && log_info "Restored /etc/zfs"

# NUT (Network UPS Tools) config
[[ -d "$SRC/nut" ]] && cp_dir "$SRC/nut" /etc/nut && log_info "Restored /etc/nut"

# Initramfs modules
[[ -f "$SRC/initramfs-modules" ]] && cp_file "$SRC/initramfs-modules" /etc/initramfs-tools/modules && log_info "Restored /etc/initramfs-tools/modules"

if [[ "${RESTORE_ETC_ALL:-0}" -eq 1 ]] && [[ -f "$SRC/etc-full.tar.gz" ]]; then
  log_section "Restore full /etc (opt-in)"
  log_warn "RESTORE_ETC_ALL=1: extracting snapshot over /etc. This may overwrite host-specific files and secrets."
  if [[ "$(id -u)" -eq 0 ]]; then
    run_cmd tar -C /etc -xzf "$SRC/etc-full.tar.gz"
  else
    run_cmd_sudo tar -C /etc -xzf "$SRC/etc-full.tar.gz"
  fi
  log_info "Restored /etc from host-config/etc-full.tar.gz"
fi

if [[ "${DRY_RUN:-0}" -eq 0 ]]; then
  if command -v update-grub &>/dev/null; then
    log_info "Running update-grub"
    [[ "$(id -u)" -eq 0 ]] && update-grub || sudo update-grub
  fi
  if command -v update-initramfs &>/dev/null && [[ -f "$SRC/modules" || -d "$SRC/modprobe.d" ]]; then
    log_info "Running update-initramfs -u"
    [[ "$(id -u)" -eq 0 ]] && update-initramfs -u || sudo update-initramfs -u
  fi
fi

log_info "Host config restore complete. Reboot may be required for kernel/GRUB changes."
