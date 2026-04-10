#!/usr/bin/env bash
SCENARIO_ID=17
SCENARIO_NAME="pending-cpu"
SCENARIO_CATEGORY="pod"
SCENARIO_ISSUE_KIND="pod_pending"
SCENARIO_DESCRIPTION="Pod requests 100 CPU cores (unschedulable)"
SCENARIO_FIXABLE="no"
SCENARIO_DETECT_ONLY="yes"
SCENARIO_EXPECTED_FIX=""

scenario_inject() {
  local ns=$1
  kubectl apply --context="$KUBEBENCH_CONTEXT" -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: greedy-cpu
  namespace: $ns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: greedy-cpu
  template:
    metadata:
      labels:
        app: greedy-cpu
    spec:
      containers:
      - name: app
        image: nginx:1.27-alpine
        resources:
          requests:
            cpu: "100"
          limits:
            memory: "64Mi"
EOF
}

scenario_precondition() {
  local ns=$1
  kubectl get pods -n "$ns" --context="$KUBEBENCH_CONTEXT" -o json \
    | jq -e '.items[] | select(.status.phase == "Pending")' >/dev/null
}

scenario_postcondition() { return 1; }
