#!/usr/bin/env bash
SCENARIO_ID=50
SCENARIO_NAME="image-plus-job"
SCENARIO_CATEGORY="multi"
SCENARIO_ISSUE_KIND="pod_image_pull"
SCENARIO_DESCRIPTION="Bad image deployment + failing job simultaneously"
SCENARIO_FIXABLE="no"
SCENARIO_DETECT_ONLY="yes"
SCENARIO_EXPECTED_FIX=""

scenario_inject() {
  local ns=$1
  kubectl apply --context="$KUBEBENCH_CONTEXT" -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bad-image
  namespace: $ns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: bad-image
  template:
    metadata:
      labels:
        app: bad-image
    spec:
      containers:
      - name: app
        image: nginx:nonexistent-tag-xxxx9999
        resources:
          limits:
            memory: "64Mi"
            cpu: "100m"
---
apiVersion: batch/v1
kind: Job
metadata:
  name: failing-job
  namespace: $ns
spec:
  backoffLimit: 1
  template:
    spec:
      containers:
      - name: fail
        image: busybox:1.36
        command: ["sh", "-c", "exit 1"]
        resources:
          limits:
            memory: "32Mi"
            cpu: "50m"
      restartPolicy: Never
EOF
}

scenario_precondition() {
  local ns=$1
  local img_pull job_fail
  img_pull=$(kubectl get pods -n "$ns" --context="$KUBEBENCH_CONTEXT" -o json \
    | jq '[.items[] | select(.status.containerStatuses[]?.state.waiting.reason == "ImagePullBackOff" or .status.containerStatuses[]?.state.waiting.reason == "ErrImagePull")] | length')
  job_fail=$(kubectl get jobs -n "$ns" --context="$KUBEBENCH_CONTEXT" -o json \
    | jq '[.items[] | select(.status.conditions[]?.type == "Failed" and .status.conditions[]?.status == "True")] | length')
  [ "$img_pull" -ge 1 ] && [ "$job_fail" -ge 1 ]
}

scenario_postcondition() { return 1; }
