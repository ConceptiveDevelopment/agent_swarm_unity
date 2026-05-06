---
name: deep-qa-review
description: >
  Use when the user says "run QA", "find bugs", "deep review", "check for
  crashes", "review this code for issues", or asks for a thorough quality
  audit before a release. Performs risk-prioritized per-file checklist
  (crash, data integrity, edge cases), traces every bug 3 levels to root
  cause, and reports findings for the orchestrator.
---

# Deep QA Review

## Steps

1. Prioritize files by risk:
   - First: files flagged as hotspots by the architect (check memory.md and docs/architecture/)
   - Second: files with no test coverage
   - Third: recently changed files (git log --since="2 weeks ago" --name-only)
   - Last: everything else
2. For each source file, run through the checklist:
   - **Crashes**: nil/null access, index out of bounds, unhandled errors, force unwraps
   - **Data Integrity**: race conditions, stale state, missing validation, lossy conversions
   - **UI Bugs**: layout overflow, missing loading/error states, accessibility gaps
   - **Edge Cases**: empty collections, max/min values, rapid repeated input, offline state
3. For every finding, perform 3-level root cause analysis (see Output).
4. Check memory.md for known issues — don't duplicate existing findings.
5. Document each bug in the `## Discovered Issues` section of your done file:
   - Title: `[QA] <short description>`
   - Suggested labels: `bug`, `qa-review`, `severity::<1-4>`
   - Description using the 3-level template
   - The orchestrator will create the Linear issues from your report

## Output

```markdown
### Bug: Crash on empty search results
**Level 1 — Symptom**: App crashes when search returns no results.
**Level 2 — Mechanism**: `results[0]` accessed without bounds check in SearchView.swift:47.
**Level 3 — Root Cause**: The API contract assumes non-empty results; no guard was added when the empty-state feature was cut from sprint 3.
**Fix**: Add `guard !results.isEmpty` before access in SearchView.swift:45.
**Severity**: 1 (crash)
```

## Gotchas

- Don't report style issues or naming conventions as bugs — this is a quality review, not a linter.
- Severity 1 = crash/data loss, 2 = wrong behavior, 3 = degraded UX, 4 = cosmetic. Don't inflate.
- If you can't trace to Level 3, say so — a partial analysis is better than a fabricated root cause.
- Check test files for coverage of the bug path, but don't create issues against test code itself.
- Check memory.md before reporting — another agent may have already found the same issue.

## Constraints

- Never modify source code — report only.
- Every issue must include file path and line number.
- Every issue must have all 3 levels filled in (or explicitly marked unknown).
