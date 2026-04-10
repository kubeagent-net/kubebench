#!/usr/bin/env bash
SCENARIO_ID=9
SCENARIO_NAME="oom-memory-leak"
SCENARIO_CATEGORY="pod"
SCENARIO_ISSUE_KIND="pod_oom"
SCENARIO_DESCRIPTION="Container allocates memory until OOMKilled (32Mi limit)"
SCENARIO_FIXABLE="yes"
SCENARIO_EXPECTED_FIX="set_resources"

scenario_inject() {
  local ns=$1
  kubectl apply --context="$KUBEBENCH_CONTEXT" -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: oom-leak
  namespace: $ns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: oom-leak
  template:
    metadata:
      labels:
        app: oom-leak
    spec:
      containers:
      - name: app
        image: busybox:1.36
        command: ["sh", "-c", "tail /dev/zero"]
        resources:
          requests:
            memory: "16Mi"
          limits:
            memory: "32Mi"
            cpu: "100m"
EOF
}

scenario_precondition() {
  local ns=$1
  kubectl get pods -n "$ns" --context="$KUBEBENCH_CONTEXT" -o json \
    | jq -e '.items[] | .status.containerStatuses[]? | select(.lastState.terminated.reason == "OOMKilled")' >/dev/null
}

scenario_postcondition() {
  local ns=$1
  kubectl get pods -n "$ns" --context="$KUBEBENCH_CONTEXT" -o json \
    | jq -e '[.items[] | select(.status.phase == "Running") | select(.status.containerStatuses[]?.ready == true)] | length > 0' >/dev/null
}
