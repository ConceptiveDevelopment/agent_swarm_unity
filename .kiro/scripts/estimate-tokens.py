#!/usr/bin/env python3
"""Estimate token usage for kiro-cli agent sessions.

Scans ~/.kiro/sessions/cli/ for sessions matching the current project and date.
Outputs per-agent breakdown and cost estimate.

Usage:
    python3 .kiro/scripts/estimate-tokens.py [--date YYYY-MM-DD] [--project NAME] [--cost-per-mtok FLOAT]

Defaults: today's date, project name from current directory, $3.00/MTok.
"""

import argparse
import glob
import json
import os
from collections import defaultdict
from datetime import datetime, timezone

# Default blended cost per million tokens (input+output average)
DEFAULT_COST_PER_MTOK = 3.00


def estimate(project, date, cost_per_mtok):
    sessions = glob.glob(os.path.expanduser("~/.kiro/sessions/cli/*.json"))
    agents = defaultdict(lambda: {"sessions": 0, "turns": 0, "peak_ctx": 0, "est_input": 0, "est_output": 0})

    for sf in sessions:
        try:
            d = json.load(open(sf))
            if project not in d.get("cwd", ""):
                continue
            if not d.get("created_at", "").startswith(date):
                continue
            turns = d.get("session_state", {}).get("conversation_metadata", {}).get("user_turn_metadatas", [])
            if not turns:
                continue
            agent = d.get("session_state", {}).get("agent_name") or "unknown"
            peak_ctx = max(t.get("context_usage_percentage", 0) for t in turns)
            est_input = int(peak_ctx / 100 * 200000)
            est_output = len(turns) * 3500
            a = agents[agent]
            a["sessions"] += 1
            a["turns"] += len(turns)
            a["peak_ctx"] = max(a["peak_ctx"], peak_ctx)
            a["est_input"] += est_input
            a["est_output"] += est_output
        except Exception:
            pass

    if not agents:
        print("No sessions found.")
        return

    # Per-agent table
    print(f"{'Agent':<18} {'Sessions':>8} {'Turns':>7} {'Peak%':>6} {'Input':>12} {'Output':>12} {'Total':>12}")
    print("-" * 77)
    totals = {"sessions": 0, "turns": 0, "peak_ctx": 0, "est_input": 0, "est_output": 0}
    for agent in sorted(agents):
        a = agents[agent]
        total = a["est_input"] + a["est_output"]
        print(f"{agent:<18} {a['sessions']:>8} {a['turns']:>7} {a['peak_ctx']:>5.1f}% {a['est_input']:>11,} {a['est_output']:>11,} {total:>11,}")
        for k in totals:
            if k == "peak_ctx":
                totals[k] = max(totals[k], a[k])
            else:
                totals[k] += a[k]

    grand_total = totals["est_input"] + totals["est_output"]
    print("-" * 77)
    print(f"{'TOTAL':<18} {totals['sessions']:>8} {totals['turns']:>7} {totals['peak_ctx']:>5.1f}% {totals['est_input']:>11,} {totals['est_output']:>11,} {grand_total:>11,}")

    # Cost estimate
    cost = (grand_total / 1_000_000) * cost_per_mtok
    print(f"\nEst. cost: ${cost:.2f} (@ ${cost_per_mtok:.2f}/MTok)")
    if totals["peak_ctx"] > 70:
        print(f"⚠️  COMPACT RECOMMENDED — an agent hit {totals['peak_ctx']:.0f}% context")


def main():
    parser = argparse.ArgumentParser(description="Estimate kiro-cli token usage")
    parser.add_argument("--date", default=datetime.now(timezone.utc).strftime("%Y-%m-%d"))
    parser.add_argument("--project", default=os.path.basename(os.getcwd()))
    parser.add_argument("--cost-per-mtok", type=float, default=DEFAULT_COST_PER_MTOK)
    args = parser.parse_args()
    estimate(args.project, args.date, args.cost_per_mtok)


if __name__ == "__main__":
    main()
