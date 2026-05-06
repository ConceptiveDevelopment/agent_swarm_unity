#!/bin/bash
# Protocol compliance audit — verify orchestrator follows the swarm protocol.
# Usage: bash .kiro/scripts/audit-protocol.sh
#
# Checks status.json consistency, Linear sync, and protocol adherence.
# Run manually or on a schedule. Reports findings, does not modify state.

cd "$(dirname "$0")/../.."
source .kiro/scripts/swarm-env.sh

STATUS=".kiro/swarm/status.json"
ERRORS=0
WARNINGS=0

echo "📋 Protocol Compliance Audit — Swarm $SWARM_PREFIX"
echo "   $(date '+%Y-%m-%d %H:%M')"
echo ""

# 1. status.json exists and is valid JSON
if [ ! -f "$STATUS" ]; then
    echo "❌ status.json missing"
    ERRORS=$((ERRORS + 1))
else
    if ! python3 -c "import json; json.load(open('$STATUS'))" 2>/dev/null; then
        echo "❌ status.json is invalid JSON"
        ERRORS=$((ERRORS + 1))
    else
        echo "✅ status.json valid"

        # 2. All in_progress tasks have an assigned agent
        UNASSIGNED=$(python3 -c "
import json
s = json.load(open('$STATUS'))
for tid, t in s.get('tasks', {}).items():
    if t.get('status') == 'in_progress' and not t.get('agent'):
        print(f'  {tid}: in_progress but no agent assigned')
" 2>/dev/null)
        if [ -n "$UNASSIGNED" ]; then
            echo "❌ Tasks in progress without agent:"
            echo "$UNASSIGNED"
            ERRORS=$((ERRORS + 1))
        else
            echo "✅ All in-progress tasks have agents"
        fi

        # 3. No agent assigned to multiple tasks
        MULTI=$(python3 -c "
import json
from collections import Counter
s = json.load(open('$STATUS'))
agents = [t['agent'] for t in s.get('tasks', {}).values() if t.get('status') == 'in_progress' and t.get('agent')]
dupes = [a for a, c in Counter(agents).items() if c > 1]
for d in dupes:
    print(f'  {d}: assigned to multiple in-progress tasks')
" 2>/dev/null)
        if [ -n "$MULTI" ]; then
            echo "⚠️ Agents with multiple active tasks:"
            echo "$MULTI"
            WARNINGS=$((WARNINGS + 1))
        else
            echo "✅ No agent overloaded"
        fi

        # 4. Blocked tasks have valid blockers
        BAD_BLOCKS=$(python3 -c "
import json
s = json.load(open('$STATUS'))
tasks = s.get('tasks', {})
for tid, t in tasks.items():
    for b in t.get('blocked_by', []):
        if b not in tasks:
            print(f'  {tid}: blocked by {b} which is not in status.json')
" 2>/dev/null)
        if [ -n "$BAD_BLOCKS" ]; then
            echo "❌ Invalid blockers:"
            echo "$BAD_BLOCKS"
            ERRORS=$((ERRORS + 1))
        else
            echo "✅ All blockers valid"
        fi

        # 5. Agent status matches reality
        AGENT_MISMATCH=$(python3 -c "
import json
s = json.load(open('$STATUS'))
agents = s.get('agents', {})
tasks = s.get('tasks', {})
for name, a in agents.items():
    if a.get('status') == 'working' and a.get('current_task'):
        task = tasks.get(a['current_task'], {})
        if task.get('status') != 'in_progress':
            print(f'  {name}: marked working on {a[\"current_task\"]} but task is {task.get(\"status\", \"missing\")}')
    if a.get('status') == 'idle' and a.get('current_task'):
        print(f'  {name}: marked idle but has current_task {a[\"current_task\"]}')
" 2>/dev/null)
        if [ -n "$AGENT_MISMATCH" ]; then
            echo "⚠️ Agent/task status mismatch:"
            echo "$AGENT_MISMATCH"
            WARNINGS=$((WARNINGS + 1))
        else
            echo "✅ Agent statuses consistent"
        fi
    fi
fi

# 6. Orphan done files (done file exists but no matching in-progress task)
for done in .kiro/swarm/done-*.md; do
    [ -f "$done" ] || continue
    AGENT=$(basename "$done" | sed 's/done-//;s/\.md//')
    echo "⚠️ Unprocessed done file: $done (from $AGENT)"
    WARNINGS=$((WARNINGS + 1))
done

# 7. Orphan task files (task file exists but agent might not be working)
for task in .kiro/swarm/task-*.md; do
    [ -f "$task" ] || continue
    AGENT=$(basename "$task" | sed 's/task-//;s/\.md//')
    echo "ℹ️ Active task file: $task (for $AGENT)"
done

# 8. status.md freshness
if [ -f ".kiro/swarm/status.md" ]; then
    STALE=$(find .kiro/swarm/status.md -mmin +30 2>/dev/null)
    if [ -n "$STALE" ]; then
        echo "⚠️ status.md not updated in 30+ minutes"
        WARNINGS=$((WARNINGS + 1))
    else
        echo "✅ status.md is fresh"
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Errors: $ERRORS  Warnings: $WARNINGS"
[ "$ERRORS" -eq 0 ] && echo "✅ Protocol compliance: PASS" || echo "❌ Protocol compliance: FAIL"
