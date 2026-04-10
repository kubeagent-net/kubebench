#!/usr/bin/env bash
SCENARIO_ID=33
SCENARIO_NAME="error-security-context"
SCENARIO_CATEGORY="pod"
SCENARIO_ISSUE_KIND="pod_error"
SCENARIO_DESCRIPTION="Pod security context requires runAsNonRoot but specifies runAsUser: 0, causing container rejection"
SCENARIO_FIXABLE="no"
SCENARIO_DETECT_ONLY="yes"
SCENARIO_EXPECTED_FIX=""

scenario_inject() {
  local ns=$1
  kubectl apply --context="$KUBEBENCH_CONTEXT" -n "$ns" -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sec-ctx-fail
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sec-ctx-fail
  template:
    metadata:
      labels:
        app: sec-ctx-fail
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 0
      containers:
        - name: sec-ctx-fail
          image: nginx:1.27-alpine
EOF
}

scenario_precondition() {
  local ns=$1
  # Broad check: CreateContainerError, CrashLoopBackOff, or pod not Running/not ready
  kubectl get pods --context="$KUBEBENCH_CONTEXT" -n "$ns" -l app=sec-ctx-fail -o json \
    | jq -e '
      .items[] |
      (
        (.status.containerStatuses[]? | select(
          .state.waiting.reason == "CreateContainerError" or
          .state.waiting.reason == "CrashLoopBackOff"
        ))
        // select(.status.phase != "Running")
        // (.status.conditions[]? | select(.type == "Ready" and .status == "False"))
      )
    ' >/dev/null 2>&1
}

scenario_postcondition() { return 1; }
