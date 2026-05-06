#!/bin/bash
# Launch the agent swarm in tmux.
# Usage: bash .kiro/scripts/swarm.sh [num_developers]
#
# Creates tmux windows prefixed with the project ID (e.g. 9558:ORCHESTRATOR)
# and writes a pane manifest to .kiro/swarm/panes.json for session-safe routing.
#
# Layout:
#   {id}:COMMAND — PO (left 2/3) + MONITOR (right 1/3)
#   {id}:ORCHESTRATOR — coordinates all agents
#   {id}:ARCHITECT — structural advisor
#   {id}:PRINCIPAL-QA — quality gate
#   {id}:DEVELOPERS — 2x2 grid of DEVELOPER-1..4
#   {id}:WATCHERS — crash detection & done-file notifications

set -e
cd "$(dirname "$0")/../.."
PROJECT_DIR="$(pwd)"
source .kiro/scripts/swarm-env.sh

SESSION="${TMUX_SESSION:-$(tmux display-message -p '#S')}"
NUM_DEVS="${1:-4}"
MAX_DEVS=4
P="$SWARM_PREFIX"

# Pre-flight: validate config
if ! python3 -c "
import json, sys
c = json.load(open('.kiro/swarm/config.json'))
if not c.get('github_repo') and not c.get('linear_team_id'):
    print('❌ Set github_repo and linear_team_id in .kiro/swarm/config.json before launching.')
    sys.exit(1)
if c.get('project_name') == 'your-project':
    print('⚠️  Warning: project_name is still \"your-project\" — update config.json.')
" 2>/dev/null; then
    exit 1
fi

if [ "$NUM_DEVS" -gt "$MAX_DEVS" ]; then
    echo "Max $MAX_DEVS developers. Clamping."
    NUM_DEVS=$MAX_DEVS
fi

# Check for swarm updates
LOCAL_V=$(cat .kiro/swarm/VERSION 2>/dev/null || echo "0.0.0")
REMOTE_V=$(cat "$HOME/Developer/agent_swarm/.kiro/swarm/VERSION" 2>/dev/null || echo "$LOCAL_V")
if [ "$LOCAL_V" != "$REMOTE_V" ]; then
    echo "⚠️  Swarm update available: v${LOCAL_V} → v${REMOTE_V}"
    echo "   Run 'bash .kiro/scripts/update-swarm.sh' via kiro to review changes."
fi

SWARM_VERSION=$(cat .kiro/swarm/VERSION 2>/dev/null || echo "?")

echo "🐝 Launching Agent Swarm v${SWARM_VERSION} in session: $SESSION (prefix: $P)"
echo "   Developers: $NUM_DEVS"

# Initialize pane manifest
PANES_FILE="$PROJECT_DIR/.kiro/swarm/panes.json"
echo '{}' > "$PANES_FILE"

# Helper: record pane ID in manifest
record_pane() {
    local AGENT="$1"
    local PANE_ID="$2"
    python3 -c "
import json, sys
f = '$PANES_FILE'
p = json.load(open(f))
p[sys.argv[1]] = sys.argv[2]
json.dump(p, open(f, 'w'), indent=2)
" "$AGENT" "$PANE_ID"
    echo "   $AGENT ($PANE_ID)"
}

# Helper: auto-accept trust dialog then send init message
accept_trust() {
    local PANE_ID="$1"
    # Wait for trust dialog to render — kiro-cli TUI needs time to start
    local ATTEMPTS=0
    while [ $ATTEMPTS -lt 10 ]; do
        sleep 1
        SCREEN=$(tmux capture-pane -t "$PANE_ID" -p 2>/dev/null)
        if echo "$SCREEN" | grep -q "Yes, I accept\|No, exit"; then
            break
        fi
        ATTEMPTS=$((ATTEMPTS + 1))
    done
    # Accept: Down to "Yes, I accept", Enter to confirm
    tmux send-keys -t "$PANE_ID" Down
    sleep 0.3
    tmux send-keys -t "$PANE_ID" Enter
    # Wait for dialog to clear and chat to be ready
    sleep 3
    tmux send-keys -t "$PANE_ID" "Begin. Follow your STARTUP instructions."
    sleep 0.3
    tmux send-keys -t "$PANE_ID" Enter
}

# Helper: create a single-pane agent window
create_agent_window() {
    local AGENT="$1"
    local CMD="$2"
    local WIN_NAME="${P}:${AGENT}"
    local PANE_ID
    PANE_ID=$(tmux new-window -n "$WIN_NAME" -P -F '#{pane_id}' "$CMD")
    tmux set-option -p -t "$PANE_ID" remain-on-exit on 2>/dev/null
    record_pane "$AGENT" "$PANE_ID"
    accept_trust "$PANE_ID"
}

AGENT_CMD="echo '--- Agent exited. Ctrl+C to close. ---'; sleep infinity"

# ── Window 1: COMMAND (PO left 2/3 + MONITOR right 1/3) ──
WIN_CMD="${P}:COMMAND"
PO_PANE=$(tmux new-window -n "$WIN_CMD" -P -F '#{pane_id}' "cd $PROJECT_DIR && kiro-cli chat -a --agent product-owner; $AGENT_CMD")
tmux set-option -p -t "$PO_PANE" remain-on-exit on 2>/dev/null
record_pane "PRODUCT-OWNER" "$PO_PANE"
accept_trust "$PO_PANE"

# Split right 33% for monitor (restart loop keeps dashboard alive)
MON_PANE=$(tmux split-window -t "$PO_PANE" -h -l 33% -P -F '#{pane_id}' "cd $PROJECT_DIR && while true; do bash .kiro/scripts/dashboard.sh 10; echo 'Dashboard crashed — restarting in 3s...'; sleep 3; done")
record_pane "MONITOR" "$MON_PANE"

# ── Window 2: ORCHESTRATOR ──
create_agent_window "ORCHESTRATOR" "cd $PROJECT_DIR && kiro-cli chat -a --agent orchestrator; $AGENT_CMD"

# ── Window 3: ARCHITECT ──
create_agent_window "ARCHITECT" "cd $PROJECT_DIR && kiro-cli chat -a --agent architect; $AGENT_CMD"

# ── Window 4: PRINCIPAL-QA ──
create_agent_window "PRINCIPAL-QA" "cd $PROJECT_DIR && kiro-cli chat -a --agent principal-qa; $AGENT_CMD"

# ── Window 5: DEVELOPERS (2x2 grid) ──
WIN_DEV="${P}:DEVELOPERS"

# Create window with DEV-1
DEV1_PANE=$(tmux new-window -n "$WIN_DEV" -P -F '#{pane_id}' "cd $PROJECT_DIR && AGENT_NUMBER=1 kiro-cli chat -a --agent engineer; $AGENT_CMD")
tmux set-option -p -t "$DEV1_PANE" remain-on-exit on 2>/dev/null
record_pane "DEVELOPER-1" "$DEV1_PANE"
accept_trust "$DEV1_PANE"

if [ "$NUM_DEVS" -ge 2 ]; then
    DEV2_PANE=$(tmux split-window -t "$DEV1_PANE" -h -l 50% -P -F '#{pane_id}' "cd $PROJECT_DIR && AGENT_NUMBER=2 kiro-cli chat -a --agent engineer; $AGENT_CMD")
    tmux set-option -p -t "$DEV2_PANE" remain-on-exit on 2>/dev/null
    record_pane "DEVELOPER-2" "$DEV2_PANE"
    accept_trust "$DEV2_PANE"
fi

if [ "$NUM_DEVS" -ge 3 ]; then
    DEV3_PANE=$(tmux split-window -t "$DEV1_PANE" -v -l 50% -P -F '#{pane_id}' "cd $PROJECT_DIR && AGENT_NUMBER=3 kiro-cli chat -a --agent engineer; $AGENT_CMD")
    tmux set-option -p -t "$DEV3_PANE" remain-on-exit on 2>/dev/null
    record_pane "DEVELOPER-3" "$DEV3_PANE"
    accept_trust "$DEV3_PANE"
fi

if [ "$NUM_DEVS" -ge 4 ]; then
    DEV4_PANE=$(tmux split-window -t "$DEV2_PANE" -v -l 50% -P -F '#{pane_id}' "cd $PROJECT_DIR && AGENT_NUMBER=4 kiro-cli chat -a --agent engineer; $AGENT_CMD")
    tmux set-option -p -t "$DEV4_PANE" remain-on-exit on 2>/dev/null
    record_pane "DEVELOPER-4" "$DEV4_PANE"
    accept_trust "$DEV4_PANE"
fi

# ── Window 6: WATCHERS (harness monitors via supervisor) ──
WIN_WATCH="${P}:WATCHERS"
WATCH_PANE=$(tmux new-window -n "$WIN_WATCH" -P -F '#{pane_id}' "cd $PROJECT_DIR && bash .kiro/scripts/watcher-supervisor.sh; sleep infinity")
tmux set-option -p -t "$WATCH_PANE" remain-on-exit on 2>/dev/null
record_pane "WATCHERS" "$WATCH_PANE"

# ── Focus on COMMAND window ──
tmux select-window -t "$WIN_CMD"
tmux select-pane -t "$PO_PANE"

# Init messages are sent inside accept_trust() immediately after trust dialog acceptance.

echo ""
echo "🐝 Swarm launched (prefix: $P):"
echo "   ${P}:COMMAND — Product Owner (left) + Monitor (right)"
echo "   ${P}:ORCHESTRATOR — coordinates agents"
echo "   ${P}:ARCHITECT — context briefs, impact analysis"
echo "   ${P}:PRINCIPAL-QA — pre-merge review, regression checks"
echo "   ${P}:DEVELOPERS — $NUM_DEVS engineers in 2x2 grid"
echo "   ${P}:WATCHERS — harness monitors (done-watch, crash, heartbeat, drift, boundary)"
echo ""
echo "Pane manifest: $PANES_FILE"
echo "Switch windows: Ctrl+B n/p or Ctrl+B <number>"
