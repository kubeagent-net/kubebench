#!/usr/bin/env bash
SCENARIO_ID=21
SCENARIO_NAME="pending-taint"
SCENARIO_CATEGORY="pod"
SCENARIO_ISSUE_KIND="pod_pending"
SCENARIO_DESCRIPTION="Pod has no toleration for node taint"
SCENARIO_FIXABLE="no"
SCENARIO_DETECT_ONLY="yes"
SCENARIO_EXPECTED_FIX=""

scenario_inject() {
  local ns=$1
  # Taint one worker node
  local worker
  worker=$(kubectl get nodes --context="$KUBEBENCH_CONTEXT" --no-headers \
    | grep -v "control-plane\|master" | head -1 | awk '{print $1}')
  if [ -n "$worker" ]; then
    kubectl taint nodes "$worker" --context="$KUBEBENCH_CONTEXT" \
      kubebench-test=true:NoSchedule --overwrite 2>/dev/null || true
  fi
  kubectl apply --context="$KUBEBENCH_CONTEXT" -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: no-toleration
  namespace: $ns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: no-toleration
  template:
    metadata:
      labels:
        app: no-toleration
    spec:
      nodeSelector:
        kubernetes.io/hostname: "${worker}"
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
    | jq -e '.items[] | select(.status.phase == "Pending")' >/dev/null
}

scenario_postcondition() { return 1; }

scenario_cleanup() {
  local ns=$1
  local worker
  worker=$(kubectl get nodes --context="$KUBEBENCH_CONTEXT" --no-headers \
    | grep -v "control-plane\|master" | head -1 | awk '{print $1}')
  if [ -n "$worker" ]; then
    kubectl taint nodes "$worker" --context="$KUBEBENCH_CONTEXT" \
      kubebench-test=true:NoSchedule- 2>/dev/null || true
  fi
}
