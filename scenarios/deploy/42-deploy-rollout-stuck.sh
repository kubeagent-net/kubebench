#!/usr/bin/env bash
SCENARIO_ID=42
SCENARIO_NAME="deploy-rollout-stuck"
SCENARIO_CATEGORY="deploy"
SCENARIO_ISSUE_KIND="pod_pending"
SCENARIO_DESCRIPTION="Rolling update stuck — new pods request 50 CPU cores"
SCENARIO_FIXABLE="yes"
SCENARIO_EXPECTED_FIX="set_resources"

scenario_inject() {
  local ns=$1
  kubectl apply --context="$KUBEBENCH_CONTEXT" -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stuck-rollout
  namespace: $ns
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 1
  selector:
    matchLabels:
      app: stuck-rollout
  template:
    metadata:
      labels:
        app: stuck-rollout
    spec:
      containers:
      - name: app
        image: nginx:1.27-alpine
        resources:
          limits:
            memory: "64Mi"
            cpu: "100m"
EOF
  wait_for 60 3 kubectl rollout status deployment/stuck-rollout -n "$ns" \
    --context="$KUBEBENCH_CONTEXT" --timeout=5s
  # Update with impossible resource requests
  kubectl patch deployment stuck-rollout -n "$ns" --context="$KUBEBENCH_CONTEXT" \
    --type=json -p='[{"op":"replace","path":"/spec/template/spec/containers/0/resources/requests","value":{"cpu":"50"}}]'
}

scenario_precondition() {
  local ns=$1
  kubectl get pods -n "$ns" --context="$KUBEBENCH_CONTEXT" -o json \
    | jq -e '.items[] | select(.status.phase == "Pending")' >/dev/null
}

scenario_postcondition() {
  local ns=$1
  local pending
  pending=$(kubectl get pods -n "$ns" --context="$KUBEBENCH_CONTEXT" -o json \
    | jq '[.items[] | select(.status.phase == "Pending")] | length')
  [ "$pending" -eq 0 ]
}
