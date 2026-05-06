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

  output+="🐝 SWARM [$SWARM_PREFIX] $(date '+%H:%M')\n"
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

agents = s.get('agents', {})
if agents:
    for name, a in sorted(agents.items()):
        icon = '🔨' if a['status'] == 'working' else '💤'
        task = a.get('current_task') or ''
        if task:
            t = s.get('tasks', {}).get(task, {})
            title = t.get('title', '')[:tw - len(name) - len(task) - 4]
            print('  %s %-14s %s %s' % (icon, name[:14], task, title))
        else:
            print('  %s %s' % (icon, name[:14]))
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

  # Backlog from status.json
  output+="\n📥 BACKLOG\n"
  local BACKLOG
  BACKLOG=$(python3 -c "
import json, os
cols = int(os.environ.get('COLS', '60'))
tw = cols - 4
if os.path.exists('.kiro/swarm/status.json'):
    s = json.load(open('.kiro/swarm/status.json'))
    tasks = s.get('tasks', {})
    queued = [(k, v) for k, v in sorted(tasks.items(), key=lambda x: x[1].get('priority', 9)) if v.get('status') == 'open']
    if not queued:
        print('  (empty)')
    else:
        for tid, t in queued[:5]:
            title = t.get('title', '')[:tw - 10]
            p = 'P' + str(t.get('priority', '?'))
            print('  %s %s %s' % (tid, title, p))
else:
    print('  (no status.json)')
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
