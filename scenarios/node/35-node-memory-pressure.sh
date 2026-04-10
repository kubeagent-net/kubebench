#!/usr/bin/env bash
SCENARIO_ID=35
SCENARIO_NAME="node-memory-pressure"
SCENARIO_CATEGORY="node"
SCENARIO_ISSUE_KIND="node_pressure"
SCENARIO_DESCRIPTION="Stress test node memory to trigger MemoryPressure condition"
SCENARIO_FIXABLE="no"
SCENARIO_DETECT_ONLY="yes"
SCENARIO_EXPECTED_FIX=""

scenario_inject() {
  local ns=$1
  kubectl apply --context="$KUBEBENCH_CONTEXT" -f - <<EOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: memory-hog
  namespace: $ns
spec:
  selector:
    matchLabels:
      app: memory-hog
  template:
    metadata:
      labels:
        app: memory-hog
    spec:
      containers:
      - name: stress
        image: busybox:1.36
        command: ["sh", "-c", "head -c 1500m /dev/urandom > /dev/null; sleep 3600"]
        resources:
          requests:
            memory: "1500Mi"
          limits:
            memory: "2Gi"
            cpu: "200m"
EOF
}

scenario_precondition() {
  local ns=$1
  kubectl get nodes --context="$KUBEBENCH_CONTEXT" -o json \
    | jq -e '.items[] | .status.conditions[] | select(.type == "MemoryPressure" and .status == "True")' >/dev/null
}

scenario_postcondition() { return 1; }
