#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

PORT="${1:-8060}"
PID_FILE="/tmp/celadora-web.pid"
LOG_FILE="/tmp/celadora-web.log"

if [ -f "$PID_FILE" ]; then
  OLD_PID="$(cat "$PID_FILE" || true)"
  if [ -n "$OLD_PID" ] && ps -p "$OLD_PID" >/dev/null 2>&1; then
    kill "$OLD_PID" || true
  fi
fi

nohup python3 -m http.server "$PORT" --directory build/web >"$LOG_FILE" 2>&1 &
echo $! >"$PID_FILE"

sleep 1

echo "Preview server running on http://127.0.0.1:$PORT"
echo "PID: $(cat "$PID_FILE")"
echo "Log: $LOG_FILE"
