#!/usr/bin/env bash
SCENARIO_ID=25
SCENARIO_NAME="failed-exit-code"
SCENARIO_CATEGORY="pod"
SCENARIO_ISSUE_KIND="pod_failed"
SCENARIO_DESCRIPTION="Standalone pod exits with non-zero code (exit 42), restartPolicy: Never"
SCENARIO_FIXABLE="no"
SCENARIO_DETECT_ONLY="yes"
SCENARIO_EXPECTED_FIX=""

scenario_inject() {
  local ns=$1
  kubectl apply --context="$KUBEBENCH_CONTEXT" -n "$ns" -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: fail-pod
  labels:
    app: fail-pod
spec:
  restartPolicy: Never
  containers:
    - name: fail-pod
      image: busybox:1.36
      command: ["sh", "-c", "echo done; exit 42"]
EOF
}

scenario_precondition() {
  local ns=$1
  kubectl get pods --context="$KUBEBENCH_CONTEXT" -n "$ns" -o json \
    | jq -e '.items[] | select(.status.phase == "Failed")' >/dev/null 2>&1
}

scenario_postcondition() { return 1; }
