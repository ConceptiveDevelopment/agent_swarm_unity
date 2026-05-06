#!/bin/bash
# Boundary guard — detect agents accessing files outside the project.
# Usage: bash .kiro/scripts/boundary-guard.sh [interval_seconds]
#
# Scans agent screen output for file paths outside $PROJECT_DIR.
# Logs warnings and notifies the orchestrator.

cd "$(dirname "$0")/../.."
source .kiro/scripts/swarm-env.sh

INTERVAL="${1:-30}"
PROJECT_DIR="$SWARM_DIR"

echo "🛡️ Boundary guard (swarm $SWARM_PREFIX) every ${INTERVAL}s"
echo "   Project: $PROJECT_DIR"

while true; do
    sleep "$INTERVAL"

    swarm_list_panes | grep -E "DEVELOPER|ARCHITECT|PRINCIPAL-QA|ORCHESTRATOR" | while read PANE_ID WINDOW CMD; do
        AGENT=$(swarm_agent_name "$WINDOW")

        # Get recent screen output
        SCREEN=$(tmux capture-pane -t "$PANE_ID" -p 2>/dev/null | tail -20)

        # Look for absolute paths outside the project
        FOREIGN_PATHS=$(echo "$SCREEN" | grep -oE '/Users/[^ ]+' | \
            grep -vF "$PROJECT_DIR" | \
            grep -v "/tmp/" | \
            grep -v "/dev/" | \
            grep -v "/usr/" | \
            grep -v "/bin/" | \
            grep -v "/var/" | \
            grep -v "/etc/" | \
            grep -v "/opt/" | \
            grep -v "/System/" | \
            grep -v "/Library/" | \
            grep -v "/private/" | \
            grep -v "\.kiro/scripts/" | \
            grep -v "\.gitconfig" | \
            grep -v "\.ssh/" | \
            sort -u)

        if [ -n "$FOREIGN_PATHS" ]; then
            echo "$(date +%H:%M:%S) — 🚨 $AGENT accessing files outside project:"
            echo "$FOREIGN_PATHS" | while read fp; do
                echo "  $fp"
            done

            # Warn the agent
            tmux send-keys -t "$PANE_ID" "BOUNDARY WARNING: You are accessing files outside your project ($PROJECT_DIR). Stay within your project directory. Do NOT read or modify files in other projects."
            sleep 0.3
            tmux send-keys -t "$PANE_ID" Enter 2>/dev/null
        fi
    done
done
