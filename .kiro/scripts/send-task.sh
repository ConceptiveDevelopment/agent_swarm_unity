#!/bin/bash
# Send a task to an agent via tmux.
# Usage: bash .kiro/scripts/send-task.sh <agent-name> <message>
# Example: bash .kiro/scripts/send-task.sh DEVELOPER-1 "Implement the login screen"

cd "$(dirname "$0")/../.."
source .kiro/scripts/swarm-env.sh

AGENT="$1"
shift
MESSAGE="$*"

if [ -z "$AGENT" ] || [ -z "$MESSAGE" ]; then
    echo "Usage: send-task.sh <agent-name> <message>"
    echo "Agents: ORCHESTRATOR, ARCHITECT, PRINCIPAL-QA, DEVELOPER-1, DEVELOPER-2, etc."
    exit 1
fi

PANE_ID=$(swarm_pane_id "$AGENT")

if [ -z "$PANE_ID" ]; then
    echo "❌ Agent '$AGENT' not found. Available:"
    swarm_list_panes 2>/dev/null | awk '{print "  " $2}'
    exit 1
fi

tmux send-keys -t "$PANE_ID" "$MESSAGE" Enter
echo "✅ Sent to $AGENT ($PANE_ID)"
