#!/usr/bin/env bash
SCENARIO_ID=23
SCENARIO_NAME="pending-priority"
SCENARIO_CATEGORY="pod"
SCENARIO_ISSUE_KIND="pod_pending"
SCENARIO_DESCRIPTION="Low PriorityClass pod cannot schedule"
SCENARIO_FIXABLE="no"
SCENARIO_DETECT_ONLY="yes"
SCENARIO_EXPECTED_FIX=""

scenario_inject() {
  local ns=$1
  kubectl apply --context="$KUBEBENCH_CONTEXT" -f - <<EOF
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: kubebench-low
value: -1000
globalDefault: false
description: "Very low priority for kubebench test"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: low-priority
  namespace: $ns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: low-priority
  template:
    metadata:
      labels:
        app: low-priority
    spec:
      priorityClassName: kubebench-low
      containers:
      - name: app
        image: nginx:1.27-alpine
        resources:
          requests:
            cpu: "50"
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

scenario_cleanup() {
  kubectl delete priorityclass kubebench-low --context="$KUBEBENCH_CONTEXT" 2>/dev/null || true
}
