#!/usr/bin/env bash
# agents/manual.sh — no-agent baseline (inject faults, observe only)

agent_name()       { echo "manual"; }
agent_setup()      { log_info "Manual mode — no agent will attempt fixes"; }
agent_start()      { touch "$REPORT_DIR/agent-output.log"; AGENT_PID=0; export AGENT_PID; }
agent_stop()       { :; }
agent_is_running() { return 0; }
