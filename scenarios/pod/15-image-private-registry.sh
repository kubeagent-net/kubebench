#!/usr/bin/env bash
SCENARIO_ID=15
SCENARIO_NAME="image-private-registry"
SCENARIO_CATEGORY="pod"
SCENARIO_ISSUE_KIND="pod_image_pull"
SCENARIO_DESCRIPTION="Private registry with no pull secret"
SCENARIO_FIXABLE="no"
SCENARIO_DETECT_ONLY="yes"
SCENARIO_EXPECTED_FIX=""

scenario_inject() {
  local ns=$1
  kubectl apply --context="$KUBEBENCH_CONTEXT" -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: private-reg
  namespace: $ns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: private-reg
  template:
    metadata:
      labels:
        app: private-reg
    spec:
      containers:
      - name: app
        image: ghcr.io/kubebench-fake/private-image:latest
        resources:
          limits:
            memory: "64Mi"
            cpu: "100m"
EOF
}

scenario_precondition() {
  local ns=$1
  kubectl get pods -n "$ns" --context="$KUBEBENCH_CONTEXT" -o json \
    | jq -e '.items[] | .status.containerStatuses[]? | select(.state.waiting.reason == "ImagePullBackOff" or .state.waiting.reason == "ErrImagePull")' >/dev/null
}

scenario_postcondition() { return 1; }
