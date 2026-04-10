#!/usr/bin/env bash
SCENARIO_ID=43
SCENARIO_NAME="deploy-zero-replicas"
SCENARIO_CATEGORY="deploy"
SCENARIO_ISSUE_KIND="pod_pending"
SCENARIO_DESCRIPTION="Deployment scaled to 0 replicas"
SCENARIO_FIXABLE="yes"
SCENARIO_EXPECTED_FIX="scale_deployment"

scenario_inject() {
  local ns=$1
  kubectl apply --context="$KUBEBENCH_CONTEXT" -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ghost-app
  namespace: $ns
spec:
  replicas: 0
  selector:
    matchLabels:
      app: ghost-app
  template:
    metadata:
      labels:
        app: ghost-app
    spec:
      containers:
      - name: app
        image: nginx:1.27-alpine
        resources:
          limits:
            memory: "64Mi"
            cpu: "100m"
EOF
}

scenario_precondition() {
  local ns=$1
  local ready
  ready=$(kubectl get deployment ghost-app -n "$ns" --context="$KUBEBENCH_CONTEXT" \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  [ "${ready:-0}" -eq 0 ]
}

scenario_postcondition() {
  local ns=$1
  local ready
  ready=$(kubectl get deployment ghost-app -n "$ns" --context="$KUBEBENCH_CONTEXT" \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  [ "${ready:-0}" -ge 1 ]
}
