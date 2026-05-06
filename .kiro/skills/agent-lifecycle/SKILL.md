---
name: agent-lifecycle
description: >
  Standard lifecycle for all swarm agents. Use as the base behavior for
  every agent in the swarm. Defines how agents watch for task files,
  execute assigned work, land the plane (push, verify, report), and update
  shared memory. Loaded automatically by agent configs — not triggered
  by user phrases.
---

# Agent Lifecycle

Every agent in the swarm follows this loop:

## Steps

1. **Check for task** — `cat .kiro/swarm/task-<your-name>.md`. If it exists, read it fully and proceed. If not, say "Idle — waiting for task assignment" and wait.
2. **Execute** — Follow the task file instructions. Work only on listed files. Use the specified branch. Include `Implements <TICKET-ID>` in commits.
3. **Discover, don't fix** — If you find bugs or issues outside your task scope, note them in the `## Discovered Issues` section of your done file. Do NOT fix them. Do NOT create Linear issues — the orchestrator does that.
4. **Land the plane** — Complete ALL steps in the Landing Protocol below. Work is NOT done until the branch is pushed.
5. **Report completion** — Write `.kiro/swarm/done-<your-name>.md` (see Output).
6. **Update shared memory** — Append findings to `.kiro/swarm/memory.md`. Never overwrite existing lines.
7. **Clean up** — Delete your task file. Say "Task complete — idle" and wait.

## Landing Protocol

Before writing your done file, you MUST complete every step:

1. Run the build/test command from the task file (if applicable)
2. `git add` all changed files
3. `git commit` with appropriate message:
   - Engineers: `feat(<scope>): <description> — Implements <TICKET-ID>`
   - Architect: `docs(architecture): <description>`
   - QA: `docs(qa): <description>`
   - Only engineers use `Implements <TICKET-ID>` in commits — architect and QA report findings, they don't close issues
4. `git push origin <your-branch>`
5. `git status` — must show clean working tree
6. Verify: `git log origin/<your-branch>..HEAD` — must be empty (everything pushed)

If any step fails, report it in the done file with `Status: BLOCKED` and explain what failed. Do NOT leave unpushed commits.

## Output

```markdown
# Done: <TICKET-ID>
## Status: PASS
## Branch: feature/NNN-short-name
## Push verified: yes
## Acceptance Criteria Self-Check:
- [x] Criterion 1 — MET (file.py:34-67)
- [x] Criterion 2 — MET (file.py:70-85)
## Files changed:
- path/to/file1.py (created, 150 lines)
- path/to/file2.py (modified, +20 -5 lines)
## Build verified: yes
## API contracts preserved: yes — authenticate() signature unchanged
## Design decisions:
- Chose X over Y because Z
## Specs/references used:
- Real-world data source or GDD section
## Known limitations:
- What doesn't work yet or edge cases not covered
## Discovered Issues:
- [P1 bug] Null check missing in auth.py:42 — crashes on empty token
- [P2 task] Config loader doesn't handle missing keys gracefully
## Notes:
- Gotchas discovered
## Time spent: ~15 minutes
```

## Gotchas

- Always read the FULL task file before starting — don't assume context from the title alone.
- Never modify files not listed in your task — another agent may be working on them concurrently.
- Always verify build before writing the done file — a PASS with a broken build wastes the orchestrator's time.
- If blocked, write the done file with `Status: BLOCKED` and explain why — don't sit idle without reporting.
- Append to `memory.md`, never overwrite it — other agents' entries are there too.
- The done file must be verbose enough for the orchestrator to copy directly into a Linear issue comment without editing.
- NEVER say "ready to push when you are" — YOU must push. Unpushed work breaks coordination across agents.
- Discovered issues go in the done file ONLY — do not go off-task to create Linear issues or fix unrelated code.

## Constraints

- Never merge branches — only the orchestrator merges.
- Never modify files outside your task assignment.
- Every commit must reference the Linear issue number from the task file.
- Task file format and done file format are non-negotiable — the orchestrator parses them.
- Work is NOT complete until `git push` succeeds and `git status` is clean.
