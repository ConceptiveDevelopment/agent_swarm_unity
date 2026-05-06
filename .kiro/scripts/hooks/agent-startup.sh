#!/bin/bash
# agentSpawn hook — inject project context on agent initialization.
# STDOUT is added to the agent's context automatically.
# Reads config, status, memory and outputs a summary.

cd "$(dirname "$0")/../../.."

CONFIG=".kiro/swarm/config.json"
STATUS=".kiro/swarm/status.json"
MEMORY=".kiro/swarm/memory.md"
VISION=".kiro/swarm/vision.md"

echo "=== SWARM CONTEXT ==="

if [ -f "$CONFIG" ]; then
    echo "Project: $(python3 -c "import json; c=json.load(open('$CONFIG')); print(c.get('project_name','unknown'))" 2>/dev/null)"
    echo "GitHub: $(python3 -c "import json; c=json.load(open('$CONFIG')); print(c.get('github_repo',''))" 2>/dev/null)"
    echo "Issues: Linear"
    echo "Build: $(python3 -c "import json; c=json.load(open('$CONFIG')); print(c.get('build_command','none'))" 2>/dev/null)"
    echo "Test: $(python3 -c "import json; c=json.load(open('$CONFIG')); print(c.get('test_command','none'))" 2>/dev/null)"
fi

if [ -f "$STATUS" ]; then
    echo ""
    python3 -c "
import json
s = json.load(open('$STATUS'))
tasks = s.get('tasks', {})
agents = s.get('agents', {})
wip = [f'{k}: {v[\"title\"]}' for k,v in tasks.items() if v.get('status') == 'in_progress']
blocked = [f'{k}: blocked by {v[\"blocked_by\"]}' for k,v in tasks.items() if v.get('status') == 'blocked']
if wip: print('In progress: ' + '; '.join(wip))
if blocked: print('Blocked: ' + '; '.join(blocked))
if not wip and not blocked: print('No active tasks.')
" 2>/dev/null
fi

if [ -f "$MEMORY" ]; then
    RECENT=$(tail -20 "$MEMORY" | grep "^## " | tail -3)
    if [ -n "$RECENT" ]; then
        echo ""
        echo "Recent memory:"
        echo "$RECENT"
    fi
fi

echo "=== END CONTEXT ==="
