#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

echo "[1/3] Smoke checks..."
scripts/dev/smoke_check.sh

echo "[2/3] Running Godot headless QA runner..."
set +e
QA_OUTPUT=$(docker run --rm --platform linux/amd64 \
  -v "$ROOT_DIR":/workspace \
  -w /workspace \
  barichello/godot-ci:4.3 \
  godot --headless --path /workspace --script "res://scripts/qa/godot_qa_runner.gd" 2>&1)
QA_EXIT=$?
set -e

# Filter known noisy dummy-renderer mesh warnings in headless mode.
echo "$QA_OUTPUT" | rg -v 'mesh_get_surface_count|Parameter "m" is null\.' || true

echo "[3/3] Latest report files:"
echo "- $ROOT_DIR/docs/reports/qa_latest.md"
echo "- $ROOT_DIR/docs/reports/qa_latest.json"

exit $QA_EXIT
