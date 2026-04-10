#!/usr/bin/env bash
# lib/report.sh — JSON + terminal reporting

report_generate() {
  local total_duration=$1

  mkdir -p "$REPORT_DIR"

  # Build JSON report
  local summary
  summary=$(echo "$RESULTS_JSON" | jq '{
    total: length,
    precondition_met: [.[] | select(.result != "precondition_failed" and .result != "error" and .result != "skipped")] | length,
    precondition_failed: [.[] | select(.result == "precondition_failed")] | length,
    fixed: [.[] | select(.result == "fixed")] | length,
    detected: [.[] | select(.result == "detected")] | length,
    unfixed: [.[] | select(.result == "unfixed")] | length,
    errors: [.[] | select(.result == "error")] | length,
    avg_precondition_time_s: ([.[] | select(.precondition_time_s > 0) | .precondition_time_s] | if length > 0 then (add / length | floor) else 0 end),
    avg_fix_time_s: ([.[] | select(.fix_time_s > 0 and .result == "fixed") | .fix_time_s] | if length > 0 then (add / length | floor) else 0 end)
  }')

  local report
  report=$(jq -n \
    --argjson summary "$summary" \
    --argjson scenarios "$RESULTS_JSON" \
    --arg timestamp "$(now_iso)" \
    --arg provider "$PROVIDER" \
    --arg agent "$(agent_name)" \
    --arg cluster "$CLUSTER_NAME" \
    --argjson pre_timeout "$PRECONDITION_TIMEOUT" \
    --argjson post_timeout "$POSTCONDITION_TIMEOUT" \
    --argjson detect_only "$( [ "$DETECT_ONLY" = "true" ] && echo true || echo false )" \
    --argjson duration "$total_duration" \
    '{
      meta: {
        timestamp: $timestamp,
        kubebench_version: "0.1.0",
        provider: $provider,
        agent: $agent,
        cluster_name: $cluster,
        precondition_timeout_s: $pre_timeout,
        postcondition_timeout_s: $post_timeout,
        detect_only_mode: $detect_only,
        total_duration_s: $duration
      },
      summary: $summary,
      scenarios: $scenarios
    }')

  echo "$report" > "$REPORT_DIR/report.json"

  # Terminal summary
  local total detected fixed unfixed pre_fail errors avg_fix
  total=$(echo "$summary" | jq '.total')
  detected=$(echo "$summary" | jq '.precondition_met')
  fixed=$(echo "$summary" | jq '.fixed')
  unfixed=$(echo "$summary" | jq '.unfixed')
  pre_fail=$(echo "$summary" | jq '.precondition_failed')
  errors=$(echo "$summary" | jq '.errors')
  avg_fix=$(echo "$summary" | jq '.avg_fix_time_s')

  local detect_only_count
  detect_only_count=$(echo "$RESULTS_JSON" | jq '[.[] | select(.result == "detected")] | length')
  local fixable_total fixable_fixed
  fixable_total=$(echo "$RESULTS_JSON" | jq '[.[] | select(.fixable == "yes" and .result != "precondition_failed" and .result != "error")] | length')
  fixable_fixed=$(echo "$RESULTS_JSON" | jq '[.[] | select(.fixable == "yes" and .result == "fixed")] | length')

  echo ""
  echo -e "${BOLD}================================================================${NC}"
  echo -e "${BOLD}  KUBEBENCH RESULTS${NC}"
  echo -e "  Agent: ${BOLD}$(agent_name)${NC} | Provider: ${PROVIDER}"
  echo -e "  Date: $(date +%Y-%m-%d) | Duration: $(format_duration "$total_duration")"
  echo -e "${BOLD}================================================================${NC}"
  echo ""
  echo -e "  Detection:          ${BOLD}${detected}/${total}${NC}"
  echo -e "  Fixed:              ${GREEN}${fixed}${NC}/${total}"
  echo -e "  Unfixed:            ${RED}${unfixed}${NC}"
  echo -e "  Detect-only:        ${BLUE}${detect_only_count}${NC}"
  if [ "$pre_fail" -gt 0 ]; then
    echo -e "  Precondition fail:  ${YELLOW}${pre_fail}${NC}"
  fi
  if [ "$errors" -gt 0 ]; then
    echo -e "  Errors:             ${RED}${errors}${NC}"
  fi
  echo ""
  if [ "$fixable_total" -gt 0 ]; then
    echo -e "  Fixable scenarios:  ${GREEN}${fixable_fixed}/${fixable_total}${NC} fixed"
  fi
  echo -e "  Avg fix time:       ${avg_fix}s"
  echo ""

  # Per-category breakdown
  echo -e "  ${DIM}By category:${NC}"
  echo "$RESULTS_JSON" | jq -r '
    group_by(.category) | sort_by(.[0].id) | .[] |
    (.[0].category) as $cat |
    (length) as $total |
    ([.[] | select(.result == "fixed")] | length) as $fixed |
    ([.[] | select(.result != "precondition_failed" and .result != "error")] | length) as $detected |
    "    \($cat)\(" " * (20 - ($cat | length)))  \($detected)/\($total) detected  \($fixed)/\($total) fixed"
  '

  echo ""
  echo -e "  Full report: ${BOLD}${REPORT_DIR}/report.json${NC}"
  echo -e "  Scenario logs: ${BOLD}${REPORT_DIR}/logs/${NC}"
  echo -e "${BOLD}================================================================${NC}"
  echo ""
}
