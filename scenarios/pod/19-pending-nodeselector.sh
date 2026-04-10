#!/usr/bin/env bash
SCENARIO_ID=19
SCENARIO_NAME="pending-nodeselector"
SCENARIO_CATEGORY="pod"
SCENARIO_ISSUE_KIND="pod_pending"
SCENARIO_DESCRIPTION="nodeSelector references non-existent label"
SCENARIO_FIXABLE="no"
SCENARIO_DETECT_ONLY="yes"
SCENARIO_EXPECTED_FIX=""

scenario_inject() {
  local ns=$1
  kubectl apply --context="$KUBEBENCH_CONTEXT" -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bad-selector
  namespace: $ns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: bad-selector
  template:
    metadata:
      labels:
        app: bad-selector
    spec:
      nodeSelector:
        gpu: nvidia-a100
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
  kubectl get pods -n "$ns" --context="$KUBEBENCH_CONTEXT" -o json \
    | jq -e '.items[] | select(.status.phase == "Pending")' >/dev/null
}

scenario_postcondition() { return 1; }
