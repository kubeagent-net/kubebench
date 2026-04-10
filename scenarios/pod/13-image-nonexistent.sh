#!/usr/bin/env bash
SCENARIO_ID=13
SCENARIO_NAME="image-nonexistent"
SCENARIO_CATEGORY="pod"
SCENARIO_ISSUE_KIND="pod_image_pull"
SCENARIO_DESCRIPTION="Image from nonexistent registry"
SCENARIO_FIXABLE="no"
SCENARIO_DETECT_ONLY="yes"
SCENARIO_EXPECTED_FIX=""

scenario_inject() {
  local ns=$1
  kubectl apply --context="$KUBEBENCH_CONTEXT" -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bad-registry
  namespace: $ns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: bad-registry
  template:
    metadata:
      labels:
        app: bad-registry
    spec:
      containers:
      - name: app
        image: registry.example.invalid/does-not-exist:v1
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
