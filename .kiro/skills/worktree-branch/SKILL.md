---
name: worktree-branch
description: >
  Create an isolated git worktree for a new branch, following best practices
  for parallel development. Use when the user says "create a worktree",
  "new branch in a worktree", "work on this in a separate directory",
  "set up a worktree for this feature", or needs to work on multiple
  branches simultaneously without stashing.
---

# Worktree Branch — Isolated Branch in a New Working Directory

Create a git worktree with a new branch, configured for immediate development. Follow every step in order.

## Step 1 — Assess the repository

Run these commands to understand the current state:

1. `git rev-parse --show-toplevel` — confirm we're in a git repo and find the root
2. `git branch --show-current` — current branch (this becomes the base branch)
3. `git status --short` — check for uncommitted changes
4. `git worktree list` — list existing worktrees to avoid conflicts
5. `git remote -v` — confirm the remote for push

If there are uncommitted changes, **warn the user** — worktrees share the same git objects, so uncommitted changes on tracked files won't carry over. Suggest committing or stashing first.

## Step 2 — Determine branch name and worktree path

Ask the user what they're working on if not already clear. Derive:

- **Branch name** — follow the project's existing convention. Common patterns:
  - `feature/<issue-id>-<short-description>` (e.g., `feature/42-login-page`)
  - `fix/<issue-id>-<short-description>` (e.g., `fix/87-null-check`)
  - `chore/<description>` (e.g., `chore/update-deps`)
  - If the project uses a `branch_prefix` in config, use it
- **Base branch** — default to the current branch. Ask if they want a different base (e.g., `main`, `develop`)
- **Worktree path** — place the worktree as a sibling directory to the repo root:
  ```
  ~/Developer/
  ├── my-project/          ← main repo (current)
  ├── my-project--feature-42-login/  ← worktree
  ```
  Convention: `<repo-name>--<branch-short-name>` (double-dash separator, slashes replaced with dashes)

**Wait for user confirmation** of the branch name and path before proceeding.

## Step 3 — Create the worktree

```bash
# Fetch latest from remote to ensure base is current
git fetch origin

# Create worktree with new branch based on the chosen base
git worktree add -b <branch-name> <worktree-path> <base-branch>
```

If the branch already exists remotely, track it instead:
```bash
git worktree add <worktree-path> <branch-name>
```

If the branch already exists locally and is checked out elsewhere, inform the user — git does not allow the same branch in two worktrees.

## Step 4 — Set up the worktree environment

```bash
cd <worktree-path>
```

Check for project setup needs:

1. **Dependencies** — if `package.json` exists, run `npm install` (or `yarn`/`pnpm`). If `requirements.txt` or `pyproject.toml`, run the appropriate install. If `Cargo.toml`, `cargo build` will handle it.
2. **Environment files** — check if `.env`, `.env.local`, or similar exist in the main repo but are gitignored. Warn the user they need to copy or symlink them:
   ```
   ⚠️  .env file exists in the main repo but won't be in the worktree (gitignored).
   Copy it: cp ../my-project/.env .env
   ```
3. **IDE config** — if `.vscode/` or `.idea/` exists and is gitignored, mention it.

**Ask the user** if they want dependencies installed now or if they'll handle it.

## Step 5 — Verify and summarize

```bash
git worktree list
git -C <worktree-path> log --oneline -1
git -C <worktree-path> branch --show-current
```

## Output

```
## Worktree Created

  Branch:    feature/42-login-page
  Base:      develop (at abc1234)
  Path:      ~/Developer/my-project--feature-42-login/
  Remote:    origin (git@host:group/my-project.git)

  Dependencies: installed / skipped / not applicable
  Env files:    copied / ⚠️ needs manual copy / not applicable

  To work in this worktree:
    cd ~/Developer/my-project--feature-42-login/

  To push when ready:
    git push -u origin feature/42-login-page

  To remove when done:
    git worktree remove ~/Developer/my-project--feature-42-login/
    git branch -d feature/42-login-page
```

## Gotchas

- A branch can only be checked out in ONE worktree at a time. If the user asks for a branch that's already checked out, explain and suggest a different name.
- Worktrees share the git object store — `git stash` in one worktree is visible in all others. Warn about this if the user stashes.
- Gitignored files (`.env`, `node_modules/`, build artifacts) are NOT shared between worktrees. Each worktree needs its own.
- Submodules need to be initialized separately in each worktree: `git submodule update --init`.
- If the main repo is moved or deleted, worktrees break. The `.git` file in the worktree points back to the main repo's `.git` directory.
- Long-lived worktrees diverge from the base branch. Remind the user to rebase periodically: `git rebase <base-branch>`.
- Worktrees consume disk space for dependencies (`node_modules`, `target/`, etc.). Clean up with `git worktree remove` when done.

## Constraints

- Never create a worktree inside the existing repo directory — always use a sibling path.
- Never force-checkout a branch that's already in another worktree.
- Always fetch before creating the worktree to ensure the base branch is current.
- The worktree path must not already exist as a directory.
- Branch names must follow the project's existing convention — don't invent a new pattern.

For detailed reference on git worktree commands, see `references/worktree-reference.md`.
