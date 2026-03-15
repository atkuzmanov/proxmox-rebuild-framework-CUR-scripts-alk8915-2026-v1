#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT_DIR/lib/common.sh"

DEST="${SNAPSHOT_DIR:?SNAPSHOT_DIR not set}"
MANIFEST="$DEST/snapshot-manifest.txt"

log_section "Write snapshot manifest"

TIMESTAMP="${SNAPSHOT_TIMESTAMP:-$(date +%Y-%m-%d-%H%M%S)}"
HOSTNAME="$(hostname)"
PVE_VERSION=""
[[ -f /usr/bin/pveversion ]] && PVE_VERSION="$([[ "$(id -u)" -eq 0 ]] && pveversion || sudo pveversion)"
KERNEL="$(uname -r)"

{
  echo "snapshot_timestamp=$TIMESTAMP"
  echo "hostname=$HOSTNAME"
  echo "pve_version=$PVE_VERSION"
  echo "kernel=$KERNEL"
  echo "profile=${PROFILE:-default}"
  echo ""
  echo "# VM and CT IDs (see pve-config/lists/)"
  [[ -f "$DEST/pve-config/lists/qemu-server.txt" ]] && echo "qemu_server_ids=$(tr '\n' ' ' < "$DEST/pve-config/lists/qemu-server.txt")"
  [[ -f "$DEST/pve-config/lists/lxc.txt" ]] && echo "lxc_ids=$(tr '\n' ' ' < "$DEST/pve-config/lists/lxc.txt")"
} > "$MANIFEST"

log_info "Manifest written: $MANIFEST"
cat "$MANIFEST" | tee -a "${RUN_LOG:-/dev/null}"
