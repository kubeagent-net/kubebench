#!/usr/bin/env bash
SCENARIO_ID=37
SCENARIO_NAME="job-wrong-cmd"
SCENARIO_CATEGORY="job"
SCENARIO_ISSUE_KIND="job_failed"
SCENARIO_DESCRIPTION="Job runs nonexistent command"
SCENARIO_FIXABLE="no"
SCENARIO_DETECT_ONLY="yes"
SCENARIO_EXPECTED_FIX=""

scenario_inject() {
  local ns=$1
  kubectl apply --context="$KUBEBENCH_CONTEXT" -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: bad-cmd-job
  namespace: $ns
spec:
  backoffLimit: 0
  template:
    spec:
      containers:
      - name: fail
        image: busybox:1.36
        command: ["nonexistent-binary-xyz"]
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
