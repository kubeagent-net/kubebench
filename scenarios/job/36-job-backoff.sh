#!/usr/bin/env bash
SCENARIO_ID=36
SCENARIO_NAME="job-backoff"
SCENARIO_CATEGORY="job"
SCENARIO_ISSUE_KIND="job_failed"
SCENARIO_DESCRIPTION="Job exceeds backoffLimit with exit 1"
SCENARIO_FIXABLE="no"
SCENARIO_DETECT_ONLY="yes"
SCENARIO_EXPECTED_FIX=""

scenario_inject() {
  local ns=$1
  kubectl apply --context="$KUBEBENCH_CONTEXT" -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: failing-job
  namespace: $ns
spec:
  backoffLimit: 2
  template:
    spec:
      containers:
      - name: fail
        image: busybox:1.36
        command: ["sh", "-c", "echo failing; exit 1"]
        resources:
          limits:
            memory: "32Mi"
            cpu: "50m"
      restartPolicy: Never
EOF
}

scenario_precondition() {
  local ns=$1
  kubectl get jobs -n "$ns" --context="$KUBEBENCH_CONTEXT" -o json \
    | jq -e '.items[] | .status.conditions[]? | select(.type == "Failed" and .status == "True")' >/dev/null
}

scenario_postcondition() { return 1; }
