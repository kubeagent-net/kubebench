#!/usr/bin/env bash
# lib/runner.sh — scenario execution loop

# Global results array (each entry is a JSON object)
RESULTS_JSON="[]"

runner_execute_all() {
  local -a scenario_files=("$@")
  local total=${#scenario_files[@]}
  local num=0

  for scenario_file in "${scenario_files[@]}"; do
    num=$((num + 1))
    runner_execute_one "$scenario_file" "$num" "$total"
    # Brief pause between scenarios for cluster to settle
    sleep 3
  done
}

runner_execute_one() {
  local scenario_file=$1 num=$2 total=$3

  # Reset scenario variables
  local SCENARIO_ID="" SCENARIO_NAME="" SCENARIO_CATEGORY=""
  local SCENARIO_ISSUE_KIND="" SCENARIO_DESCRIPTION=""
  local SCENARIO_FIXABLE="no" SCENARIO_EXPECTED_FIX=""
  local SCENARIO_DETECT_ONLY="no"

  # Source the scenario to load metadata and functions
  # shellcheck disable=SC1090
  source "$scenario_file"

  if [ -z "$SCENARIO_ID" ] || [ -z "$SCENARIO_NAME" ]; then
    log_error "Scenario file missing SCENARIO_ID or SCENARIO_NAME: $scenario_file"
    return
  fi

  local ns="kubebench-s$(printf '%02d' "$SCENARIO_ID")"
  local label
  label=$(printf "[%2d/%d]" "$num" "$total")

  # Pad scenario name for alignment
  local name_display="$SCENARIO_NAME"
  local pad_len=$(( 40 - ${#name_display} ))
  if [ "$pad_len" -lt 1 ]; then pad_len=1; fi
  local dots
  dots=$(printf '%*s' "$pad_len" '' | tr ' ' '.')

  # Capture agent log start position
  local log_offset=0
  if [ -f "$REPORT_DIR/agent-output.log" ]; then
    log_offset=$(wc -c < "$REPORT_DIR/agent-output.log" | tr -d ' ')
  fi

  # Create namespace
  kubectl create namespace "$ns" --context="$KUBEBENCH_CONTEXT" --dry-run=client -o yaml \
    | kubectl apply --context="$KUBEBENCH_CONTEXT" -f - >/dev/null 2>&1

  local start_time result_status precondition_time=-1 fix_time=-1
  start_time=$(date +%s)

  # --- Inject ---
  if ! scenario_inject "$ns" 2>/dev/null; then
    printf "  %s %s %s ${RED}INJECT FAILED${NC}\n" "$label" "$name_display" "$dots"
    result_status="error"
    runner_record_result "$result_status" "$precondition_time" "$fix_time"
    runner_cleanup "$ns" "$log_offset"
    return
  fi

  # --- Precondition: wait for issue to manifest ---
  local pre_start
  pre_start=$(date +%s)
  if wait_for "$PRECONDITION_TIMEOUT" 3 scenario_precondition "$ns"; then
    precondition_time=$(elapsed "$pre_start")
  else
    printf "  %s %s %s ${YELLOW}PRECONDITION FAILED${NC} (%ss)\n" \
      "$label" "$name_display" "$dots" "$PRECONDITION_TIMEOUT"
    result_status="precondition_failed"
    runner_record_result "$result_status" "$precondition_time" "$fix_time"
    runner_cleanup "$ns" "$log_offset"
    return
  fi

  # --- Detect-only mode ---
  if [ "$DETECT_ONLY" = "true" ] || [ "$SCENARIO_DETECT_ONLY" = "yes" ]; then
    printf "  %s %s %s ${BLUE}DETECTED${NC} (%ss)\n" \
      "$label" "$name_display" "$dots" "$precondition_time"
    result_status="detected"
    runner_record_result "$result_status" "$precondition_time" "$fix_time"
    runner_cleanup "$ns" "$log_offset"
    return
  fi

  # --- Postcondition: wait for agent to fix ---
  local fix_start
  fix_start=$(date +%s)
  if wait_for "$POSTCONDITION_TIMEOUT" 5 scenario_postcondition "$ns"; then
    fix_time=$(elapsed "$fix_start")
    printf "  %s %s %s ${GREEN}FIXED${NC} (%ss)\n" \
      "$label" "$name_display" "$dots" "$fix_time"
    result_status="fixed"
  else
    fix_time=$(elapsed "$fix_start")
    printf "  %s %s %s ${RED}UNFIXED${NC} (%ss timeout)\n" \
      "$label" "$name_display" "$dots" "$POSTCONDITION_TIMEOUT"
    result_status="unfixed"
  fi

  runner_record_result "$result_status" "$precondition_time" "$fix_time"
  runner_cleanup "$ns" "$log_offset"
}

runner_record_result() {
  local status=$1 pre_time=$2 fix_time=$3

  # Escape description for JSON
  local escaped_desc
  escaped_desc=$(echo "$SCENARIO_DESCRIPTION" | sed 's/"/\\"/g')

  local entry
  entry=$(cat <<JSONEOF
{
  "id": ${SCENARIO_ID},
  "name": "${SCENARIO_NAME}",
  "category": "${SCENARIO_CATEGORY}",
  "issue_kind": "${SCENARIO_ISSUE_KIND}",
  "description": "${escaped_desc}",
  "fixable": "${SCENARIO_FIXABLE}",
  "expected_fix": "${SCENARIO_EXPECTED_FIX}",
  "result": "${status}",
  "precondition_time_s": ${pre_time},
  "fix_time_s": ${fix_time}
}
JSONEOF
)
  RESULTS_JSON=$(echo "$RESULTS_JSON" | jq --argjson e "$entry" '. + [$e]')
}

runner_cleanup() {
  local ns=$1 log_offset=$2

  # Extract per-scenario agent log
  if [ -f "$REPORT_DIR/agent-output.log" ]; then
    local current_size
    current_size=$(wc -c < "$REPORT_DIR/agent-output.log" | tr -d ' ')
    if [ "$current_size" -gt "$log_offset" ]; then
      mkdir -p "$REPORT_DIR/logs"
      tail -c "+$((log_offset + 1))" "$REPORT_DIR/agent-output.log" \
        > "$REPORT_DIR/logs/scenario-$(printf '%02d' "$SCENARIO_ID").log" 2>/dev/null || true
    fi
  fi

  # Optional scenario-specific cleanup
  if declare -f scenario_cleanup &>/dev/null; then
    scenario_cleanup "$ns" 2>/dev/null || true
  fi

  # Delete namespace (background, don't wait)
  kubectl delete namespace "$ns" --context="$KUBEBENCH_CONTEXT" \
    --wait=false --ignore-not-found >/dev/null 2>&1 || true

  # Unset scenario functions so they don't leak into the next scenario
  unset -f scenario_inject scenario_precondition scenario_postcondition scenario_cleanup 2>/dev/null || true
}
