#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib/logging.sh
source "$ROOT_DIR/lib/logging.sh"

die() {
  log_error "$*"
  exit 1
}

require_command() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || die "Required command not found: $cmd"
}

run_cmd() {
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_info "Dry run: $*"
  else
    log_info "Running: $*"
    "$@"
  fi
}

run_cmd_sudo() {
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_info "Dry run (sudo): $*"
  else
    log_info "Running: sudo $*"
    sudo "$@"
  fi
}

load_profile() {
  local file="${1:-}"
  [[ -f "$file" ]] || return 0
  # shellcheck disable=SC1090
  source "$file"
}

ensure_dir() {
  local dir="$1"
  [[ -d "$dir" ]] || run_cmd mkdir -p "$dir"
}

is_true() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

want_feature() {
  local var_name="$1"
  local val="${!var_name:-false}"
  is_true "$val"
}
