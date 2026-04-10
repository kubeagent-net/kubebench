#!/usr/bin/env bash
SCENARIO_ID=47
SCENARIO_NAME="deploy-env-var"
SCENARIO_CATEGORY="deploy"
SCENARIO_ISSUE_KIND="pod_crashloop"
SCENARIO_DESCRIPTION="Deployment runs command referencing undefined env var"
SCENARIO_FIXABLE="yes"
SCENARIO_EXPECTED_FIX="rollout_restart"

scenario_inject() {
  local ns=$1
  kubectl apply --context="$KUBEBENCH_CONTEXT" -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bad-env
  namespace: $ns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: bad-env
  template:
    metadata:
      labels:
        app: bad-env
    spec:
      containers:
      - name: app
        image: busybox:1.36
        command: ["sh", "-c", "echo \$MISSING_VAR; exit 1"]
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
