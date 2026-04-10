#!/usr/bin/env bash
SCENARIO_ID=28
SCENARIO_NAME="evicted-ephemeral"
SCENARIO_CATEGORY="pod"
SCENARIO_ISSUE_KIND="pod_evicted"
SCENARIO_DESCRIPTION="Pod exceeds ephemeral-storage limit and gets evicted"
SCENARIO_FIXABLE="no"
SCENARIO_DETECT_ONLY="yes"
SCENARIO_EXPECTED_FIX=""

scenario_inject() {
  local ns=$1
  kubectl apply --context="$KUBEBENCH_CONTEXT" -n "$ns" -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ephemeral-hog
  labels:
    app: ephemeral-hog
spec:
  restartPolicy: Never
  containers:
    - name: ephemeral-hog
      image: busybox:1.36
      command: ["sh", "-c", "dd if=/dev/zero of=/tmp/fill bs=1M count=500"]
      resources:
        limits:
          ephemeral-storage: "10Mi"
EOF
}

scenario_precondition() {
  local ns=$1
  kubectl get pods --context="$KUBEBENCH_CONTEXT" -n "$ns" -o json \
    | jq -e '.items[] | select(.status.phase == "Failed") | select(.status.reason == "Evicted")' >/dev/null 2>&1
}

scenario_postcondition() { return 1; }
