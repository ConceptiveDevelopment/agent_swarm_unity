#!/bin/bash
# stop hook — prevent idle agents from self-directed activity.
# If no task file exists for this agent, inject "stay idle" message.
# Applied to: engineer, architect, principal-qa (NOT orchestrator or PO).

cd "$(dirname "$0")/../../.."

# Determine which task file to check
N="${AGENT_NUMBER:-}"
if [ -n "$N" ]; then
    TASK_FILE=".kiro/swarm/task-developer-${N}.md"
elif [ -n "$AGENT_NAME" ]; then
    TASK_FILE=".kiro/swarm/task-${AGENT_NAME}.md"
else
    exit 0
fi

# If no task file exists, suppress activity
if [ ! -f "$TASK_FILE" ]; then
    echo "⏸️ No task assigned. Stay idle — do not take any action. Wait for the orchestrator to assign you a task via your task file."
fi

exit 0
