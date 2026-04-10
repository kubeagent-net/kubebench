#!/usr/bin/env bash
# kubebench — Kubernetes Fault Injection Benchmark
# Test any K8s monitoring/remediation agent against 50 real fault scenarios
set -euo pipefail

KUBEBENCH_VERSION="0.1.0"
KUBEBENCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Defaults
PROVIDER="${KUBEBENCH_PROVIDER:-k3d}"
AGENT="${KUBEBENCH_AGENT:-kubeagent}"
CLUSTER_NAME="${KUBEBENCH_CLUSTER:-kubebench}"
PRECONDITION_TIMEOUT=90
POSTCONDITION_TIMEOUT=300
AGENT_INTERVAL=15
REPORT_DIR="${KUBEBENCH_DIR}/reports/$(date +%Y%m%d-%H%M%S)"
KEEP_CLUSTER=false
DETECT_ONLY=false
VERBOSE=false
SCENARIO_FILTER=""
CATEGORY_FILTER=""
EXISTING_CONTEXT=""

usage() {
  cat <<EOF
kubebench v${KUBEBENCH_VERSION} — Kubernetes Fault Injection Benchmark

Usage: kubebench.sh [OPTIONS]

Options:
  --provider k3d|kind           Cluster provider (default: k3d)
  --agent kubeagent|manual      Agent to test (default: kubeagent)
  --scenario N|N-M              Run scenario N, or range N-M
  --category CATEGORY           Filter by: pod, node, job, deploy, multi
  --detect-only                 Only verify detection, skip fix verification
  --precondition-timeout SEC    Wait for issue to manifest (default: 90)
  --postcondition-timeout SEC   Wait for agent to fix (default: 300)
  --agent-interval SEC          Agent poll interval in seconds (default: 15)
  --cluster-name NAME           Cluster name (default: kubebench)
  --keep-cluster                Don't delete cluster after run
  --report-dir DIR              Report output directory
  --context CONTEXT              Use existing cluster (skip create/delete)
  --verbose                     Verbose output
  -h, --help                    Show this help

Environment:
  KUBEAGENT_BIN                 Path to kubeagent binary (for kubeagent agent)
  KUBEBENCH_PROVIDER            Override --provider
  KUBEBENCH_AGENT               Override --agent
  KUBEBENCH_CLUSTER             Override --cluster-name

Examples:
  ./kubebench.sh                                # Full benchmark with kubeagent
  ./kubebench.sh --agent manual --keep-cluster  # Inject faults only, keep cluster
  ./kubebench.sh --scenario 9-12                # Run OOM scenarios only
  ./kubebench.sh --category pod --detect-only   # Detection-only for pod scenarios
  ./kubebench.sh --provider kind                # Use kind instead of k3d
  ./kubebench.sh --context my-cluster           # Use an existing cluster
EOF
  exit 0
}

# Parse arguments
while [ $# -gt 0 ]; do
  case "$1" in
    --provider) PROVIDER="$2"; shift 2 ;;
    --agent) AGENT="$2"; shift 2 ;;
    --scenario) SCENARIO_FILTER="$2"; shift 2 ;;
    --category) CATEGORY_FILTER="$2"; shift 2 ;;
    --detect-only) DETECT_ONLY=true; shift ;;
    --precondition-timeout) PRECONDITION_TIMEOUT="$2"; shift 2 ;;
    --postcondition-timeout) POSTCONDITION_TIMEOUT="$2"; shift 2 ;;
    --agent-interval) AGENT_INTERVAL="$2"; shift 2 ;;
    --cluster-name) CLUSTER_NAME="$2"; shift 2 ;;
    --keep-cluster) KEEP_CLUSTER=true; shift ;;
    --context) EXISTING_CONTEXT="$2"; shift 2 ;;
    --report-dir) REPORT_DIR="$2"; shift 2 ;;
    --verbose) VERBOSE=true; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

export PROVIDER AGENT CLUSTER_NAME PRECONDITION_TIMEOUT POSTCONDITION_TIMEOUT
export AGENT_INTERVAL REPORT_DIR KEEP_CLUSTER DETECT_ONLY VERBOSE KUBEBENCH_DIR
export EXISTING_CONTEXT

# Source libraries
source "${KUBEBENCH_DIR}/lib/util.sh"
source "${KUBEBENCH_DIR}/lib/cluster.sh"
source "${KUBEBENCH_DIR}/lib/runner.sh"
source "${KUBEBENCH_DIR}/lib/report.sh"

# Source agent adapter
AGENT_FILE="${KUBEBENCH_DIR}/agents/${AGENT}.sh"
if [ ! -f "$AGENT_FILE" ]; then
  log_error "Unknown agent: ${AGENT} (no file: ${AGENT_FILE})"
  exit 1
fi
source "$AGENT_FILE"

# Check prerequisites
log_info "kubebench v${KUBEBENCH_VERSION}"
require_cmd kubectl
require_cmd jq
if [ -z "$EXISTING_CONTEXT" ]; then
  require_cmd docker
  require_cmd "$PROVIDER"
fi

# Collect scenarios
collect_scenarios() {
  local -a files=()
  for f in "${KUBEBENCH_DIR}"/scenarios/*/*.sh; do
    [ -f "$f" ] || continue
    files+=("$f")
  done

  # Sort by scenario ID extracted from filename (NN-name.sh)
  IFS=$'\n' files=($(printf '%s\n' "${files[@]}" | sort -t/ -k2 -V)); unset IFS

  # Apply filters
  local -a filtered=()
  for f in "${files[@]}"; do
    local basename
    basename=$(basename "$f")
    local id
    id=$(echo "$basename" | grep -o '^[0-9]*' || echo "0")

    # Category filter
    if [ -n "$CATEGORY_FILTER" ]; then
      local dir
      dir=$(basename "$(dirname "$f")")
      if [[ "$dir" != "$CATEGORY_FILTER"* ]]; then
        continue
      fi
    fi

    # Scenario filter (single number or range N-M)
    if [ -n "$SCENARIO_FILTER" ]; then
      if [[ "$SCENARIO_FILTER" == *-* ]]; then
        local lo hi
        lo=$(echo "$SCENARIO_FILTER" | cut -d- -f1)
        hi=$(echo "$SCENARIO_FILTER" | cut -d- -f2)
        if [ "$id" -lt "$lo" ] || [ "$id" -gt "$hi" ]; then
          continue
        fi
      else
        if [ "$id" -ne "$SCENARIO_FILTER" ]; then
          continue
        fi
      fi
    fi

    filtered+=("$f")
  done

  printf '%s\n' "${filtered[@]}"
}

# Cleanup handler
cleanup_on_exit() {
  agent_stop 2>/dev/null || true
  if [ -z "$EXISTING_CONTEXT" ] && [ "$KEEP_CLUSTER" = "false" ]; then
    cluster_delete 2>/dev/null || true
  else
    log_info "Cluster kept: kubectl --context=${KUBEBENCH_CONTEXT:-unknown}"
  fi
}
trap cleanup_on_exit EXIT

# --- Main flow ---
main_start=$(date +%s)

mkdir -p "$REPORT_DIR"
touch "$REPORT_DIR/agent-output.log"

echo ""
echo -e "${BOLD}  kubebench v${KUBEBENCH_VERSION}${NC}"
echo -e "  Provider: ${PROVIDER} | Agent: ${AGENT} | Cluster: ${CLUSTER_NAME}"
echo ""

# 1. Create cluster (or use existing)
if [ -n "$EXISTING_CONTEXT" ]; then
  KUBEBENCH_CONTEXT="$EXISTING_CONTEXT"
  export KUBEBENCH_CONTEXT
  log_ok "Using existing cluster context: ${KUBEBENCH_CONTEXT}"
  # Verify context works
  if ! kubectl cluster-info --context="$KUBEBENCH_CONTEXT" &>/dev/null; then
    log_error "Cannot connect to cluster context: $KUBEBENCH_CONTEXT"
    exit 1
  fi
  # Still build fixture images if docker is available
  if command -v docker &>/dev/null; then
    cluster_build_images
  fi
else
  cluster_create
  cluster_wait_ready
  cluster_build_images
fi

# 2. Set up agent
agent_setup

# 3. Collect scenarios
mapfile -t scenarios < <(collect_scenarios)
if [ ${#scenarios[@]} -eq 0 ]; then
  log_error "No scenarios found matching filters"
  exit 1
fi
log_info "Running ${#scenarios[@]} scenario(s)..."
echo ""

# 4. Start agent
agent_start

# 5. Run scenarios
runner_execute_all "${scenarios[@]}"

# 6. Stop agent
agent_stop

# 7. Generate report
total_duration=$(elapsed "$main_start")
report_generate "$total_duration"
