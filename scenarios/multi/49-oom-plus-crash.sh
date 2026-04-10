#!/usr/bin/env bash
SCENARIO_ID=49
SCENARIO_NAME="oom-plus-crash"
SCENARIO_CATEGORY="multi"
SCENARIO_ISSUE_KIND="pod_oom"
SCENARIO_DESCRIPTION="OOMKilled pod + CrashLoopBackOff pod simultaneously"
SCENARIO_FIXABLE="partial"
SCENARIO_EXPECTED_FIX="set_resources"

scenario_inject() {
  local ns=$1
  kubectl apply --context="$KUBEBENCH_CONTEXT" -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: oom-victim
  namespace: $ns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: oom-victim
  template:
    metadata:
      labels:
        app: oom-victim
    spec:
      containers:
      - name: app
        image: busybox:1.36
        command: ["sh", "-c", "tail /dev/zero"]
        resources:
          requests:
            memory: "8Mi"
          limits:
            memory: "16Mi"
            cpu: "100m"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: crasher
  namespace: $ns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: crasher
  template:
    metadata:
      labels:
        app: crasher
    spec:
      containers:
      - name: app
        image: busybox:1.36
        command: ["sh", "-c", "exit 1"]
        resources:
          limits:
            memory: "64Mi"
            cpu: "100m"
EOF
}

scenario_precondition() {
  local ns=$1
  local oom crash
  oom=$(kubectl get pods -n "$ns" --context="$KUBEBENCH_CONTEXT" -o json \
    | jq '[.items[] | select(.status.containerStatuses[]?.lastState.terminated.reason == "OOMKilled")] | length')
  crash=$(kubectl get pods -n "$ns" --context="$KUBEBENCH_CONTEXT" -o json \
    | jq '[.items[] | select(.status.containerStatuses[]?.state.waiting.reason == "CrashLoopBackOff")] | length')
  [ "$oom" -ge 1 ] && [ "$crash" -ge 1 ]
}

scenario_postcondition() {
  local ns=$1
  local oom crash
  oom=$(kubectl get pods -n "$ns" --context="$KUBEBENCH_CONTEXT" -o json \
    | jq '[.items[] | select(.status.containerStatuses[]?.lastState.terminated.reason == "OOMKilled")] | length')
  crash=$(kubectl get pods -n "$ns" --context="$KUBEBENCH_CONTEXT" -o json \
    | jq '[.items[] | select(.status.containerStatuses[]?.state.waiting.reason == "CrashLoopBackOff")] | length')
  [ "$oom" -eq 0 ] || [ "$crash" -eq 0 ]
}
