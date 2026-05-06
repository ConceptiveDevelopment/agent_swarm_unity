#!/bin/bash
# Status pulse — macOS notification with swarm status every N seconds.
# Usage: bash .kiro/scripts/status-pulse.sh [interval_seconds]
# Default: 240 (4 minutes)
# Stop: kill $(cat /tmp/swarm-pulse-<prefix>.pid)

if [ "$(uname)" != "Darwin" ]; then
    echo "❌ status-pulse.sh requires macOS (uses osascript). Exiting."
    exit 1
fi

cd "$(dirname "$0")/../.."
source .kiro/scripts/swarm-env.sh

INTERVAL="${1:-240}"
STATUS=".kiro/swarm/status.json"
PIDFILE="/tmp/swarm-pulse-${SWARM_PREFIX}.pid"

echo $$ > "$PIDFILE"
echo "📡 Status pulse every ${INTERVAL}s (pid $$, kill via: kill \$(cat $PIDFILE))"

while true; do
    sleep "$INTERVAL"
    [ ! -f "$STATUS" ] && continue

    REPORT=$(python3 - "$STATUS" << 'PY'
import json, sys, os, glob

s = json.load(open(sys.argv[1]))
tasks = s.get("tasks", {})
agents = s.get("agents", {})

working, idle = [], []
for name, info in sorted(agents.items()):
    if not name.startswith("developer") and name not in ("architect", "principal-qa", "orchestrator"):
        continue
    short = name.replace("developer-", "dev").replace("principal-qa", "qa").replace("orchestrator", "orch")
    if info.get("status") == "working":
        task = info.get("current_task", "")
        working.append(f"{short}→{task}")
    else:
        idle.append(short)

open_t = sum(1 for t in tasks.values() if t.get("status") == "open")
closed = sum(1 for t in tasks.values() if t.get("status") == "closed")

stuck = []
done_files = glob.glob(".kiro/swarm/done-*.md")
if done_files:
    stuck.append(f"⚠️ {len(done_files)} done files waiting!")

title = f"{len(working)} working, {len(idle)} idle | {open_t} queued, {closed} done"
parts = []
if working:
    parts.append("🔨 " + ", ".join(working))
if idle:
    parts.append("💤 " + ", ".join(idle))
parts.extend(stuck)
body = " | ".join(parts)

print(f"TITLE:{title}")
print(f"BODY:{body}")
PY
)

    TITLE=$(echo "$REPORT" | grep "^TITLE:" | sed 's/^TITLE://')
    BODY=$(echo "$REPORT" | grep "^BODY:" | sed 's/^BODY://')

    osascript -e "display notification \"$BODY\" with title \"🐝 Swarm\" subtitle \"$TITLE\"" 2>/dev/null
    echo "$(date '+%H:%M') — pulsed"
done
