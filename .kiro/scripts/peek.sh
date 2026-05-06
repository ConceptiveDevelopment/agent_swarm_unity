#!/bin/bash
# Read the current output of an agent window.
# Usage: bash .kiro/scripts/peek.sh <agent-name> [lines]
# Example: bash .kiro/scripts/peek.sh DEVELOPER-1 30

cd "$(dirname "$0")/../.."
source .kiro/scripts/swarm-env.sh

AGENT="$1"
LINES="${2:-20}"

if [ -z "$AGENT" ]; then
    echo "Usage: peek.sh <agent-name> [lines]"
    echo ""
    echo "Available agents:"
    swarm_list_panes 2>/dev/null | awk '{print "  " $2}'
    exit 0
fi

PANE_ID=$(swarm_pane_id "$AGENT")

if [ -z "$PANE_ID" ]; then
    echo "❌ Agent '$AGENT' not found."
    exit 1
fi

echo "=== $AGENT ($PANE_ID) ==="
tmux capture-pane -t "$PANE_ID" -p 2>/dev/null | tail -"$LINES"
