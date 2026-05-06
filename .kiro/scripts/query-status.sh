#!/bin/bash
# Query task status and dependencies from status.json.
# Usage:
#   bash .kiro/scripts/query-status.sh ready     — show tasks with no open blockers
#   bash .kiro/scripts/query-status.sh blocked    — show blocked tasks
#   bash .kiro/scripts/query-status.sh agent <name> — show what an agent is working on
#   bash .kiro/scripts/query-status.sh deps <issue> — show dependencies for an issue

set -e
cd "$(dirname "$0")/../.."

STATUS=".kiro/swarm/status.json"

if [ ! -f "$STATUS" ]; then
    echo "No status.json found."
    exit 1
fi

case "${1:-ready}" in
    ready)
        python3 - "$STATUS" << 'PY'
import json, sys
s = json.load(open(sys.argv[1]))
for tid, t in s.get("tasks", {}).items():
    if t.get("status") == "open":
        blockers = [b for b in t.get("blocked_by", []) if s["tasks"].get(b, {}).get("status") != "closed"]
        if not blockers:
            print(f"  {tid}: {t.get('title', '?')} (P{t.get('priority', '?')})")
PY
        ;;
    blocked)
        python3 - "$STATUS" << 'PY'
import json, sys
s = json.load(open(sys.argv[1]))
for tid, t in s.get("tasks", {}).items():
    if t.get("status") != "closed":
        blockers = [b for b in t.get("blocked_by", []) if s["tasks"].get(b, {}).get("status") != "closed"]
        if blockers:
            print(f"  {tid}: blocked by {', '.join(blockers)}")
PY
        ;;
    agent)
        if [ -z "$2" ]; then
            echo "Usage: query-status.sh agent <name>"
            echo "Example: query-status.sh agent developer-1"
            exit 1
        fi
        python3 - "$STATUS" "$2" << 'PY'
import json, sys
s = json.load(open(sys.argv[1]))
name = sys.argv[2]
agent = s.get("agents", {}).get(name, {})
if not agent:
    print(f"  Agent '{name}' not found in status.json")
    sys.exit(1)
print(f"  Status: {agent.get('status', 'unknown')}")
print(f"  Task: {agent.get('current_task', 'none')}")
PY
        ;;
    deps)
        if [ -z "$2" ]; then
            echo "Usage: query-status.sh deps <issue>"
            echo "Example: query-status.sh deps #42"
            exit 1
        fi
        python3 - "$STATUS" "$2" << 'PY'
import json, sys
s = json.load(open(sys.argv[1]))
issue = sys.argv[2]
t = s.get("tasks", {}).get(issue, {})
if not t:
    print(f"  Issue '{issue}' not found in status.json")
    sys.exit(1)
print(f"  Blocked by: {t.get('blocked_by', [])}")
print(f"  Blocks: {t.get('blocks', [])}")
print(f"  Discovered: {t.get('discovered_from', [])}")
PY
        ;;
    *)
        echo "Usage: query-status.sh {ready|blocked|agent <name>|deps <issue>}"
        ;;
esac
