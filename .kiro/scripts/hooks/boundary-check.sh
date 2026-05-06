#!/bin/bash
# preToolUse hook — block file access outside project directory.
# Reads JSON from STDIN with tool_name and tool_input.
# Exit 0 = allow, Exit 2 = block (STDERR returned to agent).

cd "$(dirname "$0")/../../.."
PROJECT_DIR="$(pwd)"

EVENT=$(cat)

# Extract file paths from tool_input
PATHS=$(echo "$EVENT" | python3 -c "
import json, sys
e = json.load(sys.stdin)
inp = e.get('tool_input', {})
paths = []
# fs_read/fs_write operations array
for op in inp.get('operations', []):
    if 'path' in op: paths.append(op['path'])
    for p in op.get('image_paths', []): paths.append(p)
# fs_write direct path
if 'path' in inp: paths.append(inp['path'])
for p in paths:
    print(p)
" 2>/dev/null)

[ -z "$PATHS" ] && exit 0

while IFS= read -r filepath; do
    # Resolve to absolute path
    if [[ "$filepath" == /* ]]; then
        ABS="$filepath"
    else
        ABS="$PROJECT_DIR/$filepath"
    fi

    # Normalize (remove ..)
    ABS=$(cd "$(dirname "$ABS")" 2>/dev/null && echo "$(pwd)/$(basename "$ABS")" || echo "$ABS")

    # Allow common system paths
    case "$ABS" in
        /tmp/*|/dev/*|/usr/*|/bin/*|/var/*|/etc/*|/opt/*|/System/*|/Library/*|/private/*)
            continue ;;
    esac

    # Block if outside project dir
    if [[ "$ABS" != "$PROJECT_DIR"* ]]; then
        echo "BOUNDARY VIOLATION: Attempted to access $filepath which is outside the project directory ($PROJECT_DIR). Stay within your project." >&2
        exit 2
    fi
done <<< "$PATHS"

exit 0
