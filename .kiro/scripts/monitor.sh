#!/bin/bash
# Monitor all agent windows. Auto-approve permission prompts. Detect crashes.
# Usage: bash .kiro/scripts/monitor.sh [poll_interval]
# Runs until Ctrl+C or all agent windows close.

cd "$(dirname "$0")/../.."
source .kiro/scripts/swarm-env.sh

POLL_INTERVAL="${1:-5}"

echo "🐝 Monitoring agent windows every ${POLL_INTERVAL}s (swarm $SWARM_PREFIX)"
echo "   Auto-approving permission prompts (y/n/t → t)"
echo "   Detecting agent crashes"
echo "   Ctrl+C to stop"
echo ""

while true; do
    sleep "$POLL_INTERVAL"

    AGENT_PANES=$(swarm_list_panes | grep -E "ORCHESTRATOR|ARCHITECT|PRINCIPAL-QA|DEVELOPER")

    if [ -z "$AGENT_PANES" ]; then
        echo "$(date +%H:%M:%S) — No agent windows running. Done."
        break
    fi

    echo "$AGENT_PANES" | while read PANE_ID WINDOW CMD; do
        AGENT=$(swarm_agent_name "$WINDOW")
        SCREEN=$(tmux capture-pane -t "$PANE_ID" -p 2>/dev/null | tail -5)

        # Check for permission prompts
        if echo "$SCREEN" | grep -q "\[y/n/t\]"; then
            tmux send-keys -t "$PANE_ID" "t" Enter 2>/dev/null
            echo "$(date +%H:%M:%S) — $AGENT: trusted tool (t)"
        elif echo "$SCREEN" | grep -q "\[y/n\]"; then
            tmux send-keys -t "$PANE_ID" "y" Enter 2>/dev/null
            echo "$(date +%H:%M:%S) — $AGENT: approved (y)"
        fi

        # Check for agent crashes
        if echo "$SCREEN" | grep -q "Agent exited"; then
            AGENT_LOWER=$(echo "$AGENT" | tr '[:upper:]' '[:lower:]')
            CRASH_MARKER=".kiro/swarm/crashed-${AGENT_LOWER}"
            if [ ! -f "$CRASH_MARKER" ]; then
                touch "$CRASH_MARKER"
                echo "$(date +%H:%M:%S) — ⚠️ $AGENT CRASHED"
                ORCH_PANE=$(swarm_pane_id "ORCHESTRATOR")
                if [ -n "$ORCH_PANE" ]; then
                    tmux send-keys -t "$ORCH_PANE" "WARNING: $AGENT has crashed. Check its task and reassign if needed." Enter 2>/dev/null
                fi
            fi
        fi

        # Check for done files
        AGENT_LOWER=$(echo "$AGENT" | tr '[:upper:]' '[:lower:]')
        DONE_FILE=".kiro/swarm/done-${AGENT_LOWER}.md"
        if [ -f "$DONE_FILE" ]; then
            echo "$(date +%H:%M:%S) — $AGENT: ✅ DONE (see $DONE_FILE)"
        fi
    done
done
