#!/bin/bash
# preToolUse hook — block writes to files not in the engineer's task assignment.
# Exit 0 = allow, Exit 2 = block.

cd "$(dirname "$0")/../../.."

EVENT=$(cat)

TARGET=$(echo "$EVENT" | python3 -c "
import json, sys
e = json.load(sys.stdin)
inp = e.get('tool_input', {})
print(inp.get('path', ''))
" 2>/dev/null)

[ -z "$TARGET" ] && exit 0

# Always allow swarm infrastructure files
case "$TARGET" in
    *.kiro/swarm/*|*done-*|*task-*|*brief-*|*memory.md|*status.*|*panes.json|*.completed-count)
        exit 0 ;;
esac

# Find the engineer's task file
N="${AGENT_NUMBER:-}"
if [ -z "$N" ]; then
    exit 0  # Can't determine task file, allow
fi

TASK_FILE=".kiro/swarm/task-developer-${N}.md"
[ -f "$TASK_FILE" ] || exit 0  # No task file = idle, allow

# Extract allowed files from task
ALLOWED=$(grep -A50 "^## Files to create:\|^## Files to modify:" "$TASK_FILE" | \
    grep -E "^- " | sed 's/^- //' | sed 's/ .*//')

[ -z "$ALLOWED" ] && exit 0  # No file list in task, allow

# Normalize target path (strip leading ./ or project dir)
NORM_TARGET=$(echo "$TARGET" | sed "s|^$(pwd)/||" | sed 's|^\./||')

# Check if target is in allowed list
if echo "$ALLOWED" | grep -qF "$NORM_TARGET"; then
    exit 0
fi

echo "SCOPE VIOLATION: Writing to '$NORM_TARGET' which is not in your task assignment. Your task lists: $(echo "$ALLOWED" | tr '\n' ', '). Only modify files listed in your task file." >&2
exit 2
