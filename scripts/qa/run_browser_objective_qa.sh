#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

PORT="${1:-8060}"
STAMP="$(date +%s)"
URL="http://127.0.0.1:${PORT}/?qa_objective_auto=1&v=${STAMP}"
REPORT_PATH="$ROOT_DIR/docs/reports/qa_browser_objective_latest.json"
SCREENSHOT_PATH="/tmp/celadora-qa-browser-objective-latest.png"
QA_HEADLESS="${CELADORA_QA_HEADLESS:-1}"
QA_BROWSER_ARGS="${CELADORA_QA_BROWSER_ARGS:-}"

if [ ! -d "$ROOT_DIR/node_modules/playwright" ]; then
  npm install --no-audit --no-fund >/tmp/celadora-npm-install.log 2>&1
fi
if [ -d "$ROOT_DIR/node_modules" ]; then
  touch "$ROOT_DIR/node_modules/.gdignore"
fi

echo "[BrowserQA 1/4] Smoke checks..."
scripts/dev/smoke_check.sh

echo "[BrowserQA 2/4] Export web build..."
scripts/dev/export_web.sh

echo "[BrowserQA 3/4] Start preview server on :$PORT..."
scripts/dev/run_web_preview.sh "$PORT"

echo "[BrowserQA 4/4] Run Playwright objective flow QA..."
npx playwright install chromium >/tmp/celadora-playwright-install.log 2>&1 || true
CELADORA_QA_URL="$URL" \
CELADORA_QA_REPORT="$REPORT_PATH" \
CELADORA_QA_SCREENSHOT="$SCREENSHOT_PATH" \
CELADORA_QA_TIMEOUT_MS=45000 \
CELADORA_QA_HEADLESS="$QA_HEADLESS" \
CELADORA_QA_BROWSER_ARGS="$QA_BROWSER_ARGS" \
npm run qa:browser:objective --silent

echo "Browser objective QA report:"
echo "- $REPORT_PATH"
echo "- $SCREENSHOT_PATH"
