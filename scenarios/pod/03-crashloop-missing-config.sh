#!/usr/bin/env bash
SCENARIO_ID=3
SCENARIO_NAME="crashloop-missing-config"
SCENARIO_CATEGORY="pod"
SCENARIO_ISSUE_KIND="pod_crashloop"
SCENARIO_DESCRIPTION="Container fails reading non-existent config file"
SCENARIO_FIXABLE="yes"
SCENARIO_EXPECTED_FIX="rollout_restart"

scenario_inject() {
  local ns=$1
  kubectl apply --context="$KUBEBENCH_CONTEXT" -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: missing-config
  namespace: $ns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: missing-config
  template:
    metadata:
      labels:
        app: missing-config
    spec:
      containers:
      - name: app
        image: busybox:1.36
        command: ["sh", "-c", "cat /config/app.yaml || exit 1"]
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
