#!/usr/bin/env bash
SCENARIO_ID=39
SCENARIO_NAME="job-oom"
SCENARIO_CATEGORY="job"
SCENARIO_ISSUE_KIND="job_failed"
SCENARIO_DESCRIPTION="Job pod OOMKilled with 16Mi limit"
SCENARIO_FIXABLE="no"
SCENARIO_DETECT_ONLY="yes"
SCENARIO_EXPECTED_FIX=""

scenario_inject() {
  local ns=$1
  kubectl apply --context="$KUBEBENCH_CONTEXT" -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: oom-job
  namespace: $ns
spec:
  backoffLimit: 1
  template:
    spec:
      containers:
      - name: oom
        image: busybox:1.36
        command: ["sh", "-c", "tail /dev/zero"]
        resources:
          requests:
            memory: "8Mi"
          limits:
            memory: "16Mi"
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
