---
name: release-checklist
description: >
  Use when the user says "release", "cut a release", "version bump", "tag
  and push", "prepare a release", or asks to ship a new version. Walks
  through version bump, changelog, commit, tag, push, and GitHub release
  creation.
---

# Release Checklist

## Steps

1. **Version Bump** — Update version string in config/manifest files. **Ask the user for the version number before proceeding.**
2. **Changelog** — Add release section to `CHANGELOG.md` with date and categorized entries (Added, Changed, Fixed, Removed).
3. **Commit** — `git commit -am "chore: release vX.Y.Z"`
4. **Tag** — `git tag -a vX.Y.Z -m "Release vX.Y.Z"`
5. **Push** — `git push origin main --follow-tags`
6. **GitHub Release** — Create a GitHub release from the tag with changelog contents as description.
7. **Verify** — Confirm pipeline passes on the tagged commit.

## Output

```
✅ Version bumped to 1.3.0 in config.json
✅ CHANGELOG.md updated with v1.3.0 section
✅ Committed: chore: release v1.3.0
✅ Tagged: v1.3.0
✅ Pushed to origin/main with tags
✅ GitHub release created: https://github.com/YourOrg/your-repo/releases/tag/v1.3.0
✅ Pipeline passing on v1.3.0
```

## Gotchas

- Always run `project-hygiene` first — releasing with stale branches or missing changelog entries creates confusion.
- Don't guess the version number — ask the user. Semver rules are context-dependent (breaking change vs patch).
- If the pipeline fails after push, the tag is already public. Document how to recover (delete tag, fix, re-tag) rather than silently retrying.
- Some projects have multiple version files (package.json, pyproject.toml, etc.) — find all of them before bumping.

## Constraints

- Never force-push tags — if a tag exists, stop and ask.
- Changelog entries must reference MR or issue numbers.
- The GitHub release description must match the changelog section exactly.
