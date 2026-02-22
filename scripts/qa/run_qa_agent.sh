#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

echo "[1/2] Running offline-capable headless QA..."
scripts/qa/run_headless_qa.sh

echo "[2/2] QA agent complete."
echo "Latest reports:"
echo "- $ROOT_DIR/docs/reports/qa_latest.md"
echo "- $ROOT_DIR/docs/reports/qa_latest.json"
echo "- $ROOT_DIR/docs/reports/qa_browser_latest.json"
