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
FROM_SNAPSHOT=""
SNAPSHOT_ROOT=""
ONLY_STEP=""
declare -a SKIP_STEPS=()

usage() {
  cat <<USAGE
Usage: $0 --from-snapshot <name> [options]

  Restore this Proxmox host from a snapshot (host config + PVE config).
  Run after a fresh Proxmox install. VM/CT configs are restored; VM disks
  must be reattached or restored from backup separately.

Options:
  --from-snapshot <name>  Snapshot name (directory under state/snapshots/)
  --snapshot-root <path>  Base directory where snapshots live (default: state/snapshots)
  --profile <name>       Profile name (default: default)
  --only-step <script>   Run only one restore script
  --skip-step <script>   Skip a script (repeatable)
  --dry-run              Print actions without executing
  -h, --help             Show this help
USAGE
}

require_arg() {
  local flag="$1"
  local value="${2:-}"
  [[ -n "$value" ]] || die "Missing value for $flag"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from-snapshot)
      require_arg "$1" "${2:-}"
      FROM_SNAPSHOT="$2"
      shift 2
      ;;
    --snapshot-root)
      require_arg "$1" "${2:-}"
      SNAPSHOT_ROOT="$2"
      shift 2
      ;;
    --profile)
      require_arg "$1" "${2:-}"
      PROFILE="$2"
      shift 2
      ;;
    --only-step)
      require_arg "$1" "${2:-}"
      ONLY_STEP="$2"
      shift 2
      ;;
    --skip-step)
      require_arg "$1" "${2:-}"
      SKIP_STEPS+=("$2")
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

[[ -n "$FROM_SNAPSHOT" ]] || die "You must pass --from-snapshot <name>"

SNAPSHOT_BASE_DIR="${SNAPSHOT_ROOT:-$ROOT_DIR/state/snapshots}"
RESTORE_SNAPSHOT_DIR="$SNAPSHOT_BASE_DIR/$FROM_SNAPSHOT"
export RESTORE_SNAPSHOT_DIR

[[ -d "$RESTORE_SNAPSHOT_DIR" ]] || die "Snapshot not found: $RESTORE_SNAPSHOT_DIR"

PROFILE_FILE="$ROOT_DIR/profiles/${PROFILE}.env"
[[ -f "$PROFILE_FILE" ]] && load_profile "$PROFILE_FILE"

export DRY_RUN
export PROFILE

mkdir -p "$ROOT_DIR/logs"
TIMESTAMP="$(date +%Y-%m-%d-%H%M%S)"
export RUN_LOG="$ROOT_DIR/logs/rebuild-${FROM_SNAPSHOT}-${TIMESTAMP}.log"

log_info "Restoring from snapshot: $FROM_SNAPSHOT"
log_info "Log file: $RUN_LOG"

RESTORE_STEPS=(
  "00-preflight.sh"
  "01-restore-host-config.sh"
  "02-restore-pve-config.sh"
  "03-validate.sh"
  "98-manual-checklist.sh"
)

is_skipped() {
  local step="$1"
  local item
  for item in "${SKIP_STEPS[@]:-}"; do
    [[ "$item" == "$step" ]] && return 0
  done
  return 1
}

run_step() {
  local step="$1"
  local path="$ROOT_DIR/scripts/restore/$step"
  [[ -f "$path" ]] || die "Missing step: $path"
  if [[ -n "$ONLY_STEP" && "$step" != "$ONLY_STEP" ]]; then
    return 0
  fi
  if is_skipped "$step"; then
    log_warn "Skipping step: $step"
    return 0
  fi
  log_section "Running $step"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "Dry run: would execute $path"
    return 0
  fi
  if ! bash "$path" 2>&1 | tee -a "$RUN_LOG"; then
    die "Step failed: $step"
  fi
}

for step in "${RESTORE_STEPS[@]}"; do
  run_step "$step"
done

log_section "Rebuild (restore) completed"
log_info "Review the manual checklist above. Reboot if you restored GRUB/kernel config."
