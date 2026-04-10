#!/usr/bin/env bash
SCENARIO_ID=27
SCENARIO_NAME="failed-init-never"
SCENARIO_CATEGORY="pod"
SCENARIO_ISSUE_KIND="pod_failed"
SCENARIO_DESCRIPTION="Init container exits with error, restartPolicy: Never prevents retry"
SCENARIO_FIXABLE="no"
SCENARIO_DETECT_ONLY="yes"
SCENARIO_EXPECTED_FIX=""

scenario_inject() {
  local ns=$1
  kubectl apply --context="$KUBEBENCH_CONTEXT" -n "$ns" -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: init-fail-pod
  labels:
    app: init-fail-pod
spec:
  restartPolicy: Never
  initContainers:
    - name: bad-init
      image: busybox:1.36
      command: ["sh", "-c", "exit 1"]
  containers:
    - name: main
      image: nginx:1.27-alpine
EOF
}

scenario_precondition() {
  local ns=$1
  kubectl get pods --context="$KUBEBENCH_CONTEXT" -n "$ns" -o json \
    | jq -e '.items[] | select(.status.phase == "Failed")' >/dev/null 2>&1
}

scenario_postcondition() { return 1; }
