#!/usr/bin/env bash
SCENARIO_ID=26
SCENARIO_NAME="failed-deadline"
SCENARIO_CATEGORY="pod"
SCENARIO_ISSUE_KIND="pod_failed"
SCENARIO_DESCRIPTION="Standalone pod exceeds activeDeadlineSeconds and is terminated"
SCENARIO_FIXABLE="no"
SCENARIO_DETECT_ONLY="yes"
SCENARIO_EXPECTED_FIX=""

scenario_inject() {
  local ns=$1
  kubectl apply --context="$KUBEBENCH_CONTEXT" -n "$ns" -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: deadline-pod
  labels:
    app: deadline-pod
spec:
  restartPolicy: Never
  activeDeadlineSeconds: 10
  containers:
    - name: deadline-pod
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
EOF
}

scenario_precondition() {
  local ns=$1
  kubectl get pods --context="$KUBEBENCH_CONTEXT" -n "$ns" -o json \
    | jq -e '.items[] | select(.status.phase == "Failed")' >/dev/null 2>&1
}

scenario_postcondition() { return 1; }
