#!/bin/bash
# Rebuild status.json from Linear API.
# Caps: 5 in-progress, 5 open/backlog, 5 most-recently-closed.
# Preserves agent assignments from existing status.json.
# Usage: bash .kiro/scripts/sync-status.sh

set -e
cd "$(dirname "$0")/../.."
source .kiro/scripts/swarm-env.sh || exit 1

TEAM_ID=$(python3 -c "import json; print(json.load(open('$SWARM_CONFIG')).get('linear_team_id',''))" 2>/dev/null)
API_KEY_ENV=$(python3 -c "import json; print(json.load(open('$SWARM_CONFIG')).get('linear_api_key_env','LINEAR_API_KEY'))" 2>/dev/null)
API_KEY="${!API_KEY_ENV}"

[ -z "$TEAM_ID" ] && { echo "❌ Missing linear_team_id in config.json"; exit 1; }
[ -z "$API_KEY" ] && { echo "❌ $API_KEY_ENV not set in environment"; exit 1; }

STATUS=".kiro/swarm/status.json"

python3 - "$TEAM_ID" "$API_KEY" "$STATUS" << 'PYEOF'
import json, os, sys, urllib.request

team_id, api_key, status_path = sys.argv[1], sys.argv[2], sys.argv[3]

def linear_query(query, variables=None):
    payload = json.dumps({"query": query, "variables": variables or {}}).encode()
    req = urllib.request.Request(
        "https://api.linear.app/graphql",
        data=payload,
        headers={"Authorization": api_key, "Content-Type": "application/json"}
    )
    try:
        resp = urllib.request.urlopen(req, timeout=15)
        return json.loads(resp.read())
    except Exception as e:
        print(f"⚠️ Linear API error: {e}", file=sys.stderr)
        return {}

# Preserve existing agent assignments
agents = {}
try:
    old = json.load(open(status_path))
    agents = old.get("agents", {})
except (FileNotFoundError, json.JSONDecodeError):
    pass

# Fetch issues from Linear
query = """
query($teamId: String!, $first: Int!) {
  issues(filter: { team: { id: { eq: $teamId } } }, first: $first, orderBy: updatedAt) {
    nodes {
      identifier
      title
      priority
      state { name type }
      assignee { name }
    }
  }
}
"""
result = linear_query(query, {"teamId": team_id, "first": 50})
nodes = result.get("data", {}).get("issues", {}).get("nodes", [])

# Categorize
in_progress = []
backlog = []
closed = []

for issue in nodes:
    state_type = issue.get("state", {}).get("type", "")
    if state_type == "started":
        in_progress.append(issue)
    elif state_type in ("completed", "canceled"):
        closed.append(issue)
    elif state_type in ("unstarted", "backlog"):
        backlog.append(issue)

def issue_to_task(issue, status):
    return {
        "title": issue["title"],
        "status": status,
        "priority": issue.get("priority") or 3,
    }

tasks = {}
for i in in_progress[:5]:
    tasks[i["identifier"]] = issue_to_task(i, "in_progress")
for i in backlog[:5]:
    tasks[i["identifier"]] = issue_to_task(i, "open")
for i in closed[:5]:
    tasks[i["identifier"]] = issue_to_task(i, "closed")

# Ensure agents exist — discover developers from panes.json
panes_path = os.path.join(os.path.dirname(status_path), "panes.json")
try:
    panes = json.load(open(panes_path))
    dev_names = sorted(k.lower() for k in panes if k.startswith("DEVELOPER"))
except (FileNotFoundError, json.JSONDecodeError):
    dev_names = ["developer-1", "developer-2", "developer-3", "developer-4"]

for name in dev_names + ["architect", "principal-qa", "product-owner"]:
    if name not in agents:
        agents[name] = {"status": "idle", "current_task": None}

result = {"tasks": tasks, "agents": agents}
with open(status_path, "w") as f:
    json.dump(result, f, indent=2)

counts = {"in_progress": 0, "open": 0, "closed": 0}
for t in tasks.values():
    counts[t["status"]] = counts.get(t["status"], 0) + 1
print(f"✅ status.json synced — {counts['in_progress']} in-progress, {counts['open']} backlog, {counts['closed']} done ({len(tasks)} total)")
PYEOF
