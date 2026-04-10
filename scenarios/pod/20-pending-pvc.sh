#!/usr/bin/env bash
SCENARIO_ID=20
SCENARIO_NAME="pending-pvc"
SCENARIO_CATEGORY="pod"
SCENARIO_ISSUE_KIND="pod_pending"
SCENARIO_DESCRIPTION="PVC references non-existent StorageClass"
SCENARIO_FIXABLE="no"
SCENARIO_DETECT_ONLY="yes"
SCENARIO_EXPECTED_FIX=""

scenario_inject() {
  local ns=$1
  kubectl apply --context="$KUBEBENCH_CONTEXT" -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: bad-pvc
  namespace: $ns
spec:
  storageClassName: nonexistent-storage-class
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pvc-pending
  namespace: $ns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pvc-pending
  template:
    metadata:
      labels:
        app: pvc-pending
    spec:
      containers:
      - name: app
        image: nginx:1.27-alpine
        volumeMounts:
        - name: data
          mountPath: /data
        resources:
          limits:
            memory: "64Mi"
            cpu: "100m"
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: bad-pvc
EOF
}

scenario_precondition() {
  local ns=$1
  kubectl get pods -n "$ns" --context="$KUBEBENCH_CONTEXT" -o json \
    | jq -e '.items[] | select(.status.phase == "Pending")' >/dev/null
}

scenario_postcondition() { return 1; }
