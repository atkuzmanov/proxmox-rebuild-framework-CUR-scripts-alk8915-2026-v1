#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROOT_DIR

# shellcheck source=lib/common.sh
source "$ROOT_DIR/lib/common.sh"
# shellcheck source=lib/logging.sh
source "$ROOT_DIR/lib/logging.sh"

PROFILE="${PROFILE:-default}"
DRY_RUN=0
SNAPSHOT_NAME=""
OUTPUT_DIR=""

usage() {
  cat <<USAGE
Usage: $0 [options]

  Take a snapshot of this Proxmox host: PVE config (VM/CT configs, storage,
  firewall), cluster DB, and host config (GRUB, modules, modprobe, network)
  for GPU passthrough and customisation. Does NOT include VM disks or large
  storage data.

Options:
  --profile <name>     Profile name (default: default)
  --name <snapshot>    Snapshot directory name (default: timestamp)
  --output-dir <path>  Base directory to write snapshots (default: state/snapshots)
  --dry-run            Print actions without executing
  -h, --help           Show this help
USAGE
}

require_arg() {
  local flag="$1"
  local value="${2:-}"
  [[ -n "$value" ]] || die "Missing value for $flag"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      require_arg "$1" "${2:-}"
      PROFILE="$2"
      shift 2
      ;;
    --name)
      require_arg "$1" "${2:-}"
      SNAPSHOT_NAME="$2"
      shift 2
      ;;
    --output-dir)
      require_arg "$1" "${2:-}"
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

export DRY_RUN
export PROFILE

# Optional profile file
PROFILE_FILE="$ROOT_DIR/profiles/${PROFILE}.env"
[[ -f "$PROFILE_FILE" ]] && load_profile "$PROFILE_FILE"

SNAPSHOT_BASE_DIR="${OUTPUT_DIR:-$ROOT_DIR/state/snapshots}"
ensure_dir "$SNAPSHOT_BASE_DIR"
SNAPSHOT_TIMESTAMP="${SNAPSHOT_NAME:-$(date +%Y-%m-%d-%H%M%S)}"
SNAPSHOT_DIR="$SNAPSHOT_BASE_DIR/$SNAPSHOT_TIMESTAMP"
export SNAPSHOT_DIR
export SNAPSHOT_TIMESTAMP

mkdir -p "$SNAPSHOT_DIR"
TIMESTAMP="$(date +%Y-%m-%d-%H%M%S)"
export RUN_LOG="$ROOT_DIR/logs/snapshot-${PROFILE}-${TIMESTAMP}.log"
mkdir -p "$ROOT_DIR/logs"

log_info "Snapshot target: $SNAPSHOT_DIR"
log_info "Log file: $RUN_LOG"

SNAPSHOT_STEPS=(
  "00-preflight.sh"
  "01-snapshot-pve-config.sh"
  "02-snapshot-host-config.sh"
  "03-snapshot-manifest.sh"
)

run_step() {
  local step="$1"
  local path="$ROOT_DIR/scripts/snapshot/$step"
  [[ -f "$path" ]] || die "Missing step: $path"
  log_section "Running $step"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "Dry run: would execute $path"
    return 0
  fi
  if ! bash "$path" 2>&1 | tee -a "$RUN_LOG"; then
    die "Step failed: $step"
  fi
}

for step in "${SNAPSHOT_STEPS[@]}"; do
  run_step "$step"
done

# If we ran with sudo, chown snapshot dir to the invoking user so they can use it without root
if [[ "$(id -u)" -eq 0 ]] && [[ -n "${SUDO_UID:-}" ]] && [[ -n "${SUDO_GID:-}" ]] && [[ "${DRY_RUN:-0}" -eq 0 ]]; then
  chown -R "${SUDO_UID}:${SUDO_GID}" "$SNAPSHOT_DIR"
  log_info "Snapshot directory ownership set to user (SUDO_UID/SUDO_GID)"
fi

log_section "Snapshot completed"
log_info "Snapshot saved to: $SNAPSHOT_DIR"
log_info "To restore: ./rebuild.sh --from-snapshot $SNAPSHOT_TIMESTAMP"
