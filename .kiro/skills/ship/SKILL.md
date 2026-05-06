---
name: ship
description: >
  Commit, version, document, and push in one step. Use when shipping code
  to GitHub — after implementing a feature, completing a review, or any
  time you need to commit + push changes. Adapted for swarm agents that
  operate autonomously without human input during execution.
---

# /ship — Commit, Version, Document & Push

Follow every step in order. Do not skip steps.

## Step 1 — Pre-flight checks

1. `git status` — identify all staged, unstaged, and untracked changes
2. `git diff --stat` — summarize what changed
3. `git log --oneline -5` — recent commit history for message style reference
4. `git remote -v` — confirm the push target

**Sensitive file gate:** Check whether any staged files match `.env*`, `*secret*`, `*credential*`, `*token*`, `*.pem`, `*.key`. If so, **do not proceed** — report the issue in your done file.

If there are no changes to ship, stop and say so.

## Step 2 — Analyze changes

Read the full diff (`git diff` and `git diff --cached`) and determine:

- What changed (features, fixes, refactors, docs, deps, config)
- Whether changes are breaking, additive, or patch-level

## Step 3 — Commit

1. Stage all relevant files. **Do not** stage sensitive files or files outside your task scope.
2. Write a commit message following **Conventional Commits** format matching the repo's existing style:
   - `feat(<scope>): <description> — Implements <TICKET-ID>`
   - `fix(<scope>): <description> — Implements <TICKET-ID>`
   - `docs(<scope>): <description> — Implements <TICKET-ID>`
3. Include a body with bullet points summarizing key changes if there are more than 3 files changed.
4. Create the commit.

## Step 4 — Push

```bash
git push origin HEAD
```

If the push fails (e.g. behind remote), try `git pull --rebase` then retry. **Never force push.**

## Step 5 — Verify

```bash
git status
git log origin/$(git branch --show-current)..HEAD
```

Working tree must be clean. No unpushed commits.

## Constraints

- Respect `.gitignore` — never stage ignored files
- Sensitive files must never be staged without explicit human confirmation
- Never force push
- Always verify push succeeded before reporting done
