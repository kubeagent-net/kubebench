#!/usr/bin/env bash
SCENARIO_ID=24
SCENARIO_NAME="pending-too-many"
SCENARIO_CATEGORY="pod"
SCENARIO_ISSUE_KIND="pod_pending"
SCENARIO_DESCRIPTION="100 replicas requesting 500m CPU each (too many to schedule)"
SCENARIO_FIXABLE="yes"
SCENARIO_EXPECTED_FIX="scale_deployment"

scenario_inject() {
  local ns=$1
  kubectl apply --context="$KUBEBENCH_CONTEXT" -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: too-many
  namespace: $ns
spec:
  replicas: 100
  selector:
    matchLabels:
      app: too-many
  template:
    metadata:
      labels:
        app: too-many
    spec:
      containers:
      - name: app
        image: nginx:1.27-alpine
        resources:
          requests:
            cpu: "500m"
          limits:
            memory: "64Mi"
            cpu: "500m"
EOF
}

scenario_precondition() {
  local ns=$1
  kubectl get pods -n "$ns" --context="$KUBEBENCH_CONTEXT" -o json \
    | jq -e '[.items[] | select(.status.phase == "Pending")] | length > 5' >/dev/null
}

scenario_postcondition() {
  local ns=$1
  local pending
  pending=$(kubectl get pods -n "$ns" --context="$KUBEBENCH_CONTEXT" -o json \
    | jq '[.items[] | select(.status.phase == "Pending")] | length')
  [ "$pending" -eq 0 ]
}
