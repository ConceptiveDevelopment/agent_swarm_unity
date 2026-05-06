#!/bin/bash
# preToolUse hook — validate done file before allowing write.
# Blocks fs_write to done-*.md if branch not pushed or content invalid.
# Exit 0 = allow, Exit 2 = block.

cd "$(dirname "$0")/../../.."

EVENT=$(cat)

# Extract write target path
TARGET=$(echo "$EVENT" | python3 -c "
import json, sys
e = json.load(sys.stdin)
inp = e.get('tool_input', {})
path = inp.get('path', '')
print(path)
" 2>/dev/null)

# Only gate done-developer-*.md files
case "$TARGET" in
    *done-developer*.md|*.kiro/swarm/done-developer*.md) ;;
    *) exit 0 ;;
esac

# Extract content being written
CONTENT=$(echo "$EVENT" | python3 -c "
import json, sys
e = json.load(sys.stdin)
inp = e.get('tool_input', {})
print(inp.get('file_text', inp.get('new_str', '')))
" 2>/dev/null)

# Check for required sections
ERRORS=""
for section in "## Status:" "## Branch:" "## Push verified:" "## Files changed:" "## Tests:" "## Time spent:"; do
    if ! echo "$CONTENT" | grep -q "$section"; then
        ERRORS="${ERRORS}Missing section: $section. "
    fi
done

# Check for hedging language
if echo "$CONTENT" | grep -qiE "\bshould pass\b|\bI believe\b|\blikely pass\b|\bI'm confident\b|\btests would\b|\bprobably work\b"; then
    ERRORS="${ERRORS}Hedging language detected — cite specific evidence instead of assumptions. "
fi

# Extract branch and verify push
BRANCH=$(echo "$CONTENT" | grep -m1 "^## Branch:" | sed 's/## Branch: *//')
if [ -n "$BRANCH" ]; then
    if ! git ls-remote --heads origin "$BRANCH" 2>/dev/null | grep -q "$BRANCH"; then
        ERRORS="${ERRORS}Branch '$BRANCH' not found on remote — push before writing done file. "
    fi
fi

# Check status value
STATUS=$(echo "$CONTENT" | grep -m1 "^## Status:" | sed 's/## Status: *//')
if ! echo "$STATUS" | grep -qE "^(PASS|FAIL|BLOCKED)"; then
    ERRORS="${ERRORS}Status must be PASS, FAIL, or BLOCKED — got '$STATUS'. "
fi

if [ -n "$ERRORS" ]; then
    echo "DONE FILE BLOCKED: $ERRORS" >&2
    exit 2
fi

exit 0
