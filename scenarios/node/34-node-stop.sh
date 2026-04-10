#!/usr/bin/env bash
SCENARIO_ID=34
SCENARIO_NAME="node-stop"
SCENARIO_CATEGORY="node"
SCENARIO_ISSUE_KIND="node_not_ready"
SCENARIO_DESCRIPTION="Stop a k3d agent node to trigger NotReady"
SCENARIO_FIXABLE="no"
SCENARIO_DETECT_ONLY="yes"
SCENARIO_EXPECTED_FIX=""

scenario_inject() {
  local ns=$1
  if [ "$PROVIDER" = "k3d" ]; then
    k3d node stop "${CLUSTER_NAME}-agent-1" 2>/dev/null || true
  elif [ "$PROVIDER" = "kind" ]; then
    docker stop "${CLUSTER_NAME}-worker2" 2>/dev/null || true
  fi
}

scenario_precondition() {
  local ns=$1
  kubectl get nodes --context="$KUBEBENCH_CONTEXT" --no-headers 2>/dev/null \
    | grep -q "NotReady"
}

scenario_postcondition() { return 1; }

scenario_cleanup() {
  if [ "$PROVIDER" = "k3d" ]; then
    k3d node start "${CLUSTER_NAME}-agent-1" 2>/dev/null || true
  elif [ "$PROVIDER" = "kind" ]; then
    docker start "${CLUSTER_NAME}-worker2" 2>/dev/null || true
  fi
  sleep 15
}
