#!/usr/bin/env bash
SCENARIO_ID=45
SCENARIO_NAME="deploy-rolling-crash"
SCENARIO_CATEGORY="deploy"
SCENARIO_ISSUE_KIND="pod_crashloop"
SCENARIO_DESCRIPTION="Rolling update to crashing image with maxUnavailable=0"
SCENARIO_FIXABLE="yes"
SCENARIO_EXPECTED_FIX="rollout_restart"

scenario_inject() {
  local ns=$1
  # Deploy healthy
  kubectl apply --context="$KUBEBENCH_CONTEXT" -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rolling-crash
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
      app: rolling-crash
  template:
    metadata:
      labels:
        app: rolling-crash
    spec:
      containers:
      - name: app
        image: nginx:1.27-alpine
        resources:
          limits:
            memory: "64Mi"
            cpu: "100m"
EOF
  wait_for 60 3 kubectl rollout status deployment/rolling-crash -n "$ns" \
    --context="$KUBEBENCH_CONTEXT" --timeout=5s
  # Update to crashing image
  kubectl set image deployment/rolling-crash app=busybox:1.36 \
    -n "$ns" --context="$KUBEBENCH_CONTEXT"
  kubectl patch deployment rolling-crash -n "$ns" --context="$KUBEBENCH_CONTEXT" \
    --type=json -p='[{"op":"replace","path":"/spec/template/spec/containers/0/command","value":["sh","-c","exit 1"]}]'
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
