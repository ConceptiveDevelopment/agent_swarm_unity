#!/bin/bash
# List all agent windows and their status.
# Usage: bash .kiro/scripts/agents.sh

cd "$(dirname "$0")/../.."
source .kiro/scripts/swarm-env.sh

echo "🐝 Agent Swarm Status ($SWARM_PREFIX)"
echo ""

swarm_list_panes | while read PANE_ID WINDOW CMD; do
    AGENT=$(swarm_agent_name "$WINDOW")

    # Check for done/task files
    AGENT_LOWER=$(echo "$AGENT" | tr '[:upper:]' '[:lower:]')
    DONE_FILE=".kiro/swarm/done-${AGENT_LOWER}.md"
    TASK_FILE=".kiro/swarm/task-${AGENT_LOWER}.md"

    STATUS="idle"
    if [ -f "$DONE_FILE" ]; then
        STATUS="✅ done"
    elif [ -f "$TASK_FILE" ]; then
        STATUS="⏳ working"
    fi

    # Check if waiting for permission
    SCREEN=$(tmux capture-pane -t "$PANE_ID" -p 2>/dev/null | tail -3)
    if echo "$SCREEN" | grep -q "\[y/n"; then
        STATUS="🔒 waiting for permission"
    fi

    printf "  %-15s %s — %s\n" "$AGENT" "$PANE_ID" "$STATUS"
done

echo ""
echo "Commands:"
echo "  bash .kiro/scripts/send-task.sh <agent> <message>"
echo "  bash .kiro/scripts/peek.sh <agent> [lines]"
