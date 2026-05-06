#!/bin/bash
# Task watcher — detects new task files and notifies agents via tmux.
# Usage: bash .kiro/scripts/task-watcher.sh [poll_interval]
#
# Watches for ALL task files: developer, architect, QA, product-owner, orchestrator.
# When a new task file appears, sends a message to the agent's pane.
# This ensures agents pick up tasks even if the sender's send-task.sh call was skipped.

cd "$(dirname "$0")/../.."
source .kiro/scripts/swarm-env.sh

POLL="${1:-5}"
NOTIFIED=""

echo "🐝 Task watcher (swarm $SWARM_PREFIX) every ${POLL}s — notifies agents of new tasks"

notify_if_new() {
    local TASK_FILE="$1"
    local AGENT="$2"

    [ ! -f "$TASK_FILE" ] && return

    echo "$NOTIFIED" | grep -q "$TASK_FILE" && return

    PANE_ID=$(swarm_pane_id "$AGENT")
    if [ -n "$PANE_ID" ]; then
        echo "$(date +%H:%M:%S) — 📋 Task detected: $TASK_FILE → notifying $AGENT"
        tmux send-keys -t "$PANE_ID" "You have a new task. Read $(pwd)/$TASK_FILE and begin." Enter 2>/dev/null
    fi

    NOTIFIED="$NOTIFIED $TASK_FILE"
}

while true; do
    sleep "$POLL"

    for N in 1 2 3 4; do
        notify_if_new ".kiro/swarm/task-developer-${N}.md" "DEVELOPER-${N}"
    done

    notify_if_new ".kiro/swarm/task-architect.md" "ARCHITECT"
    notify_if_new ".kiro/swarm/task-principal-qa.md" "PRINCIPAL-QA"
    notify_if_new ".kiro/swarm/task-product-owner.md" "PRODUCT-OWNER"
    notify_if_new ".kiro/swarm/task-orchestrator.md" "ORCHESTRATOR"

    # Clear notified list when task files are consumed
    for NOTED in $NOTIFIED; do
        [ -f "$NOTED" ] || NOTIFIED=$(echo "$NOTIFIED" | sed "s| $NOTED||")
    done
done
