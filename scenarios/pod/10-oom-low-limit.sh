#!/usr/bin/env bash
SCENARIO_ID=10
SCENARIO_NAME="oom-low-limit"
SCENARIO_CATEGORY="pod"
SCENARIO_ISSUE_KIND="pod_oom"
SCENARIO_DESCRIPTION="nginx with impossibly low 4Mi memory limit"
SCENARIO_FIXABLE="yes"
SCENARIO_EXPECTED_FIX="set_resources"

scenario_inject() {
  local ns=$1
  kubectl apply --context="$KUBEBENCH_CONTEXT" -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: oom-low
  namespace: $ns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: oom-low
  template:
    metadata:
      labels:
        app: oom-low
    spec:
      containers:
      - name: nginx
        image: nginx:1.27-alpine
        resources:
          requests:
            memory: "4Mi"
          limits:
            memory: "4Mi"
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
