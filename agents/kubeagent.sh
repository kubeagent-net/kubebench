#!/usr/bin/env bash
# agents/kubeagent.sh — kubeagent watch adapter

agent_name() { echo "kubeagent"; }

agent_setup() {
  # Find kubeagent binary
  if [ -n "${KUBEAGENT_BIN:-}" ]; then
    KUBEAGENT_CMD=("node" "$KUBEAGENT_BIN")
  elif [ -f "${KUBEBENCH_DIR}/../kubeagent/dist/cli.js" ]; then
    KUBEAGENT_CMD=("node" "${KUBEBENCH_DIR}/../kubeagent/dist/cli.js")
  elif [ -f "${KUBEBENCH_DIR}/../kubeagent/src/cli.ts" ]; then
    KUBEAGENT_CMD=("npx" "tsx" "${KUBEBENCH_DIR}/../kubeagent/src/cli.ts")
  elif command -v kubeagent &>/dev/null; then
    KUBEAGENT_CMD=("kubeagent")
  else
    log_error "kubeagent binary not found. Set KUBEAGENT_BIN or install kubeagent."
    return 1
  fi
  export KUBEAGENT_CMD

  # Verify auth
  local auth_file="${HOME}/.kubeagent/auth.json"
  if [ ! -f "$auth_file" ]; then
    log_error "kubeagent not authenticated. Run 'kubeagent login' first."
    return 1
  fi

  # Ensure cluster context is onboarded in config
  local config_file="${HOME}/.kubeagent/config.yaml"
  mkdir -p "${HOME}/.kubeagent"

  if [ ! -f "$config_file" ]; then
    cat > "$config_file" <<CFGEOF
clusters:
  - context: "${KUBEBENCH_CONTEXT}"
    interval: ${AGENT_INTERVAL:-15}
    codepaths: []
remediation:
  auto_fix: true
  max_retries: 2
  cooldown: 15
  safe_actions:
    - restart_pod
    - rollout_restart
    - scale_deployment
    - set_resources
CFGEOF
    log_ok "Created kubeagent config with kubebench context"
  else
    # Check if context already exists
    if ! grep -q "${KUBEBENCH_CONTEXT}" "$config_file" 2>/dev/null; then
      # Backup original config
      cp "$config_file" "${config_file}.kubebench-backup"

      if command -v yq &>/dev/null; then
        yq -i ".clusters += [{\"context\": \"${KUBEBENCH_CONTEXT}\", \"interval\": ${AGENT_INTERVAL:-15}, \"codepaths\": []}]" "$config_file"
      else
        # Append context using a temp file approach
        local tmp
        tmp=$(mktemp)
        python3 -c "
import yaml, sys
with open('$config_file') as f:
    cfg = yaml.safe_load(f) or {}
clusters = cfg.get('clusters', [])
clusters.append({'context': '${KUBEBENCH_CONTEXT}', 'interval': ${AGENT_INTERVAL:-15}, 'codepaths': []})
cfg['clusters'] = clusters
with open('$tmp', 'w') as f:
    yaml.dump(cfg, f, default_flow_style=False)
" 2>/dev/null && mv "$tmp" "$config_file" || {
          # Fallback: just append a cluster entry
          echo "  - context: \"${KUBEBENCH_CONTEXT}\"" >> "$config_file"
          echo "    interval: ${AGENT_INTERVAL:-15}" >> "$config_file"
          echo "    codepaths: []" >> "$config_file"
        }
      fi
      log_ok "Added ${KUBEBENCH_CONTEXT} to kubeagent config (backup: config.yaml.kubebench-backup)"
    else
      log_dim "  Context ${KUBEBENCH_CONTEXT} already in kubeagent config"
    fi
  fi

  log_ok "kubeagent adapter ready (cmd: ${KUBEAGENT_CMD[*]})"
}

agent_start() {
  local interval="${AGENT_INTERVAL:-15}"
  log_info "Starting kubeagent watch (interval: ${interval}s, non-interactive)..."

  "${KUBEAGENT_CMD[@]}" watch \
    -c "$KUBEBENCH_CONTEXT" \
    --no-interactive \
    -i "$interval" \
    >> "$REPORT_DIR/agent-output.log" 2>&1 &
  AGENT_PID=$!
  export AGENT_PID

  # Verify it didn't immediately crash
  sleep 3
  if ! kill -0 "$AGENT_PID" 2>/dev/null; then
    log_error "kubeagent exited immediately. Check: $REPORT_DIR/agent-output.log"
    tail -20 "$REPORT_DIR/agent-output.log" 2>/dev/null
    return 1
  fi
  log_ok "kubeagent watch started (PID: $AGENT_PID)"
}

agent_stop() {
  if [ -n "${AGENT_PID:-}" ] && [ "$AGENT_PID" -ne 0 ] && kill -0 "$AGENT_PID" 2>/dev/null; then
    log_info "Stopping kubeagent (PID: $AGENT_PID)..."
    kill -TERM "$AGENT_PID" 2>/dev/null
    local waited=0
    while kill -0 "$AGENT_PID" 2>/dev/null && [ $waited -lt 10 ]; do
      sleep 1
      waited=$((waited + 1))
    done
    if kill -0 "$AGENT_PID" 2>/dev/null; then
      kill -9 "$AGENT_PID" 2>/dev/null
    fi
    wait "$AGENT_PID" 2>/dev/null || true
    log_ok "kubeagent stopped"
  fi
}

agent_is_running() {
  [ -n "${AGENT_PID:-}" ] && [ "$AGENT_PID" -ne 0 ] && kill -0 "$AGENT_PID" 2>/dev/null
}
