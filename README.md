# kubebench

[![CI](https://github.com/kubeagent-net/kubebench/actions/workflows/ci.yml/badge.svg)](https://github.com/kubeagent-net/kubebench/actions/workflows/ci.yml)

Kubernetes Fault Injection Benchmark — test any K8s monitoring/remediation agent against 50 real fault scenarios.

Spins up a local cluster, injects known issues one by one, and scores your agent on detection rate, fix rate, and response time.

## Quick Start

```bash
# Prerequisites: docker, kubectl, k3d (or kind), jq
brew install k3d jq  # macOS

# Run the full benchmark with kubeagent
./kubebench.sh

# Or inject faults without an agent (manual observation)
./kubebench.sh --agent manual --keep-cluster
```

## What It Does

1. Creates a local k3d/kind cluster (1 server + 2 workers)
2. Starts your agent in the background
3. For each of 50 scenarios:
   - Injects a fault (broken deployment, OOM, bad image, etc.)
   - Waits for the issue to manifest (precondition)
   - Waits for the agent to fix it (postcondition, with timeout)
   - Records: detected? fixed? how long?
   - Captures agent output per scenario
4. Produces a JSON report + terminal summary
5. Tears down the cluster

## 50 Scenarios

| Category | Count | Issue Kinds | Fixable |
|----------|-------|-------------|---------|
| Pod CrashLoop | 8 | `pod_crashloop` | 5 yes, 3 partial |
| Pod OOM | 4 | `pod_oom` | 4 yes |
| Pod ImagePull | 4 | `pod_image_pull` | 0 (detect-only) |
| Pod Pending | 8 | `pod_pending` | 2 yes, 6 detect-only |
| Pod Failed | 3 | `pod_failed` | 0 (detect-only) |
| Pod Evicted | 1 | `pod_evicted` | 0 (detect-only) |
| Pod Error | 5 | `pod_error` | 2 yes, 1 partial, 2 detect-only |
| Node | 2 | `node_not_ready`, `node_pressure` | 0 (detect-only) |
| Job | 4 | `job_failed` | 0 (detect-only) |
| Deployment | 8 | mixed | 8 yes |
| Multi-resource | 3 | mixed | 0-2 partial |

## CLI Options

```
Usage: kubebench.sh [OPTIONS]

Options:
  --provider k3d|kind           Cluster provider (default: k3d)
  --agent kubeagent|manual      Agent to test (default: kubeagent)
  --scenario N|N-M              Run scenario N, or range N-M
  --category CATEGORY           Filter by: pod, node, job, deploy, multi
  --detect-only                 Only verify detection, skip fix verification
  --precondition-timeout SEC    Wait for issue to manifest (default: 90)
  --postcondition-timeout SEC   Wait for agent to fix (default: 300)
  --agent-interval SEC          Agent poll interval in seconds (default: 15)
  --cluster-name NAME           Cluster name (default: kubebench)
  --keep-cluster                Don't delete cluster after run
  --context CONTEXT              Use existing cluster (skip create/delete)
  --report-dir DIR              Report output directory
  --verbose                     Verbose output
```

## Examples

```bash
# Full benchmark
./kubebench.sh

# Only OOM scenarios
./kubebench.sh --scenario 9-12

# Only pod scenarios, detection only
./kubebench.sh --category pod --detect-only

# Use kind instead of k3d
./kubebench.sh --provider kind

# Keep cluster alive for manual inspection
./kubebench.sh --agent manual --scenario 1 --keep-cluster
# Then: kubectl --context=k3d-kubebench get pods -A

# Run against an existing cluster
./kubebench.sh --context my-cluster --agent manual
```

## Adding a Custom Agent

Create a file in `agents/your-agent.sh` implementing these functions:

```bash
agent_name()       # Return human-readable name
agent_setup()      # Configure agent for $KUBEBENCH_CONTEXT cluster
agent_start()      # Start agent in background, set $AGENT_PID
agent_stop()       # Stop the agent process
agent_is_running() # Return 0 if agent is alive
```

Then run: `./kubebench.sh --agent your-agent`

See `agents/kubeagent.sh` for a full example.

## Adding a Custom Scenario

Create a file in `scenarios/<category>/NN-name.sh`:

```bash
#!/usr/bin/env bash
SCENARIO_ID=51
SCENARIO_NAME="my-scenario"
SCENARIO_CATEGORY="pod"
SCENARIO_ISSUE_KIND="pod_crashloop"
SCENARIO_DESCRIPTION="What this tests"
SCENARIO_FIXABLE="yes"          # yes | no | partial
SCENARIO_EXPECTED_FIX="rollout_restart"
# SCENARIO_DETECT_ONLY="yes"   # uncomment for unfixable issues

scenario_inject() {
  local ns=$1
  kubectl apply --context="$KUBEBENCH_CONTEXT" -f - <<EOF
  # Your broken K8s manifest here
EOF
}

scenario_precondition() {
  local ns=$1
  # Return 0 when the issue has manifested
  kubectl get pods -n "$ns" --context="$KUBEBENCH_CONTEXT" -o json \
    | jq -e '.items[] | select(...)' >/dev/null
}

scenario_postcondition() {
  local ns=$1
  # Return 0 when the issue is fixed
  kubectl get pods -n "$ns" --context="$KUBEBENCH_CONTEXT" -o json \
    | jq -e '[.items[] | select(.status.phase == "Running")] | length > 0' >/dev/null
}

# Optional: extra cleanup beyond namespace deletion
scenario_cleanup() {
  local ns=$1
}
```

## Report Format

Reports are saved to `reports/<timestamp>/`:
- `report.json` — full results with per-scenario details
- `logs/scenario-NN.log` — agent output captured during each scenario

## Prerequisites

- `bash` 4.0+
- `docker`
- `kubectl`
- `k3d` or `kind`
- `jq`

For the kubeagent adapter:
- `kubeagent login` (must be authenticated)
- `node` 20+ (to run kubeagent)

## License

MIT
