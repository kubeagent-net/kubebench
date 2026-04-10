#!/usr/bin/env bash
SCENARIO_ID=11
SCENARIO_NAME="oom-init"
SCENARIO_CATEGORY="pod"
SCENARIO_ISSUE_KIND="pod_oom"
SCENARIO_DESCRIPTION="Init container OOMKilled before main starts"
SCENARIO_FIXABLE="yes"
SCENARIO_EXPECTED_FIX="set_resources"

scenario_inject() {
  local ns=$1
  kubectl apply --context="$KUBEBENCH_CONTEXT" -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: oom-init
  namespace: $ns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: oom-init
  template:
    metadata:
      labels:
        app: oom-init
    spec:
      initContainers:
      - name: init
        image: busybox:1.36
        command: ["sh", "-c", "tail /dev/zero"]
        resources:
          limits:
            memory: "16Mi"
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
    | jq -e '.items[] | .status.initContainerStatuses[]? | select(.lastState.terminated.reason == "OOMKilled")' >/dev/null
}

scenario_postcondition() {
  local ns=$1
  kubectl get pods -n "$ns" --context="$KUBEBENCH_CONTEXT" -o json \
    | jq -e '[.items[] | select(.status.phase == "Running") | select(.status.containerStatuses[]?.ready == true)] | length > 0' >/dev/null
}
