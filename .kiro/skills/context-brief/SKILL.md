---
name: context-brief
description: >
  Use when the orchestrator says "generate a context brief", "what does
  this code do", "prepare context for a task", or needs to understand
  the blast radius of a change before assigning it to a developer.
  Produces a focused brief covering dependencies, data flow, API
  contracts, and risk areas for a specific set of files.
---

# Context Brief

## Steps

1. Read the files listed in the task and all files they import/depend on (one level deep).
2. For each file, document:
   - Purpose (one sentence)
   - Fan-in: what imports/calls this file
   - Fan-out: what this file imports/calls
   - Data flow: what data enters, transforms, and exits
3. Identify API contracts — function signatures, data models, protocols that other code depends on. Mark any that the developer must NOT break.
4. Map blast radius — if these files change, what else could break? List files and why.
5. Note related files NOT in the task that the developer should read for context (but not modify).
6. Write the brief to `.kiro/swarm/brief-NNN.md` (where NNN is the issue number without `#`).

## Output

```markdown
# Context Brief: <TICKET-ID>

## Files in Scope
### src/auth/login.py
- Purpose: Handles user login flow and token generation
- Fan-in: src/api/routes.py, src/middleware/auth.py
- Fan-out: src/db/users.py, src/utils/crypto.py
- Data flow: receives credentials → validates against DB → returns JWT
- API contract: `authenticate(email, password) -> Token` — used by 3 callers

### src/db/users.py
- Purpose: User database queries
- Fan-in: src/auth/login.py, src/auth/register.py, src/admin/users.py
- Fan-out: src/db/connection.py
- Data flow: receives query params → returns User objects
- API contract: `get_user(email) -> User | None` — used by 4 callers

## Blast Radius
- Changing `authenticate()` signature breaks: routes.py, auth.py, test_login.py
- Changing `User` model breaks: 6 files across auth/ and admin/

## Read for Context (don't modify)
- src/middleware/auth.py — calls authenticate(), will break if signature changes
- src/utils/crypto.py — token format, developer needs to know the structure

## Risks
- High fan-in on users.py (4 importers) — changes here ripple widely
- No type hints on authenticate() — easy to break contract silently
```

## Gotchas

- Keep it focused — only what the developer needs for THIS task. Don't dump the whole architecture.
- Fan-in > 5 is a red flag — highlight it explicitly.
- If a file has no tests covering it, mention that as a risk.
- Dynamic imports and dependency injection won't show up in static analysis — note the limitation.

## Constraints

- Never modify source code — read-only.
- Brief must fit in a task file without overwhelming the developer — aim for under 100 lines.
- Always include the blast radius section — this is the highest-value part.
