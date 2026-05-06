#!/bin/bash
# Launch Chrome with remote debugging enabled for browser-watcher.py.
# Uses a separate profile (~/.chrome-debug) because Chrome requires
# a non-default --user-data-dir for --remote-debugging-port.
#
# Note: This is a separate profile — you'll need to authenticate once.
# Sessions persist across restarts in ~/.chrome-debug.
#
# Usage: bash .kiro/scripts/chrome-debug.sh [port]
# Default port: 9222

if [ "$(uname)" != "Darwin" ]; then
    echo "❌ This script is macOS-only."
    exit 1
fi

PORT="${1:-9222}"
DATA_DIR="$HOME/.chrome-debug"

# Check if already running on this port
if curl -s "http://localhost:$PORT/json/version" >/dev/null 2>&1; then
    echo "✅ Chrome debugging already active on port $PORT"
    curl -s "http://localhost:$PORT/json/version" | python3 -c "import json,sys; d=json.load(sys.stdin); print(f'   Browser: {d[\"Browser\"]}')"
    exit 0
fi

# Kill existing Chrome if running (required — can't add debug port to running instance)
if pgrep -q "Google Chrome"; then
    echo "⚠️  Killing existing Chrome (required to enable debugging port)..."
    pkill -9 "Google Chrome"
    sleep 3
fi

echo "🚀 Launching Chrome with debugging on port $PORT"
echo "   Profile: $DATA_DIR"
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
    --remote-debugging-port="$PORT" \
    --user-data-dir="$DATA_DIR" &>/dev/null &

# Wait for port to be ready
for i in $(seq 1 10); do
    sleep 1
    if curl -s "http://localhost:$PORT/json/version" >/dev/null 2>&1; then
        echo "✅ Chrome debugging active on port $PORT"
        exit 0
    fi
done

echo "❌ Chrome started but port $PORT not responding. Check if another process uses it."
exit 1
