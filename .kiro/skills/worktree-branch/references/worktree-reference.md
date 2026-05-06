# Git Worktree Reference

Detailed reference for git worktree commands and patterns.

## Core Commands

```bash
# Create worktree with new branch
git worktree add -b <branch> <path> <base>

# Create worktree for existing branch
git worktree add <path> <branch>

# List all worktrees
git worktree list

# Remove a worktree (directory must be clean)
git worktree remove <path>

# Force remove (discards changes)
git worktree remove --force <path>

# Clean up stale worktree references
git worktree prune
```

## Directory Naming Convention

Use `<repo>--<branch-slug>` as a sibling to the main repo:

```
~/Developer/
├── my-project/                          ← main repo
├── my-project--feature-42-login/        ← worktree
├── my-project--fix-87-null-check/       ← worktree
└── my-project--chore-update-deps/       ← worktree
```

Convert branch names to directory-safe slugs:
- `feature/42-login-page` → `feature-42-login-page`
- `fix/87-null-check` → `fix-87-null-check`

## Common Branch Prefixes

| Prefix | Use case |
|--------|----------|
| `feature/` | New functionality |
| `fix/` or `bugfix/` | Bug fixes |
| `chore/` | Maintenance, deps, config |
| `docs/` | Documentation only |
| `refactor/` | Code restructuring |
| `hotfix/` | Urgent production fix |

## Cleanup Workflow

```bash
# After merging, remove the worktree and branch
git worktree remove ~/Developer/my-project--feature-42-login/
git branch -d feature/42-login-page

# Clean up any stale references
git worktree prune
```

## Gotchas Quick Reference

| Issue | Solution |
|-------|----------|
| Branch already checked out | Use a different branch name or remove the other worktree |
| `.env` missing in worktree | Copy from main repo: `cp ../main-repo/.env .env` |
| `node_modules` missing | Run `npm install` in the worktree |
| Submodules not initialized | Run `git submodule update --init` |
| Stash visible across worktrees | Expected — git stash is repo-wide, not worktree-scoped |
| Worktree broken after moving main repo | Re-create the worktree |
