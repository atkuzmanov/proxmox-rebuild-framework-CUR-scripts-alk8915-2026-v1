#!/usr/bin/env bash

log_ts() {
  date '+%Y-%m-%d %H:%M:%S'
}

log_info() {
  echo "[$(log_ts)] [INFO] $*" | tee -a "${RUN_LOG:-/dev/null}"
}

log_warn() {
  echo "[$(log_ts)] [WARN] $*" | tee -a "${RUN_LOG:-/dev/null}"
}

log_error() {
  echo "[$(log_ts)] [ERROR] $*" | tee -a "${RUN_LOG:-/dev/null}" >&2
}

log_section() {
  printf '\n[%s] [SECTION] ===== %s =====\n' "$(log_ts)" "$*" | tee -a "${RUN_LOG:-/dev/null}"
}
