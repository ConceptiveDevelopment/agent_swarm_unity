#!/bin/bash
# Notify the Product Owner via tmux message.
# Called by the orchestrator on key state transitions.
# Usage: bash .kiro/scripts/notify-po.sh <event-type> <message>
#
# Event types:
#   issue-done      — An issue was merged and moved to Done
#   batch-done      — All issues in current batch completed
#   issue-blocked   — A developer reported BLOCKED status
#   qa-fail         — QA rejected a PR
#   backlog-empty   — No issues left to assign
#
# Examples:
#   bash .kiro/scripts/notify-po.sh issue-done "CDEV-358 Grouped bottom dock HUD"
#   bash .kiro/scripts/notify-po.sh batch-done "3 issues closed this batch"
#   bash .kiro/scripts/notify-po.sh backlog-empty "All issues Done or Canceled"

cd "$(dirname "$0")/../.."
source .kiro/scripts/swarm-env.sh

EVENT_TYPE="$1"
shift
DETAIL="$*"

if [ -z "$EVENT_TYPE" ] || [ -z "$DETAIL" ]; then
    echo "Usage: notify-po.sh <event-type> <message>"
    exit 1
fi

# Track completed count for batch summaries
COUNT_FILE=".kiro/swarm/.completed-count"

case "$EVENT_TYPE" in
    issue-done)
        # Increment completed count
        COUNT=$(cat "$COUNT_FILE" 2>/dev/null || echo 0)
        COUNT=$((COUNT + 1))
        echo "$COUNT" > "$COUNT_FILE"
        MSG="SESSION UPDATE: Completed: ${DETAIL}. Total closed: ${COUNT}. Report this progress to the human."
        ;;
    batch-done)
        COUNT=$(cat "$COUNT_FILE" 2>/dev/null || echo 0)
        MSG="SESSION UPDATE: Batch complete — ${DETAIL}. Total closed: ${COUNT}. Swarm idle. Report this progress to the human."
        # Reset counter
        echo 0 > "$COUNT_FILE"
        ;;
    issue-blocked)
        MSG="BLOCKED: ${DETAIL}. Read .kiro/swarm/task-product-owner.md for details."
        ;;
    qa-fail)
        MSG="QA FAIL: ${DETAIL}. Developer cycling back to fix."
        ;;
    backlog-empty)
        MSG="SESSION UPDATE: ${DETAIL}. Swarm idle. Read .kiro/swarm/task-product-owner.md — need next scope or session-end decision."
        ;;
    *)
        MSG="ORCHESTRATOR: [${EVENT_TYPE}] ${DETAIL}"
        ;;
esac

# Send to PO via tmux
PANE_ID=$(swarm_pane_id "PRODUCT-OWNER")
if [ -z "$PANE_ID" ]; then
    # Fallback name
    PANE_ID=$(swarm_pane_id "PO")
fi

if [ -n "$PANE_ID" ]; then
    tmux send-keys -t "$PANE_ID" "$MSG" Enter
    echo "✅ PO notified: $MSG"
else
    echo "⚠️  PO pane not found — writing to task file instead"
    cat > .kiro/swarm/task-product-owner.md << TASK
# Task: Orchestrator Notification
## Type: ${EVENT_TYPE}
## Message: ${DETAIL}
TASK
    echo "📝 Written to task-product-owner.md"
fi
