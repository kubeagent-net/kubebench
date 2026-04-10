#!/usr/bin/env bash
SCENARIO_ID=5
SCENARIO_NAME="crashloop-init-fail"
SCENARIO_CATEGORY="pod"
SCENARIO_ISSUE_KIND="pod_crashloop"
SCENARIO_DESCRIPTION="Init container always exits with error"
SCENARIO_FIXABLE="partial"
SCENARIO_EXPECTED_FIX="restart_pod"

scenario_inject() {
  local ns=$1
  kubectl apply --context="$KUBEBENCH_CONTEXT" -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: init-fail
  namespace: $ns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: init-fail
  template:
    metadata:
      labels:
        app: init-fail
    spec:
      initContainers:
      - name: init
        image: busybox:1.36
        command: ["sh", "-c", "exit 1"]
        resources:
          limits:
            memory: "32Mi"
            cpu: "50m"
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
    | jq -e '.items[] | .status.initContainerStatuses[]? | select(.state.waiting.reason == "CrashLoopBackOff")' >/dev/null
}

scenario_postcondition() {
  local ns=$1
  kubectl get pods -n "$ns" --context="$KUBEBENCH_CONTEXT" -o json \
    | jq -e '[.items[] | select(.status.phase == "Running") | select(.status.containerStatuses[]?.ready == true)] | length > 0' >/dev/null
}
