#!/bin/bash
# stop hook — remind orchestrator to update Linear when state changes.
# Checks if response mentions task actions without corresponding issue updates.
# STDOUT reminder gets injected into orchestrator context.

cd "$(dirname "$0")/../../.."

EVENT=$(cat)

RESPONSE=$(echo "$EVENT" | python3 -c "
import json, sys
e = json.load(sys.stdin)
print(e.get('assistant_response', ''))
" 2>/dev/null)

[ -z "$RESPONSE" ] && exit 0

# Check for state-changing actions that need Linear updates
NEEDS_UPDATE=false
REASON=""

if echo "$RESPONSE" | grep -qiE "assigned.*developer|task.*assigned|sending.*task"; then
    if ! echo "$RESPONSE" | grep -qi "linear\|issue.*update\|In Progress"; then
        NEEDS_UPDATE=true
        REASON="task assignment"
    fi
fi

if echo "$RESPONSE" | grep -qiE "merged.*branch|merge.*complete|merging"; then
    if ! echo "$RESPONSE" | grep -qi "linear\|issue.*Done\|moved.*Done"; then
        NEEDS_UPDATE=true
        REASON="branch merge"
    fi
fi

if echo "$RESPONSE" | grep -qiE "closing.*issue|issue.*closed|task.*complete.*closed"; then
    if ! echo "$RESPONSE" | grep -qi "linear\|moved.*Done"; then
        NEEDS_UPDATE=true
        REASON="issue closure"
    fi
fi

if $NEEDS_UPDATE; then
    echo "⚠️ LINEAR REMINDER: You performed a $REASON but did not update Linear. Move the issue to the correct state and add a comment. Linear is the source of truth."
fi

exit 0
