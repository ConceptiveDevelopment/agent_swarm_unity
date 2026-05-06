---
name: docs-update
description: >
  Update project documentation after features are merged. Use when the user
  says "update docs", "update the readme", "changelog is stale", "docs are
  out of date", or after merging features that change project structure,
  APIs, or behavior. Adapts to the project's existing documentation format.
---

# Docs Update — Keep Documentation Current After Changes

## Steps

### Step 1 — Assess what changed

1. Read `git log --oneline` since the last documented version (check CHANGELOG.md for the latest entry)
2. For each commit/merge, identify: new features, fixes, changed APIs, new files/directories, removed functionality
3. Read the current README.md, CHANGELOG.md, and any API/schema docs to understand the existing format and structure

### Step 2 — Update CHANGELOG.md

Follow the project's existing CHANGELOG format. If using [Keep a Changelog](https://keepachangelog.com/):

1. If an `[Unreleased]` section exists, add entries there
2. If not, create one above the latest version
3. Categorize entries: `### Added`, `### Changed`, `### Fixed`, `### Removed`
4. Each entry should reference the issue/MR number and describe the change from the user's perspective
5. Don't duplicate entries already in the CHANGELOG

### Step 3 — Update README.md

Adapt to the project's existing README structure. Do NOT impose a new format — match what's there.

Common sections to check and update:
- **Project status / feature tables** — add new features, update completion status
- **Project structure / directory tree** — add new directories and key files
- **Getting started / installation** — update if setup steps changed
- **Configuration** — add new config options, env vars, or settings
- **API reference** — add new endpoints or changed signatures
- **Version** — bump if referenced in the README

**Getting Started sections must always include two paths:**
1. Ask your AI agent to do it (paste a prompt the user can give to Kiro/Claude/Copilot)
2. Manual steps (commands to run)

### Step 4 — Update other docs

Check for and update if they exist:
- `API_SPECIFICATION.md` — new endpoints, changed request/response shapes
- `DATABASE_SCHEMA.md` — new tables, changed fields
- `docs/architecture/` — new diagrams if structure changed significantly
- Any project-specific docs referenced in README

### Step 5 — Verify and present

1. `git diff --stat` — show what changed
2. Present a summary of all documentation updates

## Output

```
## Docs Update Summary

CHANGELOG.md:
- Added N entries under [Unreleased]
- Covers issues #X through #Y

README.md:
- Updated: [list of sections changed]
- No changes needed: [list of sections checked but current]

Other docs:
- [file]: [what was updated]
- [file]: no changes needed

Files changed: N
```

## Gotchas

- Don't rewrite the README — update it. Match the existing tone, format, and structure.
- CHANGELOG entries should describe what changed for the user, not implementation details. "Added password reset flow" not "Created reset.py with generate_token function".
- If the project has no CHANGELOG.md, create one following Keep a Changelog format.
- If the README has a version badge or version string, update it to match the latest version.
- Don't remove existing content unless it's factually wrong — add to it.
- Check git tags to determine the current version: `git tag --list | sort -V | tail -1`.

## Constraints

- Always preserve the project's existing documentation format and structure.
- CHANGELOG entries must reference issue or MR numbers when available.
- Getting Started sections must include both AI-assisted and manual installation paths.
- Never fabricate feature descriptions — only document what's actually in the code.
- Read the actual source files to verify claims before documenting them.
