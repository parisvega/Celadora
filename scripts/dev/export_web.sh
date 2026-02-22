#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

mkdir -p build/web

# Requires Docker + barichello/godot-ci image access.
docker run --rm --platform linux/amd64 \
  -v "$PWD":/workspace \
  -w /workspace \
  barichello/godot-ci:4.3 \
  godot --headless --export-release "Web" build/web/index.html

echo "Web export complete: $ROOT_DIR/build/web/index.html"
