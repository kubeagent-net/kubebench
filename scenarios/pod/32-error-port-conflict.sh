#!/usr/bin/env bash
SCENARIO_ID=32
SCENARIO_NAME="error-port-conflict"
SCENARIO_CATEGORY="pod"
SCENARIO_ISSUE_KIND="pod_error"
SCENARIO_DESCRIPTION="Two containers in the same pod bind to port 80, causing a port conflict"
SCENARIO_FIXABLE="partial"
SCENARIO_DETECT_ONLY="no"
SCENARIO_EXPECTED_FIX="restart_pod"

scenario_inject() {
  local ns=$1
  kubectl apply --context="$KUBEBENCH_CONTEXT" -n "$ns" -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: port-conflict
spec:
  replicas: 1
  selector:
    matchLabels:
      app: port-conflict
  template:
    metadata:
      labels:
        app: port-conflict
    spec:
      containers:
        - name: nginx-a
          image: nginx:1.27-alpine
          ports:
            - containerPort: 80
        - name: nginx-b
          image: nginx:1.27-alpine
          ports:
            - containerPort: 80
EOF
}

scenario_precondition() {
  local ns=$1
  kubectl get pods --context="$KUBEBENCH_CONTEXT" -n "$ns" -l app=port-conflict -o json \
    | jq -e '.items[] | .status.containerStatuses[]? | select(.state.waiting.reason == "CrashLoopBackOff" or .state.terminated.reason == "Error" or .restartCount > 2)' >/dev/null 2>&1
}

scenario_postcondition() {
  local ns=$1
  # Check that all containers in all pods are ready (unlikely but test it)
  local not_ready
  not_ready=$(kubectl get pods --context="$KUBEBENCH_CONTEXT" -n "$ns" -l app=port-conflict -o json \
    | jq '[.items[] | .status.containerStatuses[]? | select(.ready != true)] | length')
  [ "$not_ready" -eq 0 ]
}
