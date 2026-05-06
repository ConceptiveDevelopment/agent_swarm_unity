#!/bin/bash
# Update swarm files from agent_swarm repo.
# Usage: bash .kiro/scripts/update-swarm.sh [agent_swarm_path]
#
# Shows what would change (added/modified/deleted) and waits for confirmation.
# Preserves config.json and runtime state.

set -e
cd "$(dirname "$0")/../.."

SWARM_REPO="${1:-$HOME/Developer/agent_swarm}"

if [ ! -d "$SWARM_REPO/.kiro" ]; then
    echo "⚠️  agent_swarm repo not found at $SWARM_REPO — skipping update"
    exit 0
fi

LOCAL_VERSION=$(cat .kiro/swarm/VERSION 2>/dev/null || echo "0.0.0")
REMOTE_VERSION=$(cat "$SWARM_REPO/.kiro/swarm/VERSION" 2>/dev/null || echo "unknown")

if [ "$LOCAL_VERSION" = "$REMOTE_VERSION" ]; then
    echo "✅ Swarm v${LOCAL_VERSION} — up to date"
    exit 0
fi

echo "🔄 Swarm update available: v${LOCAL_VERSION} → v${REMOTE_VERSION}"

# Pull latest in agent_swarm repo
git -C "$SWARM_REPO" pull --ff-only 2>/dev/null || true
REMOTE_VERSION=$(cat "$SWARM_REPO/.kiro/swarm/VERSION" 2>/dev/null || echo "unknown")

# --- Dry-run: compute what would change ---
ADDED=""
MODIFIED=""
DELETED=""

for dir in agents scripts skills; do
    # Files that would be deleted (exist locally but not in source)
    if [ -d ".kiro/$dir" ]; then
        while IFS= read -r f; do
            [ -z "$f" ] && continue
            rel=".kiro/$dir/$f"
            if [ ! -e "$SWARM_REPO/$rel" ]; then
                DELETED="${DELETED}  🗑️  $rel\n"
            fi
        done < <(cd ".kiro/$dir" && find . -type f | sed 's|^\./||' 2>/dev/null)
    fi

    # Files that would be added or modified
    if [ -d "$SWARM_REPO/.kiro/$dir" ]; then
        while IFS= read -r f; do
            [ -z "$f" ] && continue
            rel=".kiro/$dir/$f"
            if [ ! -e "$rel" ]; then
                ADDED="${ADDED}  ➕ $rel\n"
            elif ! diff -q "$SWARM_REPO/$rel" "$rel" >/dev/null 2>&1; then
                MODIFIED="${MODIFIED}  📝 $rel\n"
            fi
        done < <(cd "$SWARM_REPO/.kiro/$dir" && find . -type f | sed 's|^\./||' 2>/dev/null)
    fi
done

# Check swarm scaffolding files
for f in VERSION README.md; do
    if [ -f "$SWARM_REPO/.kiro/swarm/$f" ]; then
        if [ ! -f ".kiro/swarm/$f" ]; then
            ADDED="${ADDED}  ➕ .kiro/swarm/$f\n"
        elif ! diff -q "$SWARM_REPO/.kiro/swarm/$f" ".kiro/swarm/$f" >/dev/null 2>&1; then
            MODIFIED="${MODIFIED}  📝 .kiro/swarm/$f\n"
        fi
    fi
done

# --- Print change summary ---
HAS_CHANGES=false

if [ -n "$DELETED" ]; then
    echo ""
    echo "Files that will be DELETED (exist locally but not in agent_swarm):"
    echo -e "$DELETED"
    HAS_CHANGES=true
fi

if [ -n "$MODIFIED" ]; then
    echo ""
    echo "Files that will be MODIFIED:"
    echo -e "$MODIFIED"
    HAS_CHANGES=true
fi

if [ -n "$ADDED" ]; then
    echo ""
    echo "Files that will be ADDED:"
    echo -e "$ADDED"
    HAS_CHANGES=true
fi

if [ "$HAS_CHANGES" = false ]; then
    echo "No file changes detected (version bump only)."
fi

echo ""
echo "Preserved (never overwritten): config.json, status.json, memory.md, vision.md, status.md"
echo ""
echo "SWARM_UPDATE_CHANGES_START"
if [ -n "$DELETED" ]; then echo -e "DELETED:\n$DELETED"; fi
if [ -n "$MODIFIED" ]; then echo -e "MODIFIED:\n$MODIFIED"; fi
if [ -n "$ADDED" ]; then echo -e "ADDED:\n$ADDED"; fi
echo "SWARM_UPDATE_CHANGES_END"
echo ""
echo "Run 'bash .kiro/scripts/update-swarm.sh --apply' to apply, or let the agent confirm."

# --- Apply only if --apply flag or SWARM_AUTO_APPLY is set ---
APPLY=false
for arg in "$@"; do
    [ "$arg" = "--apply" ] && APPLY=true
done
[ "${SWARM_AUTO_APPLY:-}" = "1" ] && APPLY=true

if [ "$APPLY" = false ]; then
    exit 0
fi

echo "Applying update..."

# Sync agents, scripts, skills
for dir in agents scripts skills; do
    rsync -a --delete --exclude='archive/' "$SWARM_REPO/.kiro/$dir/" ".kiro/$dir/"
done

# Sync swarm scaffolding — only VERSION and README
for f in VERSION README.md; do
    [ -f "$SWARM_REPO/.kiro/swarm/$f" ] && cp "$SWARM_REPO/.kiro/swarm/$f" ".kiro/swarm/$f"
done

# Copy template files only if missing
for f in vision.md memory.md status.md status.json; do
    [ ! -f ".kiro/swarm/$f" ] && [ -f "$SWARM_REPO/.kiro/swarm/$f" ] && cp "$SWARM_REPO/.kiro/swarm/$f" ".kiro/swarm/$f"
done

echo "✅ Swarm updated to v${REMOTE_VERSION}"

# Install/update git pre-push hook
HOOK_SRC=".kiro/scripts/hooks/pre-push-hygiene.sh"
HOOK_DST=".git/hooks/pre-push"
if [ -f "$HOOK_SRC" ]; then
    if [ ! -f "$HOOK_DST" ] || ! diff -q "$HOOK_SRC" "$HOOK_DST" >/dev/null 2>&1; then
        cp "$HOOK_SRC" "$HOOK_DST"
        chmod +x "$HOOK_DST"
        echo "   Installed pre-push hygiene hook"
    fi
fi
