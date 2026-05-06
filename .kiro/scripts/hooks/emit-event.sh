#!/bin/bash
# stop hook — append structured event to events.jsonl for progress tracking.
# Emits: agent name, timestamp, event type (inferred from response content).

cd "$(dirname "$0")/../../.."

EVENT=$(cat)
EVENTS_FILE=".kiro/swarm/events.jsonl"

# Determine agent identity
N="${AGENT_NUMBER:-}"
if [ -n "$N" ]; then
    AGENT="developer-${N}"
elif [ -n "$AGENT_NAME" ]; then
    AGENT="$AGENT_NAME"
else
    exit 0
fi

# Only log if agent has a task (skip idle chatter)
TASK_FILE=".kiro/swarm/task-${AGENT}.md"
[ -n "$N" ] && TASK_FILE=".kiro/swarm/task-developer-${N}.md"
[ -f "$TASK_FILE" ] || exit 0

python3 -c "
import json, sys, time

event = json.load(sys.stdin)
response = event.get('assistant_response', '')[:500]

# Infer event type from response content
etype = 'progress'
if 'Task complete' in response or 'idle' in response.lower():
    etype = 'done'
elif 'git push' in response or 'pushed' in response.lower():
    etype = 'push'
elif 'build' in response.lower() and ('pass' in response.lower() or 'success' in response.lower()):
    etype = 'build-pass'

entry = {
    'ts': time.time(),
    'agent': '$AGENT',
    'type': etype,
}

with open('$EVENTS_FILE', 'a') as f:
    f.write(json.dumps(entry) + '\n')
" <<< "$EVENT" 2>/dev/null

exit 0
