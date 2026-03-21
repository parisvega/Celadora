#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

PID_FILE="artifacts/authority/server.pid"

if [[ ! -f "$PID_FILE" ]]; then
  echo "Authority server is not running."
  exit 0
fi

SERVER_PID="$(cat "$PID_FILE")"
if kill -0 "$SERVER_PID" >/dev/null 2>&1; then
  kill "$SERVER_PID"
  echo "Stopped authority server pid $SERVER_PID"
else
  echo "Authority server pid $SERVER_PID was not running."
fi

rm -f "$PID_FILE"
