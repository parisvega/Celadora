#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

mkdir -p artifacts/authority

PORT="${1:-8787}"
PID_FILE="artifacts/authority/server.pid"
LOG_FILE="artifacts/authority/server.log"

if [[ -f "$PID_FILE" ]]; then
  EXISTING_PID="$(cat "$PID_FILE")"
  if kill -0 "$EXISTING_PID" >/dev/null 2>&1; then
    echo "Authority server already running on PID $EXISTING_PID"
    exit 0
  fi
  rm -f "$PID_FILE"
fi

nohup env CELADORA_AUTHORITY_PORT="$PORT" \
node scripts/server/authority_server.mjs >"$LOG_FILE" 2>&1 &
SERVER_PID=$!
echo "$SERVER_PID" >"$PID_FILE"

echo "Authority server started on http://127.0.0.1:$PORT (pid $SERVER_PID)"
echo "Logs: $LOG_FILE"
