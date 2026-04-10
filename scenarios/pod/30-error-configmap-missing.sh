#!/usr/bin/env bash
SCENARIO_ID=30
SCENARIO_NAME="error-configmap-missing"
SCENARIO_CATEGORY="pod"
SCENARIO_ISSUE_KIND="pod_error"
SCENARIO_DESCRIPTION="Deployment references a non-existent ConfigMap, causing CreateContainerConfigError"
SCENARIO_FIXABLE="no"
SCENARIO_DETECT_ONLY="yes"
SCENARIO_EXPECTED_FIX=""

scenario_inject() {
  local ns=$1
  kubectl apply --context="$KUBEBENCH_CONTEXT" -n "$ns" -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: missing-cm
spec:
  replicas: 1
  selector:
    matchLabels:
      app: missing-cm
  template:
    metadata:
      labels:
        app: missing-cm
    spec:
      containers:
        - name: missing-cm
          image: nginx:1.27-alpine
          envFrom:
            - configMapRef:
                name: nonexistent-config
EOF
}

scenario_precondition() {
  local ns=$1
  # Check for CreateContainerConfigError or pod not in Running phase
  kubectl get pods --context="$KUBEBENCH_CONTEXT" -n "$ns" -l app=missing-cm -o json \
    | jq -e '
      .items[] |
      (
        (.status.containerStatuses[]? | select(.state.waiting.reason == "CreateContainerConfigError"))
        // select(.status.phase != "Running")
      )
    ' >/dev/null 2>&1
}

scenario_postcondition() { return 1; }
