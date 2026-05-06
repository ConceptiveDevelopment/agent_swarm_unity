#!/bin/bash
# Compact shared memory — archive old entries, keep recent ones.
# Usage: bash .kiro/scripts/compact-memory.sh [keep_count]
# Default: keep last 20 entries in active memory.

set -e
cd "$(dirname "$0")/../.."

MEMORY=".kiro/swarm/memory.md"
KEEP="${1:-20}"
ARCHIVE_DIR=".kiro/swarm/archive"
ARCHIVE="$ARCHIVE_DIR/memory-$(date +%Y-%m).md"

if [ ! -f "$MEMORY" ]; then
    echo "No memory file found."
    exit 0
fi

# Count only timestamped entries (## YYYY-MM-DD ...), not structural headers
ENTRY_COUNT=$(grep -c '^## [0-9]\{4\}-' "$MEMORY" 2>/dev/null || echo 0)

if [ "$ENTRY_COUNT" -le "$KEEP" ]; then
    echo "Only $ENTRY_COUNT entries — nothing to compact."
    exit 0
fi

mkdir -p "$ARCHIVE_DIR"

# Find the line where the kept entries start
START_LINE=$(grep -n '^## [0-9]\{4\}-' "$MEMORY" | tail -"$KEEP" | head -1 | cut -d: -f1)

if [ -z "$START_LINE" ]; then
    echo "Could not determine start line — skipping compaction."
    exit 0
fi

# Archive only the entries being DROPPED (everything before START_LINE)
FIRST_ENTRY_LINE=$(grep -n '^## [0-9]\{4\}-' "$MEMORY" | head -1 | cut -d: -f1)
if [ -n "$FIRST_ENTRY_LINE" ] && [ "$FIRST_ENTRY_LINE" -lt "$START_LINE" ]; then
    if [ -f "$ARCHIVE" ]; then
        echo "" >> "$ARCHIVE"
    fi
    tail -n +"$FIRST_ENTRY_LINE" "$MEMORY" | head -n "$((START_LINE - FIRST_ENTRY_LINE))" >> "$ARCHIVE"
fi

# Rebuild memory with header + last N entries
TMPFILE=$(mktemp)
cat > "$TMPFILE" << 'HEADER'
# Shared Memory

Append-only log. Agents write discoveries, decisions, and warnings here. **Never edit or delete existing lines.** Newest entries go at the bottom.

---

HEADER

tail -n +"$START_LINE" "$MEMORY" >> "$TMPFILE"
mv "$TMPFILE" "$MEMORY"

echo "✅ Compacted: $ENTRY_COUNT entries → kept last $KEEP"
echo "   Archive: $ARCHIVE"

# ── Notify all agents to re-read memory ──
source .kiro/scripts/swarm-env.sh 2>/dev/null
for AGENT in ORCHESTRATOR ARCHITECT PRINCIPAL-QA DEVELOPER-1 DEVELOPER-2 DEVELOPER-3 DEVELOPER-4 PRODUCT-OWNER; do
    PANE_ID=$(swarm_pane_id "$AGENT" 2>/dev/null)
    [ -z "$PANE_ID" ] && continue
    tmux send-keys -t "$PANE_ID" "Memory compacted. Re-read .kiro/swarm/memory.md for current state." Enter 2>/dev/null
done
echo "   📢 Notified all agents to re-read memory"
