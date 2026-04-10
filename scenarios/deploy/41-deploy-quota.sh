#!/usr/bin/env bash
SCENARIO_ID=41
SCENARIO_NAME="deploy-quota"
SCENARIO_CATEGORY="deploy"
SCENARIO_ISSUE_KIND="pod_pending"
SCENARIO_DESCRIPTION="ResourceQuota limits pods to 3, deployment wants 10"
SCENARIO_FIXABLE="yes"
SCENARIO_EXPECTED_FIX="scale_deployment"

scenario_inject() {
  local ns=$1
  kubectl apply --context="$KUBEBENCH_CONTEXT" -f - <<EOF
apiVersion: v1
kind: ResourceQuota
metadata:
  name: pod-limit
  namespace: $ns
spec:
  hard:
    pods: "3"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: over-quota
  namespace: $ns
spec:
  replicas: 10
  selector:
    matchLabels:
      app: over-quota
  template:
    metadata:
      labels:
        app: over-quota
    spec:
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
  local desired ready
  desired=$(kubectl get deployment over-quota -n "$ns" --context="$KUBEBENCH_CONTEXT" \
    -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
  ready=$(kubectl get deployment over-quota -n "$ns" --context="$KUBEBENCH_CONTEXT" \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  [ "${ready:-0}" -lt "${desired:-0}" ]
}

scenario_postcondition() {
  local ns=$1
  local desired ready
  desired=$(kubectl get deployment over-quota -n "$ns" --context="$KUBEBENCH_CONTEXT" \
    -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "10")
  ready=$(kubectl get deployment over-quota -n "$ns" --context="$KUBEBENCH_CONTEXT" \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  [ "${ready:-0}" -ge "${desired:-10}" ] && [ "${desired:-10}" -le 3 ]
}
