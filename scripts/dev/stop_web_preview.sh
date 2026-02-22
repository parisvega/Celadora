#!/usr/bin/env bash
set -euo pipefail

PID_FILE="/tmp/celadora-web.pid"

if [ ! -f "$PID_FILE" ]; then
  echo "No PID file found at $PID_FILE"
  exit 0
fi

PID="$(cat "$PID_FILE")"
if [ -n "$PID" ] && ps -p "$PID" >/dev/null 2>&1; then
  kill "$PID" || true
  echo "Stopped preview server PID $PID"
else
  echo "No running process for PID $PID"
fi

rm -f "$PID_FILE"
