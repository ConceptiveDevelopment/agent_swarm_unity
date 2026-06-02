#!/bin/bash
# Regenerate panes.json from live tmux session.
# Run at swarm startup or when panes.json is missing/stale.

cd "$(dirname "$0")/../.."
PANES_FILE=".kiro/swarm/panes.json"
CONFIG=".kiro/swarm/config.json"

PREFIX=$(python3 -c "import json; print(json.load(open('$CONFIG')).get('gitlab_project_id',''))" 2>/dev/null)
if [ -z "$PREFIX" ]; then
    echo "❌ No project ID in config.json"
    exit 1
fi

SESSION=$(tmux display-message -p '#S' 2>/dev/null)
if [ -z "$SESSION" ]; then
    echo "❌ Not in a tmux session"
    exit 1
fi

# Build panes.json from live tmux windows matching our prefix
echo "{" > "$PANES_FILE.tmp"
FIRST=true
tmux list-panes -s -F '#{pane_id} #{window_name}' 2>/dev/null | grep "${PREFIX}:" | while read PANE_ID WNAME; do
    AGENT=$(echo "$WNAME" | sed "s/^${PREFIX}://")
    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        echo "," >> "$PANES_FILE.tmp"
    fi
    printf '  "%s": "%s"' "$AGENT" "$PANE_ID" >> "$PANES_FILE.tmp"
done
echo "" >> "$PANES_FILE.tmp"
echo "}" >> "$PANES_FILE.tmp"

# Only replace if we got results
ENTRIES=$(grep -c "%" "$PANES_FILE.tmp" 2>/dev/null)
if [ "$ENTRIES" -gt 0 ]; then
    chmod 644 "$PANES_FILE" 2>/dev/null
    mv "$PANES_FILE.tmp" "$PANES_FILE"
    chmod 444 "$PANES_FILE"
    echo "✅ panes.json refreshed ($ENTRIES agents)"
else
    rm -f "$PANES_FILE.tmp"
    echo "⚠️ No agent panes found for prefix $PREFIX"
fi
