---
name: nudge-swarm
description: >
  Use when the user asks about swarm status, wants to poke or nudge the
  swarm, says "check status", "poke swarm", "nudge swarm", "kick the
  agents", "what's happening", "is the swarm stuck", "wake them up",
  "status update", "progress check", or similar prompts requesting
  swarm health and forward progress.
---

# Nudge Swarm — Diagnose & Unstick the Agent Swarm

Diagnose the swarm state, report to the human, and take corrective action
to keep work flowing. This is the human's "poke the anthill" button.

## Steps

1. **Read swarm state** — Gather all signals in parallel:
   - `.kiro/swarm/status.json` — agent assignments and task statuses
   - `ls .kiro/swarm/done-*.md` — unprocessed completion reports
   - `ls .kiro/swarm/task-*.md` — pending task assignments
   - `tail -20 .kiro/swarm/memory.md` — recent activity
   - `tmux list-panes -a -F '#{session_name}:#{window_name}:#{pane_index}'` — which agents are alive

2. **Diagnose stuck points** — Check for these failure modes in order:
   - **Unprocessed done files**: done-*.md exists but orchestrator hasn't merged/reassigned → orchestrator is stuck
   - **Stale task files**: task-*.md older than 15 minutes with no corresponding done file → agent may be stuck
   - **Idle agents with open backlog**: status.json shows agent idle but ready tasks exist → orchestrator missed assignment
   - **Blocked tasks**: tasks with unresolved blocked_by dependencies → check if blocker is actually done
   - **Missing agents**: status.json lists agents not found in tmux → agent crashed or session lost

3. **Report to human** — Concise status table:
   ```
   | Agent | Status | Task | Issue |
   ```
   Then list:
   - ⚠️ Stuck points found (with root cause)
   - ✅ What's working
   - 📋 What's queued next

4. **Take corrective action** — For each stuck point:
   - **Orchestrator not processing done files**: Rewrite `task-orchestrator.md` with explicit merge/assign instructions, then `tmux send-keys` to the orchestrator pane
   - **Agent stuck on task**: `tmux send-keys` to the agent pane with "Your task file is ready. Read .kiro/swarm/task-<name>.md and begin."
   - **QA not reviewing**: `tmux send-keys` to QA pane with nudge
   - **Idle developers with no task file**: Write task-orchestrator.md requesting assignment, nudge orchestrator
   - **Agent pane missing from tmux**: Report to human — needs manual restart

   Use the tmux targeting format: `tmux send-keys -t "<session>:<window>" "<message>" Enter`
   where session and window names come from `tmux list-panes` output.

5. **Confirm action taken** — Tell the human exactly what you did:
   - Which agents were nudged
   - What task files were written
   - What the expected next state is

## Output

```
🐝 SWARM STATUS — <timestamp>

| Agent        | Status    | Task     |
|--------------|-----------|----------|
| orchestrator | 🔨/💤/⚠️ | ...      |

⚠️ STUCK: <description of stuck point>
→ ACTION: <what was done to fix it>

📋 NEXT UP: <what should happen next>
```

## Gotchas

- The orchestrator is the most common failure point — it must process done files, merge branches, update status.json, and assign new work. If it stalls, everything stalls.
- `send-task.sh` uses `panes.json` manifest which may not exist. Fall back to direct `tmux send-keys -t "session:window"` targeting.
- Done files are the handoff signal. If they exist and haven't been deleted, the orchestrator hasn't processed them.
- Don't merge branches yourself — that's the orchestrator's job. Just nudge it.
- Don't reassign tasks — just tell the orchestrator what needs doing.
- Check `tmux list-panes` output to get the correct session:window targeting format for the current environment.
- Multiple swarm sessions may exist (different projects). Target only the current project's session.

## Constraints

- Never merge branches or modify status.json directly — the orchestrator owns those.
- Never delete done files — the orchestrator deletes them after processing.
- Always report what you found AND what you did to the human.
- If the swarm is healthy (no stuck points), just report status — don't nudge unnecessarily.
