#!/bin/bash
# PO notifier — watches for completed tasks and nudges PO to report.
# Usage: bash .kiro/scripts/po-notifier.sh [poll_interval]
#
# Checks status.json for newly closed issues.
# When new closures detected, sends PO a message to update the human.

cd "$(dirname "$0")/../.."
source .kiro/scripts/swarm-env.sh

POLL="${1:-30}"
LAST_CLOSED_FILE="/tmp/swarm-po-notifier-${SWARM_PREFIX}"
STATUS=".kiro/swarm/status.json"

# Initialize with current closed set
python3 -c "
import json, os

seen = set()

if os.path.exists('$STATUS'):
    s = json.load(open('$STATUS'))
    for tid, t in s.get('tasks', {}).items():
        if t.get('status') == 'closed':
            seen.add(tid)

with open('$LAST_CLOSED_FILE', 'w') as f:
    f.write(' '.join(sorted(seen)))
" 2>/dev/null

echo "📢 PO notifier (swarm $SWARM_PREFIX) every ${POLL}s — checks status.json"

while true; do
    sleep "$POLL"

    # Get currently closed from status.json
    CURRENT=$(python3 -c "
import json, os

seen = set()

if os.path.exists('$STATUS'):
    s = json.load(open('$STATUS'))
    for tid, t in s.get('tasks', {}).items():
        if t.get('status') == 'closed':
            seen.add(tid)

print(' '.join(sorted(seen)))
" 2>/dev/null)

    [ -z "$CURRENT" ] && continue

    PREV=""
    [ -f "$LAST_CLOSED_FILE" ] && PREV=$(cat "$LAST_CLOSED_FILE")

    # Find newly closed
    NEW=""
    for tid in $CURRENT; do
        if ! echo " $PREV " | grep -qF " $tid "; then
            NEW="$NEW $tid"
        fi
    done

    if [ -n "$NEW" ]; then
        # Get titles from status.json
        DETAILS=$(python3 -c "
import json, sys, os
new_ids = sys.argv[1].split()
if os.path.exists('$STATUS'):
    s = json.load(open('$STATUS'))
    parts = []
    for tid in new_ids:
        t = s.get('tasks', {}).get(tid, {})
        title = t.get('title', '')[:40]
        parts.append(f'{tid} {title}')
    total = sum(1 for t in s.get('tasks',{}).values() if t.get('status')=='closed')
    if parts:
        print(f'Completed: {\"; \".join(parts)}. Total closed: {total}.')
    else:
        print(f'New closures: {\", \".join(new_ids)}.')
else:
    print(f'New closures: {\", \".join(new_ids)}.')
" "$NEW" 2>/dev/null)

        echo "$(date +%H:%M:%S) — New closures:$NEW"

        PO_PANE=$(swarm_pane_id "PRODUCT-OWNER")
        if [ -n "$PO_PANE" ]; then
            tmux send-keys -t "$PO_PANE" "SESSION UPDATE: $DETAILS Report this progress to the human."
            sleep 0.3
            tmux send-keys -t "$PO_PANE" Enter 2>/dev/null
            echo "$(date +%H:%M:%S) — Notified PO"
        fi

        echo "$CURRENT" > "$LAST_CLOSED_FILE"
    fi
done
