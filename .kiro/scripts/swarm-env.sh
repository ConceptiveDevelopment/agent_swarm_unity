#!/bin/bash
# Shared environment for all swarm scripts.
# Sources config.json, resolves session name, loads pane manifest.
# Usage: source "$(dirname "$0")/swarm-env.sh"

SWARM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SWARM_CONFIG="$SWARM_DIR/.kiro/swarm/config.json"
SWARM_PANES="$SWARM_DIR/.kiro/swarm/panes.json"

# Read project prefix from config (uses project_name as namespace)
SWARM_PREFIX=$(python3 -c "
import json
c = json.load(open('$SWARM_CONFIG'))
name = c.get('project_name') or ''
print(name.replace(' ', '-').replace('/', '-'))
" 2>/dev/null)

if [ -z "$SWARM_PREFIX" ]; then
    echo "❌ No project ID in config.json — cannot resolve swarm namespace." >&2
    exit 1
fi

# Prefixed window name: e.g. "9558:ORCHESTRATOR"
swarm_window_name() {
    echo "${SWARM_PREFIX}:${1}"
}

# Strip prefix to get the logical agent name: "9558:ORCHESTRATOR" -> "ORCHESTRATOR"
swarm_agent_name() {
    echo "$1" | sed "s/^${SWARM_PREFIX}://"
}

# Resolve pane ID for a logical agent name (e.g. "ORCHESTRATOR")
# Uses panes.json manifest first, falls back to session-scoped tmux lookup.
swarm_pane_id() {
    local AGENT="$1"
    local PREFIXED
    PREFIXED=$(swarm_window_name "$AGENT")

    # Try manifest first
    if [ -f "$SWARM_PANES" ]; then
        local PID
        PID=$(python3 -c "
import json, sys
p = json.load(open('$SWARM_PANES'))
print(p.get(sys.argv[1], ''))
" "$AGENT" 2>/dev/null)
        if [ -n "$PID" ]; then
            echo "$PID"
            return 0
        fi
    fi

    # Fallback: session-scoped lookup by prefixed window name
    local SESSION
    SESSION=$(tmux display-message -p '#S' 2>/dev/null)
    if [ -n "$SESSION" ]; then
        tmux list-panes -t "$SESSION" -F '#{pane_id} #{window_name}' 2>/dev/null | \
            grep "$PREFIXED" | head -1 | awk '{print $1}'
        return 0
    fi

    return 1
}

# List all agent panes for THIS swarm (from manifest, with tmux info)
swarm_list_panes() {
    # Use manifest as source of truth — it's project-specific
    if [ -f "$SWARM_PANES" ]; then
        python3 -c "
import json
p = json.load(open('$SWARM_PANES'))
for name, pane_id in p.items():
    print(f'{pane_id} ${SWARM_PREFIX}:{name} bash')
" 2>/dev/null
        return 0
    fi

    # Fallback: session-scoped lookup
    local SESSION
    SESSION=$(tmux display-message -p '#S' 2>/dev/null)
    if [ -n "$SESSION" ]; then
        tmux list-panes -t "$SESSION" -F '#{pane_id} #{window_name} #{pane_current_command}' 2>/dev/null | \
            grep "^%.*${SWARM_PREFIX}:"
    fi
}
