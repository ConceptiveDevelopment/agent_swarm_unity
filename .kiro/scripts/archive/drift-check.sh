#!/bin/bash
# Drift detector — check if agents are staying on task.
# Usage: bash .kiro/scripts/drift-check.sh [interval_seconds]
#
# Every interval, compares each working agent's recent screen output
# against their task file keywords. If overlap drops below threshold,
# injects a re-anchoring reminder with the original task summary.

cd "$(dirname "$0")/../.."
source .kiro/scripts/swarm-env.sh

INTERVAL="${1:-300}"  # 5 minutes

echo "🧭 Drift detector (swarm $SWARM_PREFIX) every ${INTERVAL}s"

check_drift() {
    local AGENT="$1"
    local PANE_ID="$2"
    local TASK_FILE=".kiro/swarm/task-$(echo "$AGENT" | tr '[:upper:]' '[:lower:]').md"

    [ -f "$TASK_FILE" ] || return 0  # No task = nothing to drift from

    # Extract key terms from task file (issue number, title, file names, acceptance criteria)
    local TASK_KEYWORDS
    TASK_KEYWORDS=$(grep -E "^## (Title|Issue|Branch|Files to|Acceptance)" "$TASK_FILE" | \
        sed 's/^## [^:]*: *//' | tr ' /' '\n' | \
        grep -E '^[a-zA-Z]{3,}|^#[0-9]+|\.tsx?$|\.py$|\.rs$|\.go$' | \
        sort -u | head -20)

    [ -z "$TASK_KEYWORDS" ] && return 0

    # Get agent's recent screen output
    local SCREEN
    SCREEN=$(tmux capture-pane -t "$PANE_ID" -p 2>/dev/null | grep -v "^$" | tail -30)

    # Count how many task keywords appear in recent output
    local TOTAL=0
    local HITS=0
    for kw in $TASK_KEYWORDS; do
        TOTAL=$((TOTAL + 1))
        if echo "$SCREEN" | grep -qiF "$kw"; then
            HITS=$((HITS + 1))
        fi
    done

    [ "$TOTAL" -eq 0 ] && return 0

    local RATIO=$((HITS * 100 / TOTAL))

    if [ "$RATIO" -lt 15 ]; then
        # Extract task summary for re-anchoring
        local TITLE
        TITLE=$(grep -m1 "^## Title:" "$TASK_FILE" | sed 's/^## Title: *//')
        local ISSUE
        ISSUE=$(grep -m1 "^# Task:" "$TASK_FILE" | sed 's/^# Task: *//')

        echo "$(date +%H:%M:%S) — ⚠️ $AGENT drift detected (${RATIO}% task relevance)"
        echo "  Task: $ISSUE — $TITLE"

        tmux send-keys -t "$PANE_ID" "DRIFT CHECK: You may be off-task. Your assigned task is: $ISSUE — $TITLE. Review your task file at $TASK_FILE and refocus on the acceptance criteria. Do NOT work on unrelated code."
        sleep 0.3
        tmux send-keys -t "$PANE_ID" Enter 2>/dev/null
    fi
}

while true; do
    sleep "$INTERVAL"

    swarm_list_panes | grep -E "DEVELOPER|ARCHITECT|PRINCIPAL-QA" | while read PANE_ID WINDOW CMD; do
        AGENT=$(swarm_agent_name "$WINDOW")
        check_drift "$AGENT" "$PANE_ID"
    done
done
