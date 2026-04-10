#!/usr/bin/env bash
SCENARIO_ID=6
SCENARIO_NAME="crashloop-liveness"
SCENARIO_CATEGORY="pod"
SCENARIO_ISSUE_KIND="pod_crashloop"
SCENARIO_DESCRIPTION="Liveness probe fails (app starts after 60s, probe fires at 5s)"
SCENARIO_FIXABLE="yes"
SCENARIO_EXPECTED_FIX="rollout_restart"

scenario_inject() {
  local ns=$1
  kubectl apply --context="$KUBEBENCH_CONTEXT" -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: liveness-fail
  namespace: $ns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: liveness-fail
  template:
    metadata:
      labels:
        app: liveness-fail
    spec:
      containers:
      - name: app
        image: kubebench/slow-start:latest
        imagePullPolicy: Never
        ports:
        - containerPort: 8080
        livenessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 2
          failureThreshold: 3
        resources:
          limits:
            memory: "128Mi"
            cpu: "200m"
EOF
}

scenario_precondition() {
  local ns=$1
  kubectl get pods -n "$ns" --context="$KUBEBENCH_CONTEXT" -o json \
    | jq -e '.items[] | .status.containerStatuses[]? | select(.state.waiting.reason == "CrashLoopBackOff" or .restartCount > 2)' >/dev/null
}

scenario_postcondition() {
  local ns=$1
  kubectl get pods -n "$ns" --context="$KUBEBENCH_CONTEXT" -o json \
    | jq -e '[.items[] | select(.status.phase == "Running") | select(.status.containerStatuses[]?.ready == true)] | length > 0' >/dev/null
}
