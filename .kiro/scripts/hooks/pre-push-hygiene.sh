#!/bin/bash
# Git pre-push hook — runs project hygiene checks before pushing.
# Installed by update-swarm.sh into .git/hooks/pre-push.
# Only runs when pushing to git.ejgallo.com. Warns but does not block.

REMOTE="$1"
URL="$2"

# Only check pushes to git.ejgallo.com
echo "$URL" | grep -q "git.ejgallo.com" || exit 0

echo "🧹 Pre-push hygiene check..."

ERRORS=0
WARNINGS=0
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"

# 1. Uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
    echo "  ⚠️  Uncommitted changes on working tree"
    WARNINGS=$((WARNINGS + 1))
fi

# 2. Tag vs changelog version
LATEST_TAG=$(git tag -l --sort=-v:refname 'v*' | head -1)
CHANGELOG_VER=$(grep -m1 '^## \[' CHANGELOG.md 2>/dev/null | sed 's/## \[\(.*\)\].*/\1/')
if [ -n "$CHANGELOG_VER" ] && [ -n "$LATEST_TAG" ]; then
    TAG_VER="${LATEST_TAG#v}"
    if [ "$TAG_VER" != "$CHANGELOG_VER" ]; then
        echo "  ❌ Tag $LATEST_TAG doesn't match changelog [$CHANGELOG_VER]"
        ERRORS=$((ERRORS + 1))
    fi
elif [ -n "$CHANGELOG_VER" ] && [ -z "$LATEST_TAG" ]; then
    echo "  ❌ Changelog says [$CHANGELOG_VER] but no tags exist"
    ERRORS=$((ERRORS + 1))
fi

# 3. VERSION file vs changelog (if exists)
# Skip .kiro/swarm/VERSION — it tracks the swarm framework version, not the app.
# Only check a root-level VERSION file if present.
if [ -f "VERSION" ]; then
    FILE_VER=$(cat VERSION | tr -d '[:space:]')
    if [ -n "$CHANGELOG_VER" ] && [ "$FILE_VER" != "$CHANGELOG_VER" ]; then
        echo "  ❌ VERSION file ($FILE_VER) doesn't match changelog [$CHANGELOG_VER]"
        ERRORS=$((ERRORS + 1))
    fi
fi

# 4. Stale local branches (merged into default branch)
STALE=$(git branch --merged "$DEFAULT_BRANCH" 2>/dev/null | grep -v "^\*\|$DEFAULT_BRANCH" | tr -d ' ')
if [ -n "$STALE" ]; then
    echo "  ⚠️  Stale local branches (merged): $(echo $STALE | tr '\n' ' ')"
    WARNINGS=$((WARNINGS + 1))
fi

# 5. CHANGELOG exists
if [ ! -f "CHANGELOG.md" ]; then
    echo "  ❌ No CHANGELOG.md"
    ERRORS=$((ERRORS + 1))
fi

# 6. LICENSE exists
if [ ! -f "LICENSE" ]; then
    echo "  ⚠️  No LICENSE file"
    WARNINGS=$((WARNINGS + 1))
fi

# Summary
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "  ✅ All checks passed"
else
    [ $ERRORS -gt 0 ] && echo "  🔴 $ERRORS error(s)"
    [ $WARNINGS -gt 0 ] && echo "  🟡 $WARNINGS warning(s)"
    echo "  Push continues — fix these when you can."
fi

# Never block push — just inform
exit 0
