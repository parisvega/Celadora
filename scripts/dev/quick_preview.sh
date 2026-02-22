#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

PORT="${1:-8060}"
STAMP="$(date +%s)"
URL="http://127.0.0.1:${PORT}/?v=${STAMP}"

scripts/dev/smoke_check.sh
scripts/dev/export_web.sh
scripts/dev/run_web_preview.sh "$PORT"

echo "Preview URL: $URL"
if command -v open >/dev/null 2>&1; then
  open "$URL"
fi
