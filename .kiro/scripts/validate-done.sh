#!/bin/bash
# Validate a developer done file before accepting it.
# Usage: bash .kiro/scripts/validate-done.sh <done-file-path>
#
# Checks:
#   1. Branch exists on remote (push was real)
#   2. No unpushed commits on the branch
#   3. Done file has required sections
#   4. No hedging language ("should pass", "I believe", "likely")
#
# Exit 0 = valid, Exit 1 = invalid (prints reasons)

set -euo pipefail
cd "$(dirname "$0")/../.."

DONE_FILE="$1"
if [ -z "$DONE_FILE" ] || [ ! -f "$DONE_FILE" ]; then
    echo "Usage: validate-done.sh <done-file-path>"
    exit 1
fi

ERRORS=""

# Extract branch name from done file
BRANCH=$(grep -m1 "^## Branch:" "$DONE_FILE" | sed 's/## Branch: *//')
if [ -z "$BRANCH" ]; then
    ERRORS="${ERRORS}\n❌ Missing '## Branch:' in done file"
fi

# Extract push verified
PUSH_VERIFIED=$(grep -m1 "^## Push verified:" "$DONE_FILE" | sed 's/## Push verified: *//')

# Check required sections
for section in "## Status:" "## Branch:" "## Push verified:" "## Files changed:" "## Acceptance Criteria Self-Check:"; do
    if ! grep -q "$section" "$DONE_FILE"; then
        ERRORS="${ERRORS}\n❌ Missing section: $section"
    fi
done

# Check for hedging language (phantom verification)
HEDGING=$(grep -iE "should pass|I believe|likely pass|I'm confident|tests would|probably work|I expect" "$DONE_FILE" || true)
if [ -n "$HEDGING" ]; then
    ERRORS="${ERRORS}\n⚠️ Hedging language detected — cite specific evidence instead:\n$(echo "$HEDGING" | head -3)"
fi

# Verify branch exists on remote (if branch was extracted)
if [ -n "$BRANCH" ]; then
    REMOTE_CHECK=$(git ls-remote --heads origin "$BRANCH" 2>&1) || true
    if echo "$REMOTE_CHECK" | grep -q "fatal\|error\|Could not"; then
        ERRORS="${ERRORS}\n⚠️ Could not reach remote to verify branch (network issue?) — skipping push check"
    elif ! echo "$REMOTE_CHECK" | grep -q "$BRANCH"; then
        ERRORS="${ERRORS}\n❌ Branch '$BRANCH' not found on remote — push may have failed"
    else
        # Check for unpushed commits
        git fetch origin "$BRANCH" --quiet 2>/dev/null || true
        UNPUSHED=$(git log "origin/$BRANCH..$BRANCH" --oneline 2>/dev/null || true)
        if [ -n "$UNPUSHED" ]; then
            ERRORS="${ERRORS}\n❌ Unpushed commits on $BRANCH:\n$UNPUSHED"
        fi
    fi
fi

# Check status is PASS/FAIL/BLOCKED
STATUS=$(grep -m1 "^## Status:" "$DONE_FILE" | sed 's/## Status: *//')
if ! echo "$STATUS" | grep -qE "^(PASS|FAIL|BLOCKED)"; then
    ERRORS="${ERRORS}\n❌ Status must be PASS, FAIL, or BLOCKED — got: '$STATUS'"
fi

if [ -n "$ERRORS" ]; then
    echo "🚫 Done file validation FAILED:"
    echo -e "$ERRORS"
    exit 1
else
    echo "✅ Done file validated: $BRANCH — $STATUS"
    exit 0
fi
