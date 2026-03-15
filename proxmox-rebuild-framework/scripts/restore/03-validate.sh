#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT_DIR/lib/common.sh"

log_section "Validation"

checks=0
fails=0

check() {
  local msg="$1"
  if eval "$2"; then
    log_info "OK: $msg"
    (( checks++ )) || true
  else
    log_error "FAIL: $msg"
    (( checks++ )) || true
    (( fails++ )) || true
  fi
}

check "/etc/pve exists" "[[ -d /etc/pve ]]"
_check_cluster() {
  if [[ "$(id -u)" -eq 0 ]]; then systemctl is-active -q pve-cluster 2>/dev/null; else sudo systemctl is-active -q pve-cluster 2>/dev/null; fi
}
check "pve-cluster running" "_check_cluster"
check "storage.cfg present" "[[ -f /etc/pve/storage.cfg ]]"

if [[ $fails -gt 0 ]]; then
  log_warn "Some checks failed ($fails). Review and fix if needed."
else
  log_info "All $checks checks passed."
fi
