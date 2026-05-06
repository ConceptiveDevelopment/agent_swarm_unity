#!/bin/bash
# Ralph Wiggum Loop — "I'm helping!"
# A dumb, reliable polling loop that keeps the swarm moving.
# Every N seconds: check state, poke idle orchestrator with actionable work.
#
# Usage: bash .kiro/scripts/ralph.sh [interval]

cd "$(dirname "$0")/../.."
source .kiro/scripts/swarm-env.sh

INTERVAL="${1:-15}"

NOTIFIED_DONE=""
LAST_POKE=0

is_idle() {
    tmux capture-pane -t "$1" -p 2>/dev/null | tail -5 | grep -q "ask a question"
}

poke() {
    local pane="$1" msg="$2"
    local NOW=$(date +%s)
    local ELAPSED=$((NOW - LAST_POKE))
    [ $ELAPSED -lt 30 ] && return
    tmux send-keys -t "$pane" "$msg" Enter 2>/dev/null
    LAST_POKE=$NOW
    echo "$(date +%H:%M:%S) — Poked: ${msg:0:80}"
}

echo "🐝 Ralph Wiggum loop running every ${INTERVAL}s (swarm $SWARM_PREFIX)"
echo "   I'm helping!"
echo ""

while true; do
    sleep "$INTERVAL"

    # --- Auto-approve permission prompts ---
    swarm_list_panes | grep -E "ORCHESTRATOR|ARCHITECT|PRINCIPAL-QA|DEVELOPER" | \
        while read PANE_ID WNAME CMD; do
            SCREEN=$(tmux capture-pane -t "$PANE_ID" -p 2>/dev/null | tail -5)
            if echo "$SCREEN" | grep -q "\[y/n/t\]"; then
                tmux send-keys -t "$PANE_ID" "t" Enter 2>/dev/null
                echo "$(date +%H:%M:%S) — $(swarm_agent_name "$WNAME"): auto-trusted"
            elif echo "$SCREEN" | grep -q "\[y/n\]"; then
                tmux send-keys -t "$PANE_ID" "y" Enter 2>/dev/null
                echo "$(date +%H:%M:%S) — $(swarm_agent_name "$WNAME"): auto-approved"
            elif echo "$SCREEN" | grep -q "Entire tool"; then
                tmux send-keys -t "$PANE_ID" Enter 2>/dev/null
                echo "$(date +%H:%M:%S) — $(swarm_agent_name "$WNAME"): trusted entire tool"
            elif echo "$SCREEN" | grep -q "Yes, I accept"; then
                tmux send-keys -t "$PANE_ID" Down Enter 2>/dev/null
                echo "$(date +%H:%M:%S) — $(swarm_agent_name "$WNAME"): accepted trust"
            fi
        done

    ORCH=$(swarm_pane_id "ORCHESTRATOR")
    [ -z "$ORCH" ] && continue
    is_idle "$ORCH" || continue

    # --- Check for NEW done files ---
    for DONE in .kiro/swarm/done-*.md; do
        [ -f "$DONE" ] || continue
        BN=$(basename "$DONE")
        echo "$NOTIFIED_DONE" | grep -q "$BN" && continue
        AGENT=$(echo "$BN" | sed 's/done-//;s/\.md//')
        poke "$ORCH" "$AGENT finished. Read .kiro/swarm/$BN and take next action."
        NOTIFIED_DONE="$NOTIFIED_DONE $BN"
    done

    # --- Check for unread task file ---
    if [ -f .kiro/swarm/task-orchestrator.md ]; then
        poke "$ORCH" "You have a pending task file. Read .kiro/swarm/task-orchestrator.md and act."
        continue
    fi

    # --- Check for idle developers with assignable work ---
    if [ -f .kiro/swarm/status.json ]; then
        NUDGE=$(python3 -c "
import json
s=json.load(open('.kiro/swarm/status.json'))
tasks=s.get('tasks',{})
agents=s.get('agents',{})
idle=[a for a,v in agents.items() if v.get('status')=='idle' and 'developer' in a]
assignable=[]
for tid,t in tasks.items():
    if t.get('status') in ('open','in_progress') and not t.get('agent'):
        assignable.append(tid)
    elif t.get('status')=='blocked':
        blockers=t.get('blocked_by',[])
        all_done=all(tasks.get(b,{}).get('status')=='closed' for b in blockers)
        if all_done:
            assignable.append(tid + ' (unblocked)')
if idle and assignable:
    print(f'{len(idle)} idle devs, assignable: {\" \".join(assignable[:3])}. Assign them.')
elif not any(v.get('status')=='working' for v in agents.values()):
    open_tasks=[k for k,v in tasks.items() if v.get('status') not in ('closed',)]
    if open_tasks:
        print(f'All agents idle. Open tasks: {\" \".join(open_tasks[:3])}. Take action.')
" 2>/dev/null)
        [ -n "$NUDGE" ] && poke "$ORCH" "$NUDGE"
    fi

    # Reset notified list when done files are cleaned up
    NEW_NOTIFIED=""
    for BN in $NOTIFIED_DONE; do
        [ -f ".kiro/swarm/$BN" ] && NEW_NOTIFIED="$NEW_NOTIFIED $BN"
    done
    NOTIFIED_DONE="$NEW_NOTIFIED"
done
