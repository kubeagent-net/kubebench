#!/usr/bin/env bash
SCENARIO_ID=48
SCENARIO_NAME="cascade-crash-pending"
SCENARIO_CATEGORY="multi"
SCENARIO_ISSUE_KIND="pod_crashloop"
SCENARIO_DESCRIPTION="Simultaneous CrashLoopBackOff + Pending pod"
SCENARIO_FIXABLE="partial"
SCENARIO_EXPECTED_FIX="rollout_restart"

scenario_inject() {
  local ns=$1
  kubectl apply --context="$KUBEBENCH_CONTEXT" -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: crasher
  namespace: $ns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: crasher
  template:
    metadata:
      labels:
        app: crasher
    spec:
      containers:
      - name: app
        image: busybox:1.36
        command: ["sh", "-c", "exit 1"]
        resources:
          limits:
            memory: "64Mi"
            cpu: "100m"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: greedy
  namespace: $ns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: greedy
  template:
    metadata:
      labels:
        app: greedy
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
  local crash pending
  crash=$(kubectl get pods -n "$ns" --context="$KUBEBENCH_CONTEXT" -o json \
    | jq '[.items[] | select(.status.containerStatuses[]?.state.waiting.reason == "CrashLoopBackOff")] | length')
  pending=$(kubectl get pods -n "$ns" --context="$KUBEBENCH_CONTEXT" -o json \
    | jq '[.items[] | select(.status.phase == "Pending")] | length')
  [ "$crash" -ge 1 ] && [ "$pending" -ge 1 ]
}

scenario_postcondition() {
  local ns=$1
  local crash
  crash=$(kubectl get pods -n "$ns" --context="$KUBEBENCH_CONTEXT" -o json \
    | jq '[.items[] | select(.status.containerStatuses[]?.state.waiting.reason == "CrashLoopBackOff")] | length')
  [ "$crash" -eq 0 ]
}
