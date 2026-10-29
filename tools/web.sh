#!/usr/bin/env bash
# Export the web build and (re)start a static server on PORT (default 4956).
# Usage: tools/web.sh [port]   then open http://localhost:<port>
set -e
cd "$(dirname "$0")/.."
PORT="${1:-4956}"
mkdir -p build/web
godot --headless --export-release "Web" build/web/index.html
if ! curl -s -o /dev/null "http://127.0.0.1:$PORT/"; then
  nohup python3 -m http.server "$PORT" --bind 127.0.0.1 --directory build/web > build/server.log 2>&1 &
  sleep 1
fi
echo "Driftlands web build ready: http://localhost:$PORT"
