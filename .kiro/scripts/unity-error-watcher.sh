#!/bin/bash
# unity-error-watcher.sh — Monitors Unity Editor.log for errors and notifies the active agent.
# Runs in the WATCHERS window. Detects errors, checks if agent is mid-generation or idle,
# then either interrupts (Ctrl+C) + sends, or just sends the error message.

set -e
cd "$(dirname "$0")/../.."
source .kiro/scripts/swarm-env.sh

UNITY_LOG="$HOME/Library/Logs/Unity/Editor.log"
ERROR_LOG=".kiro/swarm/unity-errors.log"
POLL_INTERVAL=3
LAST_SIZE=0

# Initialize error log
touch "$ERROR_LOG"

# Get the file size to start tailing from current position
if [ -f "$UNITY_LOG" ]; then
    LAST_SIZE=$(wc -c < "$UNITY_LOG" | tr -d ' ')
fi

echo "🔴 Unity error watcher started (polling ${POLL_INTERVAL}s)"
echo "   Watching: $UNITY_LOG"

# Check if a pane is idle (at prompt) or generating
is_pane_idle() {
    local PANE_ID="$1"
    local SCREEN
    SCREEN=$(tmux capture-pane -t "$PANE_ID" -p 2>/dev/null | tail -5)
    
    # Kiro CLI shows these patterns when idle/at prompt
    if echo "$SCREEN" | grep -qE '^\s*[>❯›\$]\s*$|waiting for|Idle|Task complete'; then
        return 0  # idle
    fi
    return 1  # generating/working
}

# Send error to the active agent
notify_agent() {
    local ERROR_MSG="$1"
    
    # Find the active developer from status.json
    local ACTIVE_AGENT
    ACTIVE_AGENT=$(python3 -c "
import json, sys
try:
    s = json.load(open('.kiro/swarm/status.json'))
    agents = s.get('agents', {})
    for name, info in agents.items():
        if info.get('status') == 'working' and 'developer' in name:
            print(name.upper().replace('DEVELOPER', 'DEVELOPER-'))
            sys.exit(0)
    # No active developer, try orchestrator
    print('ORCHESTRATOR')
except:
    print('ORCHESTRATOR')
" 2>/dev/null)
    
    # Resolve pane ID
    local PANE_ID
    PANE_ID=$(swarm_pane_id "$ACTIVE_AGENT" 2>/dev/null)
    
    if [ -z "$PANE_ID" ]; then
        echo "   ⚠️  Could not resolve pane for $ACTIVE_AGENT"
        return
    fi
    
    echo "   → Notifying $ACTIVE_AGENT ($PANE_ID)"
    
    # Check if agent is idle or working
    if is_pane_idle "$PANE_ID"; then
        # Idle — just send the message
        tmux send-keys -t "$PANE_ID" "⚠️ UNITY ERROR detected: $ERROR_MSG — check .kiro/swarm/unity-errors.log and fix before continuing"
        sleep 0.2
        tmux send-keys -t "$PANE_ID" Enter
    else
        # Working — interrupt first, then send
        tmux send-keys -t "$PANE_ID" C-c
        sleep 1
        tmux send-keys -t "$PANE_ID" "⚠️ UNITY ERROR interrupted your work: $ERROR_MSG — fix this error before continuing your task. Check .kiro/swarm/unity-errors.log for full details."
        sleep 0.2
        tmux send-keys -t "$PANE_ID" Enter
    fi
}

while true; do
    sleep "$POLL_INTERVAL"
    
    # Check if log file exists and has grown
    if [ ! -f "$UNITY_LOG" ]; then
        continue
    fi
    
    CURRENT_SIZE=$(wc -c < "$UNITY_LOG" | tr -d ' ')
    
    if [ "$CURRENT_SIZE" -le "$LAST_SIZE" ]; then
        # File was truncated or unchanged
        if [ "$CURRENT_SIZE" -lt "$LAST_SIZE" ]; then
            LAST_SIZE=0  # Reset on truncation
        fi
        continue
    fi
    
    # Read new content and filter for errors
    NEW_ERRORS=$(tail -c +"$((LAST_SIZE + 1))" "$UNITY_LOG" 2>/dev/null | \
        grep -iE "^(Error|Exception|NullReference|MissingReference|IndexOutOfRange|InvalidOperation|Assertion failed)" | \
        grep -v "^Error\s*$" | \
        head -5)
    
    LAST_SIZE=$CURRENT_SIZE
    
    if [ -n "$NEW_ERRORS" ]; then
        # Log errors
        echo "$(date '+%H:%M:%S') — Unity errors detected:" >> "$ERROR_LOG"
        echo "$NEW_ERRORS" >> "$ERROR_LOG"
        echo "---" >> "$ERROR_LOG"
        
        # Keep error log trimmed to last 100 lines
        tail -100 "$ERROR_LOG" > "$ERROR_LOG.tmp" && mv "$ERROR_LOG.tmp" "$ERROR_LOG"
        
        # Get first error line for notification
        FIRST_ERROR=$(echo "$NEW_ERRORS" | head -1 | cut -c1-120)
        echo "$(date '+%H:%M:%S') 🔴 $FIRST_ERROR"
        
        # Notify the active agent
        notify_agent "$FIRST_ERROR"
    fi
done
