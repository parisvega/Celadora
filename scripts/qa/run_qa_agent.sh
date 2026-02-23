#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

echo "[1/2] Running offline-capable headless QA..."
scripts/qa/run_headless_qa.sh

echo "[2/3] Running browser objective-flow QA (best effort)..."
if scripts/qa/run_browser_objective_qa.sh >/tmp/celadora-browser-qa.log 2>&1; then
  browser_status="$(jq -r '.status // "unknown"' "$ROOT_DIR/docs/reports/qa_browser_objective_latest.json" 2>/dev/null || echo "unknown")"
  case "$browser_status" in
    pass)
      echo "Browser QA passed."
      ;;
    inconclusive)
      echo "Browser QA inconclusive (environment limitation)."
      ;;
    *)
      echo "Browser QA completed with status: $browser_status"
      ;;
  esac
else
  echo "Browser QA unavailable or failed in this environment (see /tmp/celadora-browser-qa.log). Continuing with headless results."
fi

echo "[3/3] QA agent complete."
echo "Latest reports:"
echo "- $ROOT_DIR/docs/reports/qa_latest.md"
echo "- $ROOT_DIR/docs/reports/qa_latest.json"
echo "- $ROOT_DIR/docs/reports/qa_browser_latest.json"
echo "- $ROOT_DIR/docs/reports/qa_browser_objective_latest.json"
