#!/usr/bin/env bash
# lib/util.sh — shared helpers for kubebench

# Colors (disabled if not a terminal)
if [ -t 1 ]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  BLUE='\033[0;34m'; DIM='\033[2m'; BOLD='\033[1m'; NC='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; DIM=''; BOLD=''; NC=''
fi

log_info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_dim()   { echo -e "${DIM}$*${NC}"; }

# Timestamp in ISO 8601
now_iso() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# Elapsed seconds since $1 (epoch seconds)
elapsed() { echo $(( $(date +%s) - $1 )); }

# Wait for a condition function to return 0, with timeout
# Usage: wait_for <timeout_seconds> <poll_interval> <function> [args...]
# Returns 0 if condition met, 1 if timeout
wait_for() {
  local timeout=$1 interval=$2; shift 2
  local deadline=$(( $(date +%s) + timeout ))
  while [ "$(date +%s)" -lt "$deadline" ]; do
    if "$@" 2>/dev/null; then
      return 0
    fi
    sleep "$interval"
  done
  return 1
}

# Format seconds as human-readable duration
format_duration() {
  local s=$1
  if [ "$s" -ge 3600 ]; then
    printf "%dh %dm %ds" $((s/3600)) $((s%3600/60)) $((s%60))
  elif [ "$s" -ge 60 ]; then
    printf "%dm %ds" $((s/60)) $((s%60))
  else
    printf "%ds" "$s"
  fi
}

# Check that a command exists
require_cmd() {
  local cmd=$1
  if ! command -v "$cmd" &>/dev/null; then
    log_error "Required command not found: $cmd"
    return 1
  fi
}
