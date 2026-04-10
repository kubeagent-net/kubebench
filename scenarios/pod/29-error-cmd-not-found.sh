#!/usr/bin/env bash
SCENARIO_ID=29
SCENARIO_NAME="error-cmd-not-found"
SCENARIO_CATEGORY="pod"
SCENARIO_ISSUE_KIND="pod_error"
SCENARIO_DESCRIPTION="Deployment runs a non-existent binary, causing CrashLoopBackOff"
SCENARIO_FIXABLE="yes"
SCENARIO_DETECT_ONLY="no"
SCENARIO_EXPECTED_FIX="rollout_restart"

scenario_inject() {
  local ns=$1
  kubectl apply --context="$KUBEBENCH_CONTEXT" -n "$ns" -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bad-cmd
spec:
  replicas: 1
  selector:
    matchLabels:
      app: bad-cmd
  template:
    metadata:
      labels:
        app: bad-cmd
    spec:
      containers:
        - name: bad-cmd
          image: busybox:1.36
          command: ["nonexistent-binary", "--flag"]
EOF
}

scenario_precondition() {
  local ns=$1
  kubectl get pods --context="$KUBEBENCH_CONTEXT" -n "$ns" -o json \
    | jq -e '.items[] | .status.containerStatuses[]? | select(.state.waiting.reason == "CrashLoopBackOff" or .state.terminated.reason == "Error")' >/dev/null 2>&1
}

scenario_postcondition() {
  local ns=$1
  local ready
  ready=$(kubectl get pods --context="$KUBEBENCH_CONTEXT" -n "$ns" -l app=bad-cmd -o json \
    | jq '[.items[] | select(.status.phase == "Running") | .status.conditions[]? | select(.type == "Ready" and .status == "True")] | length')
  [ "$ready" -gt 0 ]
}
