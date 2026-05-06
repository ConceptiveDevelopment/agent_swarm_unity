# Swarm Communication Protocol

File-based message passing between agents. All files live in `.kiro/swarm/`.

## Flow: Human → Product Owner → Orchestrator → Agents

```
Human describes feature
  → PO writes Linear issue + task-orchestrator.md
    → Orchestrator requests context brief from Architect
      → Architect writes brief-NNN.md
    → Orchestrator assigns developer with brief included
      → Developer implements, pushes, writes done file
    → Orchestrator sends to QA for pre-merge review
      → QA reviews diff + brief, gives verdict
    → Orchestrator merges, sends to PO for acceptance
      → PO reviews from user perspective: ACCEPT or REJECT
    → Orchestrator closes Linear issue
```

## Task Assignment (Product Owner → Orchestrator)

```markdown
# Task: New Issue Ready
## Type: issue-ready
## Issue: <TICKET-ID> — <title>
## Priority: P<N>
## Notes: <context>
```

## Task Assignment (Orchestrator → Developer)

```markdown
# Task: <TICKET-ID>
## Title: <from Linear issue>
## Linear URL: https://linear.app/team/issue/<TICKET-ID>
## Branch: feature/NNN-<short-name>
## Depends on: #MMM — or "none"
## Files to create:
- path/to/new/file.py
## Files to modify:
- path/to/existing/file.py
## Context:
<paste from .kiro/swarm/brief-NNN.md — architect-generated>
## Acceptance criteria: <from Linear issue>
## Build command:
make test
```

## Acceptance Review (Orchestrator → Product Owner)

```markdown
# Task: Acceptance Review
## Type: acceptance-review
## Issue: <TICKET-ID> — <title>
## Done file: .kiro/swarm/done-developer-N.md
## QA verdict: PASS
```

## Completion Report (Developer → Orchestrator)

```markdown
# Done: <TICKET-ID>
## Status: PASS | FAIL | BLOCKED
## Branch: feature/NNN-short-name
## Push verified: yes
## Acceptance Criteria Self-Check:
- [x] Criterion 1 — MET (file.py:34-67)
- [ ] Criterion 2 — NOT MET (reason)
## Files changed:
- path/to/file1.py (created, 150 lines)
- path/to/file2.py (modified, +20 -5 lines)
## Build verified: yes
## API contracts preserved: yes
## Design decisions:
- Chose X over Y because Z
## Known limitations:
- Edge case not covered
## Discovered Issues:
- [P1 bug] Null check missing in auth.py:42 — crashes on empty token
## Notes:
- Gotchas found during implementation
## Time spent: ~15 minutes
```

## Shared State

| File | Writer | Reader | Purpose |
|------|--------|--------|---------|
| `vision.md` | Product Owner | All agents | Project purpose, goals, non-goals |
| `memory.md` | All agents | All agents | Append-only shared findings (compacted) |
| `status.md` | Orchestrator | All agents | Human-readable status board |
| `status.json` | Orchestrator | Scripts | Structured task state + dependencies |
| `config.json` | Human | All agents | Project configuration |
| `panes.json` | swarm.sh | Scripts | Tmux pane ID manifest for session-safe routing |

## Key Rules

- Human talks to Product Owner only — PO talks to orchestrator
- Agents MUST push their branch before writing done files
- Agents report discovered issues in done files — only the orchestrator creates Linear issues
- Tasks with open blockers (in status.json) are never assigned
- Linear is the source of truth for all issues — status.json is the orchestrator's working state
- Orchestrator requests context brief from architect before assigning non-trivial developer tasks
- Orchestrator requests impact analysis from architect before assigning parallel tasks
- Orchestrator requests post-merge validation from architect after merging developer branches
- Orchestrator requests pre-merge review from QA before merging any developer branch
- QA verdict is binding: FAIL means the developer must fix before merge
- Product Owner does final acceptance review before issues are closed
- After merging 3+ branches in one session, orchestrator requests cross-agent consistency check from QA
