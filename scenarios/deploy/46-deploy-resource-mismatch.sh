#!/usr/bin/env bash
SCENARIO_ID=46
SCENARIO_NAME="deploy-resource-mismatch"
SCENARIO_CATEGORY="deploy"
SCENARIO_ISSUE_KIND="pod_oom"
SCENARIO_DESCRIPTION="Nginx deployment with 2Mi memory limit causes OOMKill"
SCENARIO_FIXABLE="yes"
SCENARIO_EXPECTED_FIX="set_resources"

scenario_inject() {
  local ns=$1
  kubectl apply --context="$KUBEBENCH_CONTEXT" -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: oom-deploy
  namespace: $ns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: oom-deploy
  template:
    metadata:
      labels:
        app: oom-deploy
    spec:
      containers:
      - name: nginx
        image: nginx:1.27-alpine
        resources:
          requests:
            memory: "2Mi"
          limits:
            memory: "2Mi"
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
