#!/bin/bash
# Progress reporter — posts incremental engineer updates to Linear issues.
# Usage: bash .kiro/scripts/progress-report.sh [interval_seconds]
#
# Every interval, checks each working developer's screen output and posts
# a brief progress summary as a Linear issue comment. Creates an audit
# trail that survives agent crashes.

cd "$(dirname "$0")/../.."
source .kiro/scripts/swarm-env.sh

INTERVAL="${1:-600}"  # 10 minutes
LAST_REPORT_DIR="/tmp/swarm-progress-${SWARM_PREFIX}"
rm -rf "$LAST_REPORT_DIR"
mkdir -p "$LAST_REPORT_DIR"

echo "📝 Progress reporter (swarm $SWARM_PREFIX) every ${INTERVAL}s"

while true; do
    sleep "$INTERVAL"

    # Find working developers from status.json
    if [ ! -f ".kiro/swarm/status.json" ]; then
        continue
    fi

    python3 -c "
import json
s = json.load(open('.kiro/swarm/status.json'))
for name, a in s.get('agents', {}).items():
    if a.get('status') == 'working' and a.get('current_task') and name.startswith('developer'):
        task = a['current_task']
        issue_num = task.replace('#', '')
        print(f'{name} {issue_num}')
" 2>/dev/null | while read AGENT ISSUE_NUM; do
        AGENT_UPPER=$(echo "$AGENT" | tr '[:lower:]' '[:upper:]')
        PANE_ID=$(swarm_pane_id "$AGENT_UPPER")
        [ -z "$PANE_ID" ] && continue

        # Get recent screen output (meaningful lines only)
        SCREEN=$(tmux capture-pane -t "$PANE_ID" -p 2>/dev/null | \
            grep -v "^$" | grep -v "^─" | grep -v "Trust All" | \
            grep -v "engineer ·" | grep -v "ask a question" | \
            grep -v "/copy" | grep -v "Kiro is working" | \
            grep -v "Thinking" | grep -v "esc to cancel" | \
            tail -5 | head -3)

        [ -z "$SCREEN" ] && continue

        # Check if output changed since last report
        HASH=$(echo "$SCREEN" | md5 -q 2>/dev/null || echo "$SCREEN" | md5sum 2>/dev/null | awk '{print $1}')
        LAST_FILE="$LAST_REPORT_DIR/$AGENT"
        if [ -f "$LAST_FILE" ] && [ "$(cat "$LAST_FILE")" = "$HASH" ]; then
            continue  # No change since last report
        fi
        echo "$HASH" > "$LAST_FILE"

        # Post progress comment to Linear
        SUMMARY=$(echo "$SCREEN" | tr '\n' ' ' | sed 's/  */ /g' | cut -c1-200)
        glab issue note "$ISSUE_NUM" --message "🔄 **Progress update** ($AGENT): $SUMMARY" 2>/dev/null && \
            echo "$(date +%H:%M:%S) — Posted progress for $AGENT on #$ISSUE_NUM" || \
            echo "$(date +%H:%M:%S) — ⚠️ Failed to post progress for $AGENT"
    done
done
