#!/bin/bash
# Watch for done files, validate them, notify orchestrator, and trigger maintenance.
# Usage: bash .kiro/scripts/watch-done.sh [poll_interval]
# Note: No set -e — this is a long-running critical watcher that must survive transient errors.

cd "$(dirname "$0")/../.."
source .kiro/scripts/swarm-env.sh || { echo "❌ Failed to source swarm-env.sh"; exit 1; }

POLL="${1:-5}"
NOTIFIED=""
COMPLETED_COUNT=0
COMPACT_EVERY=5
ANCHOR_EVERY=3
COUNTER_FILE=".kiro/swarm/.completed-count"

# Restore counter from previous session
[ -f "$COUNTER_FILE" ] && COMPLETED_COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)

echo "🐝 Watching for done files (swarm $SWARM_PREFIX) every ${POLL}s"
echo "   Auto-compact every $COMPACT_EVERY tasks, re-anchor every $ANCHOR_EVERY tasks"

while true; do
    sleep "$POLL"

    for DONE in .kiro/swarm/done-*.md; do
        [ -f "$DONE" ] || continue
        BASENAME=$(basename "$DONE")

        # Don't notify orchestrator about its own done file
        echo "$BASENAME" | grep -q "done-orchestrator" && continue

        echo "$NOTIFIED" | grep -q "$BASENAME" && continue

        AGENT=$(echo "$BASENAME" | sed 's/done-//;s/\.md//')
        echo "$(date +%H:%M:%S) — $AGENT completed (see $DONE)"

        # --- Harness #2: Evidence gate ---
        if echo "$BASENAME" | grep -q "done-developer"; then
            if bash .kiro/scripts/validate-done.sh "$DONE" 2>&1; then
                echo "$(date +%H:%M:%S) — ✅ $AGENT done file validated"
            else
                echo "$(date +%H:%M:%S) — 🚫 $AGENT done file FAILED validation"
                # Notify the developer to fix
                DEV_PANE=$(swarm_pane_id "$(echo "$AGENT" | tr '[:lower:]' '[:upper:]')")
                if [ -n "$DEV_PANE" ]; then
                    tmux send-keys -t "$DEV_PANE" "Your done file failed validation. Run: bash .kiro/scripts/validate-done.sh $DONE — fix the issues and rewrite the done file."
                    sleep 0.3
                    tmux send-keys -t "$DEV_PANE" Enter 2>/dev/null
                fi
                NOTIFIED="$NOTIFIED $BASENAME"
                continue  # Don't notify orchestrator about invalid done files
            fi
        fi

        # Notify orchestrator with absolute path
        ORCH_PANE=$(swarm_pane_id "ORCHESTRATOR")
        if [ -n "$ORCH_PANE" ]; then
            tmux send-keys -t "$ORCH_PANE" "$AGENT has completed their task. Read $SWARM_DIR/.kiro/swarm/$BASENAME and proceed."
            sleep 0.3
            tmux send-keys -t "$ORCH_PANE" Enter 2>/dev/null
            echo "$(date +%H:%M:%S) — Notified ORCHESTRATOR about $AGENT"
        fi

        NOTIFIED="$NOTIFIED $BASENAME"

        # --- Harness #6: Auto memory compaction ---
        if echo "$BASENAME" | grep -q "done-developer"; then
            COMPLETED_COUNT=$((COMPLETED_COUNT + 1))
            echo "$COMPLETED_COUNT" > "$COUNTER_FILE"

            if [ $((COMPLETED_COUNT % COMPACT_EVERY)) -eq 0 ]; then
                echo "$(date +%H:%M:%S) — 🗜️ Auto-compacting memory (${COMPLETED_COUNT} tasks completed)"
                bash .kiro/scripts/compact-memory.sh 20 2>&1 | tail -2
            fi

            # --- Harness #7: Session re-anchoring ---
            if [ $((COMPLETED_COUNT % ANCHOR_EVERY)) -eq 0 ]; then
                echo "$(date +%H:%M:%S) — 🔄 Re-anchoring orchestrator (${COMPLETED_COUNT} tasks completed)"
                ORCH_PANE=$(swarm_pane_id "ORCHESTRATOR")
                if [ -n "$ORCH_PANE" ]; then
                    tmux send-keys -t "$ORCH_PANE" "SESSION CHECKPOINT: ${COMPLETED_COUNT} tasks completed. Re-read .kiro/swarm/config.json for session_scope, check .kiro/swarm/status.json for current state, and run bash .kiro/scripts/query-status.sh ready to see what's next. Stay on protocol."
                    sleep 0.3
                    tmux send-keys -t "$ORCH_PANE" Enter 2>/dev/null
                fi
            fi
        fi
    done

    # --- Batch nudge: if 2+ done files pending and no task-orchestrator.md, write one ---
    DONE_COUNT=$(ls .kiro/swarm/done-developer-*.md 2>/dev/null | wc -l | tr -d ' ')
    if [ "$DONE_COUNT" -ge 2 ] && [ ! -f .kiro/swarm/task-orchestrator.md ]; then
        echo "$(date +%H:%M:%S) — 📢 $DONE_COUNT done files pending — writing batch nudge task"

        # Build done file list
        DONE_LIST=""
        for df in .kiro/swarm/done-developer-*.md; do
            [ -f "$df" ] || continue
            TICKET=$(head -1 "$df" | sed 's/# Done: //')
            STATUS_LINE=$(sed -n '2p' "$df" | sed 's/## Status: //')
            BRANCH=$(sed -n '3p' "$df" | sed 's/## Branch: //')
            AGENT=$(basename "$df" | sed 's/done-//;s/\.md//')
            DONE_LIST="${DONE_LIST}\n- $AGENT → $TICKET ($STATUS_LINE) — merge $BRANCH"
        done

        cat > .kiro/swarm/task-orchestrator.md << TASKEOF
# Task: Process $DONE_COUNT Done Files
## Type: nudge
## Done files waiting:
$(echo -e "$DONE_LIST")

## Action: Read each done file, merge PASS branches, update status.json, assign next ready tasks.
TASKEOF

        ORCH_PANE=$(swarm_pane_id "ORCHESTRATOR")
        if [ -n "$ORCH_PANE" ]; then
            tmux send-keys -t "$ORCH_PANE" "BATCH: $DONE_COUNT done files waiting. Read .kiro/swarm/task-orchestrator.md and process them all." Enter 2>/dev/null
        fi
    fi

    # Reset notified list when done files are cleaned up
    for NOTED in $NOTIFIED; do
        [ -f ".kiro/swarm/$NOTED" ] || NOTIFIED=$(echo "$NOTIFIED" | sed "s/ $NOTED//")
    done
done
