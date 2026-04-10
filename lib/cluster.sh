#!/usr/bin/env bash
# lib/cluster.sh — k3d/kind cluster lifecycle

cluster_create() {
  log_info "Creating ${PROVIDER} cluster: ${CLUSTER_NAME} (1 server + 2 agents)..."

  case "$PROVIDER" in
    k3d)
      k3d cluster create "$CLUSTER_NAME" \
        --servers 1 --agents 2 \
        --wait --timeout 120s \
        --k3s-arg "--disable=traefik@server:0" \
        --no-lb \
        2>&1 | while IFS= read -r line; do log_dim "  k3d: $line"; done
      KUBEBENCH_CONTEXT="k3d-${CLUSTER_NAME}"
      ;;
    kind)
      local config
      config=$(mktemp)
      cat > "$config" <<'KINDEOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
KINDEOF
      kind create cluster --name "$CLUSTER_NAME" --config "$config" --wait 120s
      rm -f "$config"
      KUBEBENCH_CONTEXT="kind-${CLUSTER_NAME}"
      ;;
    *)
      log_error "Unknown provider: $PROVIDER"
      return 1
      ;;
  esac

  export KUBEBENCH_CONTEXT
  log_ok "Cluster created. Context: ${KUBEBENCH_CONTEXT}"
}

cluster_wait_ready() {
  log_info "Waiting for nodes to be Ready..."
  local deadline=$(( $(date +%s) + 120 ))
  while [ "$(date +%s)" -lt "$deadline" ]; do
    local not_ready
    not_ready=$(kubectl get nodes --context="$KUBEBENCH_CONTEXT" --no-headers 2>/dev/null \
      | grep -cv " Ready" || true)
    if [ "$not_ready" -eq 0 ]; then
      log_ok "All nodes Ready"
      return 0
    fi
    sleep 3
  done
  log_error "Nodes not ready after 120s"
  return 1
}

cluster_build_images() {
  log_info "Building fixture images..."
  local fixtures_dir="${KUBEBENCH_DIR}/fixtures"

  # Only build if Dockerfiles exist
  for df in "$fixtures_dir"/Dockerfile.*; do
    [ -f "$df" ] || continue
    local tag
    tag="kubebench/$(basename "$df" | sed 's/Dockerfile\.//')"
    docker build -t "${tag}:latest" -f "$df" "$fixtures_dir" -q >/dev/null
    log_dim "  Built ${tag}:latest"
  done

  # Import images into cluster
  case "$PROVIDER" in
    k3d)
      local images
      images=$(docker images --format '{{.Repository}}:{{.Tag}}' | grep '^kubebench/' || true)
      if [ -n "$images" ]; then
        echo "$images" | xargs k3d image import -c "$CLUSTER_NAME" 2>/dev/null
      fi
      ;;
    kind)
      docker images --format '{{.Repository}}:{{.Tag}}' | grep '^kubebench/' | while read -r img; do
        kind load docker-image "$img" --name "$CLUSTER_NAME"
      done
      ;;
  esac
  log_ok "Images loaded into cluster"
}

cluster_delete() {
  log_info "Deleting cluster: ${CLUSTER_NAME}..."
  case "$PROVIDER" in
    k3d)  k3d cluster delete "$CLUSTER_NAME" 2>/dev/null || true ;;
    kind) kind delete cluster --name "$CLUSTER_NAME" 2>/dev/null || true ;;
  esac
  log_ok "Cluster deleted"
}
