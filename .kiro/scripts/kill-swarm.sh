#!/bin/bash
# Kill all swarm windows for this project.
# Usage: bash .kiro/scripts/kill-swarm.sh
#
# Identifies swarm windows by the project ID prefix from config.json.
# Only kills windows belonging to THIS project — safe with multiple swarms.

cd "$(dirname "$0")/../.."
source .kiro/scripts/swarm-env.sh

echo "🐝 Killing swarm $SWARM_PREFIX..."

# Collect pane IDs first (stable, unlike window indices which shift on kill)
PANES=$(tmux list-panes -a -F '#{pane_id} #{window_name} #{session_name}' 2>/dev/null | \
    grep "${SWARM_PREFIX}:" | awk '{print $1, $2}')

if [ -z "$PANES" ]; then
    echo "   No swarm windows found."
else
    echo "$PANES" | while read PANE_ID WIN_NAME; do
        tmux kill-pane -t "$PANE_ID" 2>/dev/null && echo "   ✗ $WIN_NAME"
    done
fi

# Clean up runtime files
rm -f .kiro/swarm/task-*.md \
      .kiro/swarm/done-*.md \
      .kiro/swarm/brief-*.md \
      .kiro/swarm/crashed-* \
      .kiro/swarm/panes.json

echo ""
echo "✅ Swarm $SWARM_PREFIX killed. Runtime files cleaned."
