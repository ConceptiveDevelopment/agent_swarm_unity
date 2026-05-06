---
name: session-summary
description: >
  Use when wrapping up a work session, ending for the day, or when the user
  says "wrap up", "that's enough", "let's stop", "session summary", or
  "what did we do today". Runs hygiene checks, ships pending work, then
  generates a structured session summary.
dependencies:
  - project-hygiene
  - ship
---

# Session Summary

Wrap up a work session: fix hygiene issues, ship pending work, summarize
what happened, and save locally.

## Steps

### 1. Run project-hygiene

Follow the **project-hygiene** skill. Fix anything actionable:
- Stale CHANGELOG → add entries for issues closed this session
- Stale README → update if features changed
- Stale branches → delete merged locals
- Tag mismatch → note it (tagging happens in ship step)

Report unfixable items (open issues without assignees, external blockers)
in the summary under Blocked / Parked.

### 2. Ship pending work

Follow the **ship** skill for any uncommitted changes from step 1:
- Stage hygiene fixes (CHANGELOG, README, docs)
- Commit, push, verify clean
- If a version bump is warranted, tag it

If the session produced a deployable artifact, note deployment status.

### 3. Gather session data

Read these sources:
- `.kiro/swarm/status.json` — task states, completions
- `.kiro/swarm/memory.md` — decisions and discoveries
- `git log --since="<session start>" --oneline` — commits
- Linear issues completed this session (from status.json)
- Linear issues still open
- `python3 .kiro/scripts/estimate-tokens.py` — token usage

Calculate duration from first commit timestamp to current time.
Format as: `~X hours Y minutes (HH:MM – HH:MM TZ)`

### 4. Write the summary

Use this template. **Omit any section with no content.**

```markdown
# Session Summary — YYYY-MM-DD

**Duration:** ~X hours Y minutes (HH:MM – HH:MM PDT)

## Session Goals

- Goal 1 — what the human asked to accomplish
- Goal 2

## Completed

| Issue | Title | Priority | Notes |
|-------|-------|----------|-------|
| PROJ-42 | Title | P1 | Brief note |

## What Shipped

Narrative of what was accomplished — readable by a non-technical stakeholder.
Group related items into a cohesive story.

## Token Usage & Cost

| Agent | Sessions | Turns | Peak% | Input | Output | Total |
|-------|----------|-------|-------|-------|--------|-------|
| engineer | N | N | N% | N | N | N |
| orchestrator | N | N | N% | N | N | N |
| ... | | | | | | |
| **TOTAL** | **N** | **N** | **N%** | **N** | **N** | **N** |

**Est. cost:** $X.XX (@ $3.00/MTok)

## Commits

N commits to main. (If ≤5, list them.)

## Next Session

- What to start with and why
- What's blocked and what unblocks it
```

**Optional sections** — include only when applicable:

- **Deferred** — issues intentionally postponed, with reason
- **Cross-Repo Impact** — work that affected or unblocked other projects
- **Deployment Status** — table of environments, status, pipeline/method
- **Blocked / Parked** — long-term blockers persisting across sessions
- **Cleanup** — worktrees removed, branches deleted

### 5. Post and save

1. Add a comment to the Linear project with the session summary (if Linear API available)
2. Save to `.kiro/swarm/session-summary.md`
3. If any agent exceeded 70% context, recommend compaction:
   `bash .kiro/scripts/compact-memory.sh 20`
4. Signal orchestrator (if in swarm mode):
   ```
   # Task: Session End
   ## Type: session-end
   ```

## Gotchas

- Duration is approximate — don't obsess over exact minutes
- If no commits exist, note it was a planning/design session
- Bugs go in the Completed table with root cause in Notes
- Sub-tasks can be rolled up: parent row with "N sub-tasks merged"
- "Deferred" = postponed this session. "Blocked" = long-term.

## Constraints

- Requires `python3` for token estimation
- Linear API key must be set as `LINEAR_API_KEY` for issue tracking
