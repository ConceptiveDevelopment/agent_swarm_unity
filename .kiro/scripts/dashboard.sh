#!/bin/bash
# Live swarm dashboard — refreshes every N seconds (session-safe).
# Adapts to pane width automatically.
# Usage: bash .kiro/scripts/dashboard.sh [interval]

cd "$(dirname "$0")/../.."
source .kiro/scripts/swarm-env.sh

INTERVAL="${1:-10}"

render() {
  local COLS
  COLS=$(tput cols 2>/dev/null || echo 80)

  local output=""
  local SEP
  SEP=$(printf '━%.0s' $(seq 1 $((COLS / 2))))

  local SWARM_VER
  SWARM_VER=$(cat .kiro/swarm/VERSION 2>/dev/null || echo "?")

  output+="🐝 SWARM [$SWARM_PREFIX] v${SWARM_VER} $(date '+%H:%M')\n"
  output+="${SEP}\n"

  # Session scope
  local scope
  scope=$(python3 -c "
import json, os
c=json.load(open('$SWARM_CONFIG'))
ss=c.get('session_scope',[])
done=0
if os.path.exists('.kiro/swarm/status.json'):
    t=json.load(open('.kiro/swarm/status.json'))
    done=sum(1 for i in ss if t.get('tasks',{}).get('#'+str(i),{}).get('status')=='closed')
if ss:
    print('[%d/%d]' % (done, len(ss)))
else:
    print('')
" 2>/dev/null)
  [ -n "$scope" ] && output+="📋 ${scope}\n"

  # Agents + Tasks from status.json
  if [ -f .kiro/swarm/status.json ]; then
    output+="\n$(COLS=$COLS python3 -c "
import json, os
cols = int(os.environ.get('COLS', '60'))
tw = cols - 4  # usable text width

s = json.load(open('.kiro/swarm/status.json'))

# Derive agent state from live task/done files on disk
import glob
agents = ['orchestrator', 'architect', 'principal-qa', 'developer-1', 'developer-2', 'developer-3', 'developer-4']
for name in agents:
    task_file = f'.kiro/swarm/task-{name}.md'
    done_file = f'.kiro/swarm/done-{name}.md'
    if os.path.exists(done_file):
        icon = '✅'
        # Read issue from done file
        issue = ''
        with open(done_file) as df:
            for line in df:
                if line.startswith('# Done:') or 'Issue #' in line or 'Issue:' in line:
                    import re
                    m = re.search(r'#(\d+)', line)
                    if m: issue = '#' + m.group(1)
                    break
        print('  %s %-14s %s done' % (icon, name[:14], issue))
    elif os.path.exists(task_file):
        icon = '🔨'
        issue = ''
        with open(task_file) as tf:
            for line in tf:
                if '## Issue:' in line or '# Task:' in line:
                    import re
                    m = re.search(r'#(\d+)', line)
                    if m: issue = '#' + m.group(1)
                    break
        print('  %s %-14s %s' % (icon, name[:14], issue))
    else:
        print('  💤 %s' % name[:14])
print()

tasks = s.get('tasks', {})
for status, icon, label in [('in_progress', '🔨', 'In Progress'), ('open', '⏸️', 'Queued'), ('blocked', '⛔', 'Blocked'), ('closed', '✅', 'Done')]:
    items = [(k, v) for k, v in sorted(tasks.items(), key=lambda x: x[1].get('priority', 9)) if v.get('status') == status]
    if items:
        print('%s %s (%d)' % (icon, label, len(items)))
        for tid, t in items:
            title = t.get('title', '')[:tw - 10]
            line = '  %s %s' % (tid, title)
            if t.get('agent'):
                line += ' → ' + t['agent']
            if t.get('blocked_by'):
                open_blockers = [b for b in t['blocked_by'] if tasks.get(b, {}).get('status') != 'closed']
                if open_blockers:
                    line += ' ⛔' + ','.join(open_blockers)
            print(line[:tw])
        print()
" 2>/dev/null)\n"
  fi

  # Orchestrator status
  output+="🎯 ORCH\n"
  local ORCH_PANE
  ORCH_PANE=$(swarm_pane_id "ORCHESTRATOR")
  if [ -n "$ORCH_PANE" ]; then
    local ORCH_STATUS
    ORCH_STATUS=$(tmux capture-pane -t "$ORCH_PANE" -p 2>/dev/null | \
      grep -v "^$" | grep -v "^─" | grep -v "^━" | \
      grep -v "Trust All" | grep -v "orchestrator ·" | \
      grep -v "ask a question" | grep -v "/copy" | \
      grep -v "Kiro is working" | grep -v "type to queue" | \
      grep -v "esc to cancel" | grep -v "working_dir=" | \
      grep -v "^●" | grep -v "Thinking" | grep -v "^  *#" | \
      grep -v "Completed in" | grep -v "using tool" | \
      sed 's/^  *//' | \
      tail -4 | head -3)
    if [ -n "$ORCH_STATUS" ]; then
      output+="$(echo "$ORCH_STATUS" | while IFS= read -r line; do
        echo "  ${line:0:$((COLS - 4))}"
      done)\n"
    else
      output+="  idle\n"
    fi
  else
    output+="  offline\n"
  fi

  # GitLab backlog
  output+="\n📥 BACKLOG\n"
  local BACKLOG
  BACKLOG=$(cd "$SWARM_DIR" && glab issue list --label "ready" --per-page 5 --output json 2>/dev/null | COLS=$COLS python3 -c "
import json, sys, os
cols = int(os.environ.get('COLS', '60'))
tw = cols - 4
try:
    issues = json.load(sys.stdin)
    if not issues:
        print('  (empty)')
    else:
        for i in issues[:5]:
            iid = '#' + str(i.get('iid','?'))
            title = i.get('title','')[:tw - 10]
            labels = [l for l in i.get('labels',[]) if l.startswith('P')]
            p = labels[0] if labels else ''
            print('  %s %s %s' % (iid, title, p))
except:
    print('  (unavailable)')
" 2>/dev/null)
  if [ -z "$BACKLOG" ]; then
    BACKLOG="  (no issues)"
  fi
  output+="${BACKLOG}\n"

  output+="\n${SEP}\n↻ ${INTERVAL}s"

  tput home 2>/dev/null || printf '\033[H'
  tput ed 2>/dev/null || printf '\033[J'
  printf '%b\n' "$output"
}

render

while true; do
  sleep "$INTERVAL"
  render
done
