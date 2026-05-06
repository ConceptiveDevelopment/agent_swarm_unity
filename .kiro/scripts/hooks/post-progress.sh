#!/bin/bash
# stop hook — log engineer progress after each turn.
# Only fires for engineers (checks AGENT_NUMBER).
# Progress is tracked locally; Linear updates happen at task completion.

cd "$(dirname "$0")/../../.."

N="${AGENT_NUMBER:-}"
[ -z "$N" ] && exit 0

TASK_FILE=".kiro/swarm/task-developer-${N}.md"
[ -f "$TASK_FILE" ] || exit 0

# No-op for now — Linear updates happen in the done file flow.
# This hook can be extended to post progress comments if needed.

exit 0
