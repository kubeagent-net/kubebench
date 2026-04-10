#!/usr/bin/env bash
SCENARIO_ID=40
SCENARIO_NAME="deploy-bad-image"
SCENARIO_CATEGORY="deploy"
SCENARIO_ISSUE_KIND="pod_image_pull"
SCENARIO_DESCRIPTION="Update deployment to nonexistent image tag"
SCENARIO_FIXABLE="yes"
SCENARIO_EXPECTED_FIX="rollout_restart"

scenario_inject() {
  local ns=$1
  # Deploy healthy first
  kubectl apply --context="$KUBEBENCH_CONTEXT" -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bad-update
  namespace: $ns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: bad-update
  template:
    metadata:
      labels:
        app: bad-update
    spec:
      containers:
      - name: app
        image: nginx:1.27-alpine
        resources:
          limits:
            memory: "64Mi"
            cpu: "100m"
EOF
  # Wait for healthy
  wait_for 60 3 kubectl rollout status deployment/bad-update -n "$ns" \
    --context="$KUBEBENCH_CONTEXT" --timeout=5s
  # Update to bad image
  kubectl set image deployment/bad-update app=nginx:nonexistent-tag-xxxx9999 \
    -n "$ns" --context="$KUBEBENCH_CONTEXT"
}

scenario_precondition() {
  local ns=$1
  kubectl get pods -n "$ns" --context="$KUBEBENCH_CONTEXT" -o json \
    | jq -e '.items[] | .status.containerStatuses[]? | select(.state.waiting.reason == "ImagePullBackOff" or .state.waiting.reason == "ErrImagePull")' >/dev/null
}

scenario_postcondition() {
  local ns=$1
  kubectl get pods -n "$ns" --context="$KUBEBENCH_CONTEXT" -o json \
    | jq -e '[.items[] | select(.status.phase == "Running") | select(.status.containerStatuses[]?.ready == true)] | length > 0' >/dev/null
}
