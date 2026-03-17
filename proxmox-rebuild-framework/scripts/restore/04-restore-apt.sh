#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT_DIR/lib/common.sh"

SNAPSHOT_DIR="${RESTORE_SNAPSHOT_DIR:?RESTORE_SNAPSHOT_DIR not set}"
APT_DIR="$SNAPSHOT_DIR/apt"

[[ -d "$APT_DIR" ]] || { log_warn "No apt/ in snapshot, skipping APT restore"; exit 0; }

log_section "Restore APT packages (optional)"

# Guard: require explicit opt-in via profile/env
if ! want_feature RESTORE_APT_PACKAGES; then
  log_warn "RESTORE_APT_PACKAGES is not enabled in profile/env; skipping APT restore."
  exit 0
fi

require_command apt-get
require_command xargs

MANUAL_LIST="$APT_DIR/apt-manual-packages.txt"
[[ -f "$MANUAL_LIST" ]] || { log_warn "Missing $MANUAL_LIST; skipping APT restore"; exit 0; }

log_info "Reading manual packages list from $MANUAL_LIST"

# Basic filter: drop obviously core/system meta packages that Proxmox manages,
# and commented/empty lines. You can refine this by editing the file before restore.
FILTERED_LIST="$APT_DIR/apt-manual-packages-filtered.txt"

if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
  log_info "Dry run: would generate $FILTERED_LIST and run apt-get install"
  exit 0
fi

log_info "Generating filtered APT package list at $FILTERED_LIST"
grep -Ev '^(#|$)' "$MANUAL_LIST" | grep -Ev '^(proxmox-|pve-|linux-image-|linux-headers-|grub-|systemd|initramfs-tools|base-files|base-passwd|login|passwd|util-linux|ubuntu-|debian-|cloud-|snapd)$' > "$FILTERED_LIST" || true

if [[ ! -s "$FILTERED_LIST" ]]; then
  log_warn "Filtered package list is empty; nothing to install."
  exit 0
fi

log_info "Running apt-get update"
if [[ "$(id -u)" -eq 0 ]]; then
  run_cmd apt-get update
else
  run_cmd_sudo apt-get update
fi

log_info "Installing packages from $FILTERED_LIST (this may take a while)"
if [[ "$(id -u)" -eq 0 ]]; then
  xargs -a "$FILTERED_LIST" -r apt-get install -y
else
  run_cmd_sudo xargs -a "$FILTERED_LIST" -r apt-get install -y
fi

log_info "APT restore step complete (see $FILTERED_LIST for the installed set)"

