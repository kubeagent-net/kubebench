#!/usr/bin/env bash
SCENARIO_ID=4
SCENARIO_NAME="crashloop-dependency"
SCENARIO_CATEGORY="pod"
SCENARIO_ISSUE_KIND="pod_crashloop"
SCENARIO_DESCRIPTION="Container fails connecting to non-existent service"
SCENARIO_FIXABLE="partial"
SCENARIO_EXPECTED_FIX="restart_pod"

scenario_inject() {
  local ns=$1
  kubectl apply --context="$KUBEBENCH_CONTEXT" -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dep-fail
  namespace: $ns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dep-fail
  template:
    metadata:
      labels:
        app: dep-fail
    spec:
      containers:
      - name: app
        image: busybox:1.36
        command: ["sh", "-c", "wget -q -T2 http://no-such-svc:8080/ || exit 1"]
        resources:
          limits:
            memory: "64Mi"
            cpu: "100m"
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
    | jq -e '[.items[] | select(.status.phase == "Running") | select(.status.containerStatuses[]?.ready == true)] | length > 0' >/dev/null
}
