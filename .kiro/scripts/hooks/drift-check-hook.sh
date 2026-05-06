#!/bin/bash
# stop hook — check if agent is drifting from assigned task.
# Reads assistant_response from STDIN JSON.
# STDOUT is injected into agent context as a reminder.

cd "$(dirname "$0")/../../.."

EVENT=$(cat)

# Determine task file
N="${AGENT_NUMBER:-}"
if [ -n "$N" ]; then
    TASK_FILE=".kiro/swarm/task-developer-${N}.md"
else
    # Try to detect from agent name in cwd or env
    exit 0
fi

[ -f "$TASK_FILE" ] || exit 0

# Extract keywords from task file
KEYWORDS=$(grep -E "^## (Title|Issue|Branch|Files to)" "$TASK_FILE" | \
    sed 's/^## [^:]*: *//' | tr ' /' '\n' | \
    grep -E '^[a-zA-Z]{4,}|^#[0-9]+' | sort -u | head -15)

[ -z "$KEYWORDS" ] && exit 0

# Extract response text
RESPONSE=$(echo "$EVENT" | python3 -c "
import json, sys
e = json.load(sys.stdin)
print(e.get('assistant_response', '')[:2000])
" 2>/dev/null)

[ -z "$RESPONSE" ] && exit 0

# Count keyword hits
TOTAL=0
HITS=0
for kw in $KEYWORDS; do
    TOTAL=$((TOTAL + 1))
    if echo "$RESPONSE" | grep -qiF "$kw"; then
        HITS=$((HITS + 1))
    fi
done

[ "$TOTAL" -eq 0 ] && exit 0

RATIO=$((HITS * 100 / TOTAL))

if [ "$RATIO" -lt 10 ]; then
    TITLE=$(grep -m1 "^## Title:" "$TASK_FILE" | sed 's/^## Title: *//')
    ISSUE=$(grep -m1 "^# Task:" "$TASK_FILE" | sed 's/^# Task: *//')
    echo "⚠️ DRIFT WARNING: Your response has low relevance (${RATIO}%) to your assigned task: $ISSUE — $TITLE. Refocus on the acceptance criteria in your task file."
fi

exit 0
