#!/bin/bash
# Swarm analytics — cycle time, WIP duration, and throughput from Linear.
# Usage: bash .kiro/scripts/swarm-analytics.sh [days_back]
#
# Reads issue history from Linear to calculate:
#   - Time to start (created → in-progress)
#   - WIP duration (in-progress → in-review)
#   - Total cycle time (created → done)

cd "$(dirname "$0")/../.."
source .kiro/scripts/swarm-env.sh

DAYS="${1:-30}"

echo "📊 Swarm Analytics — Project $SWARM_PREFIX (last ${DAYS} days)"
echo ""

python3 << 'PYEOF'
import json, subprocess, sys, os
from datetime import datetime, timedelta, timezone

config = json.load(open('.kiro/swarm/config.json'))
team_id = config.get('linear_team_id', '')
api_key = os.environ.get(config.get('linear_api_key_env', 'LINEAR_API_KEY'), '')
days = int(sys.argv[1]) if len(sys.argv) > 1 else 30

if not api_key:
    print("❌ LINEAR_API_KEY not set in environment.")
    sys.exit(1)

cutoff = (datetime.now(timezone.utc) - timedelta(days=days)).isoformat()

query = '''
{
  issues(filter: {
    team: { id: { eq: "%s" } }
    completedAt: { gte: "%s" }
  }, first: 100) {
    nodes {
      identifier
      title
      createdAt
      startedAt
      completedAt
      estimate
    }
  }
}
''' % (team_id, cutoff)

result = subprocess.run(
    ['curl', '-s', '-X', 'POST', 'https://api.linear.app/graphql',
     '-H', f'Authorization: {api_key}',
     '-H', 'Content-Type: application/json',
     '-d', json.dumps({'query': query})],
    capture_output=True, text=True, timeout=15
)

if result.returncode != 0:
    print("❌ Failed to query Linear API.")
    sys.exit(1)

data = json.loads(result.stdout)
issues = data.get('data', {}).get('issues', {}).get('nodes', [])

if not issues:
    print("No completed issues found.")
    sys.exit(0)

print(f"{'Issue':<12} {'Title':<35} {'Cycle':>8} {'WIP':>8}")
print("─" * 70)

total_cycle = 0
total_wip = 0
count = 0

for issue in issues:
    identifier = issue['identifier']
    title = issue.get('title', '')[:33]
    created = datetime.fromisoformat(issue['createdAt'].replace('Z', '+00:00'))
    completed = datetime.fromisoformat(issue['completedAt'].replace('Z', '+00:00')) if issue.get('completedAt') else None
    started = datetime.fromisoformat(issue['startedAt'].replace('Z', '+00:00')) if issue.get('startedAt') else None

    if not completed:
        continue

    cycle = completed - created
    wip = (completed - started) if started else None

    def fmt(td):
        if td is None: return "—"
        mins = int(td.total_seconds() / 60)
        if mins < 60: return f"{mins}m"
        return f"{mins // 60}h{mins % 60:02d}m"

    total_cycle += int(cycle.total_seconds() / 60)
    if wip: total_wip += int(wip.total_seconds() / 60)
    count += 1

    print(f"{identifier:<12} {title:<35} {fmt(cycle):>8} {fmt(wip):>8}")

if count > 0:
    print("─" * 70)
    avg_cycle = total_cycle // count
    print(f"{'AVG':<12} {'(' + str(count) + ' issues)':<35} {avg_cycle // 60}h{avg_cycle % 60:02d}m")
    print(f"\nThroughput: {count} issues in {days} days = {count / max(days, 1):.1f} issues/day")
PYEOF
