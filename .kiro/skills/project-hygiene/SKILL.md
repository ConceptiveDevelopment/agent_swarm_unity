---
name: project-hygiene
description: >
  Use when the user says "clean up the project", "audit the repo",
  "check project hygiene", "are we in sync", or asks whether git state,
  tags, changelog, docs, and Linear issues are consistent. Runs a
  checklist across git, tags, changelog, docs, and issue tracker.
---

# Project Hygiene

## Steps

1. **Git** — Verify no uncommitted changes on main, all feature branches merged or closed, remote up to date with local.
2. **Tags** — Confirm latest tag matches version in changelog and config. Tags must follow semver (`vX.Y.Z`).
3. **Changelog** — Verify `CHANGELOG.md` has an entry for every merged MR since last release, categorized (Added, Changed, Fixed, Removed).
4. **Docs** — Confirm README reflects current setup steps. Flag stale architecture docs.
5. **Linear Issues** — All completed work has closed issues. No "doing" issues without an active assignee. Milestone progress matches actual state.
6. Report findings as a checklist with pass/fail per item.

## Output

```markdown
# Project Hygiene Audit — 2026-04-13

| Area | Check | Status |
|------|-------|--------|
| Git | No uncommitted changes on main | ✅ |
| Git | All feature branches merged | ❌ feature/12-login stale |
| Tags | Latest tag matches changelog | ✅ v1.2.0 |
| Changelog | Entries for all merged MRs | ❌ MR !34 missing |
| Docs | README current | ✅ |
| Issues | No orphaned "doing" issues | ❌ #18 has no assignee |

## Actions Needed
- Delete or merge `feature/12-login`
- Add changelog entry for MR !34
- Assign or close issue #18
```

## Gotchas

- Don't auto-delete branches or close issues — report them and let the user decide.
- A tag on a commit that isn't on main is suspicious but not always wrong (hotfix branches). Flag it, don't fail it.
- Changelog entries from squash-merged MRs may not match individual commit messages — check MR titles instead.

## Constraints

- Read-only — never modify git state, issues, or files. Report only.
- Always check remote state (`git fetch` first) — don't rely on stale local refs.
