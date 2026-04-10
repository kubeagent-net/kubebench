#!/usr/bin/env bash
SCENARIO_ID=8
SCENARIO_NAME="crashloop-sidecar"
SCENARIO_CATEGORY="pod"
SCENARIO_ISSUE_KIND="pod_crashloop"
SCENARIO_DESCRIPTION="Sidecar container crashes while main runs"
SCENARIO_FIXABLE="partial"
SCENARIO_EXPECTED_FIX="restart_pod"

scenario_inject() {
  local ns=$1
  kubectl apply --context="$KUBEBENCH_CONTEXT" -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sidecar-crash
  namespace: $ns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sidecar-crash
  template:
    metadata:
      labels:
        app: sidecar-crash
    spec:
      containers:
      - name: main
        image: nginx:1.27-alpine
        resources:
          limits:
            memory: "64Mi"
            cpu: "100m"
      - name: sidecar
        image: busybox:1.36
        command: ["sh", "-c", "exit 1"]
        resources:
          limits:
            memory: "32Mi"
            cpu: "50m"
EOF
}

scenario_precondition() {
  local ns=$1
  kubectl get pods -n "$ns" --context="$KUBEBENCH_CONTEXT" -o json \
    | jq -e '.items[] | .status.containerStatuses[]? | select(.state.waiting.reason == "CrashLoopBackOff")' >/dev/null
}

scenario_postcondition() {
  local ns=$1
  kubectl get pods -n "$ns" --context="$KUBEBENCH_CONTEXT" -o json \
    | jq -e '[.items[] | select(.status.phase == "Running") | select(all(.status.containerStatuses[]?; .ready == true))] | length > 0' >/dev/null
}
