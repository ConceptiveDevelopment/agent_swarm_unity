#!/bin/bash
# Watcher supervisor — runs external watchers and restarts them on crash.
# Usage: bash .kiro/scripts/watcher-supervisor.sh
#
# Manages only cross-agent watchers that can't be native hooks:
#   watch-done.sh — done file detection + orchestrator notification
#   monitor.sh — crash detection (dead agents can't fire hooks)
#   heartbeat.sh — stuck agent detection (stuck agents don't fire hooks)
#
# Boundary guard, drift check, and progress reporting are now native
# kiro-cli hooks (see .kiro/agents/*.json hooks field).

cd "$(dirname "$0")/../.."
PROJECT_DIR="$(pwd)"

echo "🛡️ Watcher supervisor starting..."
echo "   External watchers: watch-done, monitor, heartbeat, unity-errors"
echo "   Native hooks: boundary, drift, progress, scope, done-gate"

run_watcher() {
    local NAME="$1"
    local SCRIPT="$2"
    while true; do
        echo "$(date +%H:%M:%S) — Starting $NAME"
        bash "$SCRIPT" 2>&1 | sed "s/^/[$NAME] /" &
        local PID=$!
        wait $PID 2>/dev/null
        echo "$(date +%H:%M:%S) — ⚠️ $NAME exited (pid $PID) — restarting in 5s"
        sleep 5
    done
}

run_watcher "watch-done" ".kiro/scripts/watch-done.sh" &
run_watcher "monitor" ".kiro/scripts/monitor.sh" &
run_watcher "heartbeat" ".kiro/scripts/heartbeat.sh" &
run_watcher "po-notify" ".kiro/scripts/po-notifier.sh" &
run_watcher "task-watch" ".kiro/scripts/task-watcher.sh" &
run_watcher "unity-errors" ".kiro/scripts/unity-error-watcher.sh" &

echo "🛡️ All watchers launched. Ctrl+C to stop all."
wait
