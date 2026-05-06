#!/bin/bash
# Heartbeat daemon — NON-AI stall detection via events.jsonl timestamps.
# Does NOT send messages to agents. Only escalates to orchestrator ONCE per stall.
# Usage: bash .kiro/scripts/heartbeat.sh [interval_seconds] [stale_threshold_seconds]

cd "$(dirname "$0")/../.."
source .kiro/scripts/swarm-env.sh

INTERVAL="${1:-60}"
STALE_THRESHOLD="${2:-600}"  # 10 minutes
EVENTS_FILE=".kiro/swarm/events.jsonl"
STATUS_FILE=".kiro/swarm/status.json"
ESCALATED="/tmp/swarm-escalated-${SWARM_PREFIX}"
mkdir -p "$ESCALATED"

echo "💓 Heartbeat daemon (non-AI) — checking every ${INTERVAL}s, stale after ${STALE_THRESHOLD}s"
echo "   Reads: events.jsonl + status.json"
echo "   Escalates: once per stall to orchestrator"

while true; do
    sleep "$INTERVAL"

    [ ! -f "$STATUS_FILE" ] && continue

    # Get agents with active tasks from status.json
    python3 -c "
import json, sys, time, os, glob

status = json.load(open('$STATUS_FILE'))
agents = status.get('agents', {})
events_file = '$EVENTS_FILE'
threshold = $STALE_THRESHOLD
escalated_dir = '$ESCALATED'
now = time.time()

# Read last event time per agent
last_event = {}
if os.path.exists(events_file):
    for line in open(events_file):
        try:
            e = json.loads(line.strip())
            agent = e.get('agent', '')
            ts = e.get('ts', 0)
            if ts > last_event.get(agent, 0):
                last_event[agent] = ts
        except:
            pass

# Check each working agent
stalled = []
for name, info in agents.items():
    if info.get('status') != 'working':
        continue
    
    last = last_event.get(name, 0)
    if last == 0:
        # No events yet — check if task file exists and is old
        task_file = f'.kiro/swarm/task-{name}.md'
        if name.startswith('developer-'):
            task_file = f'.kiro/swarm/task-{name}.md'
        if os.path.exists(task_file):
            last = os.path.getmtime(task_file)
    
    if last == 0:
        continue
    
    elapsed = now - last
    escalation_marker = os.path.join(escalated_dir, name)
    
    if elapsed > threshold:
        # Only escalate once per stall
        if not os.path.exists(escalation_marker):
            stalled.append((name, int(elapsed)))
            open(escalation_marker, 'w').write(str(now))
    else:
        # Agent is active — clear escalation marker
        if os.path.exists(escalation_marker):
            os.remove(escalation_marker)

for agent, elapsed in stalled:
    print(f'STALL:{agent}:{elapsed}')
" 2>/dev/null | while IFS=: read PREFIX AGENT ELAPSED; do
        [ "$PREFIX" != "STALL" ] && continue
        echo "$(date +%H:%M:%S) — ⚠️ $AGENT stalled (${ELAPSED}s no activity)"
        
        # Escalate to orchestrator ONCE
        ORCH_PANE=$(swarm_pane_id "ORCHESTRATOR")
        if [ -n "$ORCH_PANE" ]; then
            tmux send-keys -t "$ORCH_PANE" "STALL ALERT: $AGENT has had no activity for ${ELAPSED}s. Check if it needs a nudge or reassignment." Enter 2>/dev/null
        fi
    done
done
