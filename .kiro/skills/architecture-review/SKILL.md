---
name: architecture-review
description: >
  Use when the user says "review the architecture", "map dependencies",
  "find dead code", "check for hotspots", "draw a diagram of the codebase",
  or asks about circular dependencies, orphan files, complexity hotspots,
  or structural problems. Full codebase audit with dependency graphs,
  mermaid diagrams, and complexity analysis.
---

# Architecture Review

## Steps

1. Scan all source files and build an import/dependency graph. Identify circular dependencies and list external dependencies with versions.
2. Generate mermaid diagrams:
   - Top-level module dependency diagram
   - Data flow diagram showing key paths through the system
   - Output as fenced `mermaid` code blocks
3. Detect orphans — files not imported by any other module, exported symbols with zero consumers. Flag dead code candidates.
4. Detect complexity hotspots:
   - High fan-in files (>5 importers) — risky to change, many dependents
   - High fan-out files (>8 imports) — tightly coupled, hard to test
   - Large files (>500 lines) — candidates for splitting
5. Write a markdown summary report to `docs/architecture/`.
6. For each problem found, document it in the `## Discovered Issues` section of your done file:
   - Title: `[Arch] <short description>`
   - Suggested labels: `architecture`, `tech-debt`
   - Description with the relevant diagram excerpt and remediation suggestion
   - The orchestrator will create the Linear issues from your report

## Output

```markdown
# Architecture Review — 2026-04-13

## Circular Dependencies
- `moduleA` → `moduleB` → `moduleA` (via shared types)

## Orphan Files
- `src/utils/legacy_helper.py` — 0 importers

## Complexity Hotspots
| File | Fan-in | Fan-out | Lines | Risk |
|------|--------|---------|-------|------|
| src/db/users.py | 8 | 3 | 420 | High fan-in — changes ripple to 8 files |
| src/api/routes.py | 2 | 12 | 680 | High fan-out + large — split candidate |

## Diagrams
(mermaid blocks here)

## Discovered Issues
- [Arch] Circular dependency between moduleA and moduleB
- [Arch] Orphan file legacy_helper.py
- [Arch] users.py is a hotspot — 8 dependents, no interface abstraction
```

## Gotchas

- Don't flag test files or config files as orphans — they're consumed by tooling, not imports.
- Mermaid diagrams break if node names contain special characters — sanitize to alphanumeric + hyphens.
- Some projects use dynamic imports or dependency injection — the static scan will miss those. Note this limitation in the report.
- Always create issues AFTER the full scan, not during — you need the complete picture to avoid duplicate issues.
- Fan-in thresholds are guidelines, not rules — a utility file with 20 importers is normal. Flag it only if changes to it would be risky.

## Constraints

- Never modify source code — this skill is read-only analysis.
- Diagrams go in `docs/architecture/`, not inline in issues.
- Every discovered issue must include file paths and a suggested fix approach.
