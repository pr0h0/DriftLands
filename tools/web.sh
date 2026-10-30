#!/usr/bin/env bash
# Export the web build and (re)start a static server on PORT (default 4956).
# Usage: [HOST=0.0.0.0] tools/web.sh [port]   then open http://localhost:<port>
set -e
cd "$(dirname "$0")/.."
PORT="${1:-4956}"
HOST="${HOST:-127.0.0.1}"  # HOST=0.0.0.0 to reach it from a phone on the same network
mkdir -p build/web
godot --headless --export-release "Web" build/web/index.html
if ! curl -s -o /dev/null "http://127.0.0.1:$PORT/"; then
  nohup python3 tools/serve.py "$PORT" "$HOST" > build/server.log 2>&1 &
  sleep 1
fi
echo "Driftlands web build ready: http://localhost:$PORT"
