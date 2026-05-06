#!/bin/bash
# Watch for done files, validate, auto-merge PASS branches, notify PO and orchestrator.
# Usage: bash .kiro/scripts/watch-done.sh [poll_interval]
# No set -e — long-running watcher must survive transient errors.

cd "$(dirname "$0")/../.."
source .kiro/scripts/swarm-env.sh || { echo "❌ Failed to source swarm-env.sh"; exit 1; }

POLL="${1:-5}"
NOTIFIED=""
COMPLETED_COUNT=0
COMPACT_EVERY=5
ANCHOR_EVERY=3
COUNTER_FILE=".kiro/swarm/.completed-count"
STATUS_FILE=".kiro/swarm/status.json"

[ -f "$COUNTER_FILE" ] && COMPLETED_COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)

echo "🐝 Watching for done files (swarm $SWARM_PREFIX) every ${POLL}s"
echo "   Auto-merge PASS branches, notify PO via tmux"

# --- Helper: send tmux message to an agent ---
notify_agent() {
    local AGENT="$1"
    local MSG="$2"
    local PANE=$(swarm_pane_id "$AGENT")
    if [ -n "$PANE" ]; then
        tmux send-keys -t "$PANE" "$MSG" Enter 2>/dev/null
    fi
}

# --- Helper: update status.json ---
update_status() {
    local TICKET="$1"
    local STATUS="$2"
    local AGENT="${3:-null}"
    python3 -c "
import json
f = '$STATUS_FILE'
try: d = json.load(open(f))
except: d = {'tasks':{}, 'agents':{}}
if '$TICKET' in d.get('tasks', {}):
    d['tasks']['$TICKET']['status'] = '$STATUS'
    d['tasks']['$TICKET']['agent'] = $AGENT
else:
    d['tasks']['$TICKET'] = {'title':'','status':'$STATUS','agent':$AGENT,'branch':'','files':[],'blocked_by':[],'blocks':[],'discovered_from':[]}
if '$AGENT' != 'null' and '$STATUS' == 'closed':
    d['agents'].pop('$AGENT', None)
json.dump(d, open(f, 'w'), indent=2)
" 2>/dev/null
}

# --- Helper: auto-merge a branch ---
auto_merge() {
    local BRANCH="$1"
    local TICKET="$2"
    
    # Fetch and merge
    git fetch origin "$BRANCH" 2>/dev/null || return 1
    git merge "origin/$BRANCH" --no-edit -m "Merge $BRANCH — Implements $TICKET" 2>/dev/null || {
        git merge --abort 2>/dev/null
        return 1
    }
    git push origin main 2>/dev/null || return 1
    
    # Delete remote branch
    git push origin --delete "$BRANCH" 2>/dev/null
    return 0
}

while true; do
    sleep "$POLL"

    for DONE in .kiro/swarm/done-*.md; do
        [ -f "$DONE" ] || continue
        BASENAME=$(basename "$DONE")

        echo "$BASENAME" | grep -q "done-orchestrator" && continue
        echo "$NOTIFIED" | grep -q "$BASENAME" && continue

        AGENT=$(echo "$BASENAME" | sed 's/done-//;s/\.md//')
        AGENT_UPPER=$(echo "$AGENT" | tr '[:lower:]' '[:upper:]')
        echo "$(date +%H:%M:%S) — $AGENT completed (see $DONE)"

        # --- Handle QA verdict: auto-merge on PASS, send back on FAIL ---
        if echo "$BASENAME" | grep -q "done-principal-qa"; then
            QA_VERDICT=$(sed -n 's/^## Verdict: //p' "$DONE" | head -1)
            QA_TICKET=$(sed -n 's/^## Issue: //p' "$DONE" | grep -oE 'CDEV-[0-9]+' | head -1)
            QA_BRANCH=$(sed -n 's/^## Branch: //p' "$DONE" | head -1)
            QA_TITLE=$(sed -n 's/^## Issue: //p' "$DONE" | sed 's/CDEV-[0-9]* — //')

            if [ "$QA_VERDICT" = "PASS" ] && [ -n "$QA_BRANCH" ]; then
                echo "$(date +%H:%M:%S) — ✅ QA PASS for $QA_BRANCH — auto-merging..."
                if auto_merge "$QA_BRANCH" "$QA_TICKET"; then
                    echo "$(date +%H:%M:%S) — ✅ Merged $QA_BRANCH to main"
                    update_status "$QA_TICKET" "closed" "null"
                    COMPLETED_COUNT=$((COMPLETED_COUNT + 1))
                    echo "$COMPLETED_COUNT" > "$COUNTER_FILE"
                    notify_agent "PRODUCT-OWNER" "SESSION UPDATE: Completed: $QA_TICKET $QA_TITLE (QA passed). Total closed: $COMPLETED_COUNT."
                    notify_agent "ORCHESTRATOR" "QA passed and merged $QA_TICKET ($QA_TITLE). Assign next task from backlog if available."
                    # Clean up developer done file too
                    rm -f .kiro/swarm/done-developer-*.md
                    rm -f "$DONE"
                else
                    echo "$(date +%H:%M:%S) — ❌ Merge conflict on $QA_BRANCH — escalating to orchestrator"
                    notify_agent "ORCHESTRATOR" "MERGE CONFLICT after QA pass: $QA_BRANCH has conflicts. Resolve manually."
                fi
            elif [ "$QA_VERDICT" = "FAIL" ]; then
                echo "$(date +%H:%M:%S) — 🚫 QA FAIL for $QA_BRANCH — sending back to developer"
                # Find which developer had this task
                DEV_AGENT=$(python3 -c "
import json
try:
    s = json.load(open('$STATUS_FILE'))
    for name, info in s.get('agents', {}).items():
        if info.get('task') == '$QA_TICKET':
            print(name.upper().replace('DEVELOPER-','DEVELOPER-'))
            break
except: pass
" 2>/dev/null)
                if [ -n "$DEV_AGENT" ]; then
                    notify_agent "$DEV_AGENT" "QA FAILED your work on $QA_TICKET. Read .kiro/swarm/done-principal-qa.md for findings. Fix the issues and resubmit."
                else
                    notify_agent "ORCHESTRATOR" "QA FAILED $QA_TICKET but cannot find original developer. Read QA done file and reassign."
                fi
                update_status "$QA_TICKET" "in_progress" "null"
                rm -f "$DONE"
            else
                notify_agent "ORCHESTRATOR" "QA completed review for $QA_TICKET with verdict: $QA_VERDICT. Read $DONE and proceed."
            fi
            NOTIFIED="$NOTIFIED $BASENAME"
            continue
        fi

        # Extract info from done file
        STATUS_LINE=$(sed -n 's/^## Status: //p' "$DONE" | head -1)
        BRANCH=$(sed -n 's/^## Branch: //p' "$DONE" | head -1)
        TICKET=$(head -1 "$DONE" | grep -oE 'CDEV-[0-9]+' || echo "HOTFIX")
        TITLE=$(head -1 "$DONE" | sed 's/^# Done: //')

        # --- Validate done file (developers only) ---
        if echo "$BASENAME" | grep -q "done-developer"; then
            if bash .kiro/scripts/validate-done.sh "$DONE" 2>&1; then
                echo "$(date +%H:%M:%S) — ✅ $AGENT validated"
            else
                echo "$(date +%H:%M:%S) — 🚫 $AGENT FAILED validation"
                notify_agent "$AGENT_UPPER" "Your done file failed validation. Run: bash .kiro/scripts/validate-done.sh $DONE — fix and rewrite."
                NOTIFIED="$NOTIFIED $BASENAME"
                continue
            fi
        fi

        # --- Auto-merge PASS branches ---
        if [ "$STATUS_LINE" = "PASS" ] && [ -n "$BRANCH" ]; then
            
            # Check if issue is labeled "chore" — skip QA if so
            IS_CHORE=$(python3 -c "
import json
try:
    s = json.load(open('$STATUS_FILE'))
    t = s.get('tasks', {}).get('$TICKET', {})
    labels = t.get('labels', [])
    print('yes' if 'chore' in labels else 'no')
except: print('no')
" 2>/dev/null)

            if [ "$IS_CHORE" = "yes" ]; then
                # Chore — auto-merge without QA
                echo "$(date +%H:%M:%S) — 🔀 Auto-merging $BRANCH (chore, QA bypassed)..."
                if auto_merge "$BRANCH" "$TICKET"; then
                    echo "$(date +%H:%M:%S) — ✅ Merged $BRANCH to main"
                    update_status "$TICKET" "closed" "null"
                    COMPLETED_COUNT=$((COMPLETED_COUNT + 1))
                    echo "$COMPLETED_COUNT" > "$COUNTER_FILE"
                    notify_agent "PRODUCT-OWNER" "SESSION UPDATE: Completed: $TICKET $TITLE (chore, auto-merged). Total closed: $COMPLETED_COUNT."
                    notify_agent "ORCHESTRATOR" "$AGENT completed $TICKET ($TITLE). Branch merged. Assign next task from backlog if available."
                    rm -f "$DONE" ".kiro/swarm/task-${AGENT}.md"
                else
                    echo "$(date +%H:%M:%S) — ❌ Merge conflict on $BRANCH — escalating to orchestrator"
                    notify_agent "ORCHESTRATOR" "MERGE CONFLICT: $AGENT's branch $BRANCH has conflicts. Read $DONE and resolve manually."
                fi
            else
                # Not a chore — send to QA for review before merge
                echo "$(date +%H:%M:%S) — 🔍 Sending $BRANCH to QA for pre-merge review..."
                QA_TASK=".kiro/swarm/task-principal-qa.md"
                cat > "$QA_TASK" << EOF
# Task: Pre-Merge Review
## Type: pre-merge-review
## Issue: $TICKET — $TITLE
## Branch: $BRANCH
## Developer: $AGENT
## Done file: $DONE
## Instructions:
Review the diff: git diff main...origin/$BRANCH
Verify acceptance criteria from the done file are actually met.
Write your verdict to .kiro/swarm/done-principal-qa.md:
- ## Verdict: PASS or FAIL
- ## Issue: $TICKET
- ## Branch: $BRANCH
If FAIL, include ## Findings with specific issues.
EOF
                notify_agent "PRINCIPAL-QA" "Pre-merge review ready for $TICKET — read your task file and review the branch."
                update_status "$TICKET" "in_review" "\"principal-qa\""
            fi
        else
            # FAIL or no branch — escalate to orchestrator
            notify_agent "ORCHESTRATOR" "$AGENT has completed their task (status: $STATUS_LINE). Read $SWARM_DIR/.kiro/swarm/$BASENAME and proceed."
        fi

        NOTIFIED="$NOTIFIED $BASENAME"

        # --- Auto memory compaction ---
        if [ $((COMPLETED_COUNT % COMPACT_EVERY)) -eq 0 ] && [ $COMPLETED_COUNT -gt 0 ]; then
            echo "$(date +%H:%M:%S) — 🗜️ Auto-compacting memory ($COMPLETED_COUNT tasks)"
            bash .kiro/scripts/compact-memory.sh 20 2>&1 | tail -2
        fi

        # --- Session re-anchoring ---
        if [ $((COMPLETED_COUNT % ANCHOR_EVERY)) -eq 0 ] && [ $COMPLETED_COUNT -gt 0 ]; then
            echo "$(date +%H:%M:%S) — 🔄 Re-anchoring orchestrator ($COMPLETED_COUNT tasks)"
            notify_agent "ORCHESTRATOR" "SESSION CHECKPOINT: $COMPLETED_COUNT tasks completed. Re-read config.json session_scope, check status.json, assign next ready tasks."
        fi
    done

    # Reset notified list when done files are cleaned up
    for NOTED in $NOTIFIED; do
        [ -f ".kiro/swarm/$NOTED" ] || NOTIFIED=$(echo "$NOTIFIED" | sed "s/ $NOTED//")
    done
done
