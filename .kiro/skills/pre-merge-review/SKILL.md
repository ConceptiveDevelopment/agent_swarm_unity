---
name: pre-merge-review
description: >
  Use when the orchestrator says "review this branch", "check before merge",
  "QA this developer's work", or needs a quality gate before merging a
  developer branch to main. Reviews the diff, verifies acceptance criteria,
  checks test coverage, and gives a PASS/FAIL verdict.
---

# Pre-Merge Review

## Steps

1. Read the developer's done file for context — what was the task, which files changed, what decisions were made.
2. Read the architect's context brief (path in task file under `## Architect brief`) — check what blast radius and API contracts were flagged.
3. Run `git diff main...<branch>` and review every changed line against the checklist:
   - **Crashes**: nil/null access, index out of bounds, unhandled errors
   - **Data Integrity**: race conditions, missing validation, lossy conversions
   - **Edge Cases**: empty collections, max/min values, missing error paths
   - **Logic**: does the code actually do what the acceptance criteria require?
   - **Blast radius**: did the developer respect the boundaries from the architect's brief? Were flagged API contracts preserved?
4. Check acceptance criteria — read each criterion from the task file and verify it's met in the code.
5. Check test coverage — did the developer add tests? Are critical paths covered?
6. Give a verdict and document findings.

## Output

```markdown
# Pre-Merge Review: <TICKET-ID>
## Branch: feature/NNN-short-name
## Verdict: PASS | FAIL | PASS WITH ISSUES

## Acceptance Criteria
- [x] User can log in with email/password — MET (login.py:34-67)
- [ ] Error shown on invalid credentials — NOT MET (no error handling for 401 response)

## Findings
### [Sev 2] No error handling for failed login
**Level 1 — Symptom**: User sees nothing when credentials are wrong.
**Level 2 — Mechanism**: login.py:52 calls API but doesn't check response status.
**Level 3 — Root Cause**: Happy path implemented, error path not in acceptance criteria but expected.
**Fix**: Add status check after API call, show error message.

## Test Coverage
- ✅ test_login_success exists
- ❌ No test for invalid credentials
- ❌ No test for network timeout

## Summary
1 Sev-2 finding, 2 missing tests. Recommend FAIL — send back for error handling.
```

## Gotchas

- Review the DIFF, not the whole codebase — stay focused on what changed.
- PASS WITH ISSUES means: safe to merge now, but file follow-up bugs. Use this when findings are low severity and blocking the merge would waste more time than the bugs cost.
- If the developer's done file says "Build verified: yes" but you see obvious issues, flag the discrepancy.
- Don't block merges for style issues or minor naming concerns — only for functional problems.

## Constraints

- Never modify source code — report only.
- Must give a clear PASS/FAIL/PASS WITH ISSUES verdict — no "it depends."
- Every finding must include file path, line number, and 3-level analysis.
- Acceptance criteria check is mandatory — don't skip it even if no bugs found.
