#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

echo "[1/4] Checking JSON syntax..."
for f in data/*.json; do
  jq empty "$f"
done

echo "[2/4] Validating required Celadora IDs and moon count..."
jq -e 'length == 8' data/moons.json >/dev/null || { echo "Expected exactly 8 moons"; exit 1; }

required_items=(
  dust_blue dust_green dust_red dust_orange dust_yellow dust_white dust_black dust_silver
  energy_crystal alloy moonblade_prototype dream_seed bot_scrap
)
for id in "${required_items[@]}"; do
  jq -e --arg id "$id" 'map(.id) | index($id) != null' data/items.json >/dev/null || { echo "Missing required item id: $id"; exit 1; }
done

required_recipes=(alloy_recipe moonblade_recipe)
for id in "${required_recipes[@]}"; do
  jq -e --arg id "$id" 'map(.id) | index($id) != null' data/recipes.json >/dev/null || { echo "Missing required recipe id: $id"; exit 1; }
done

required_locations=(enoks_kingdom_ridge makunas_shore greegion_ruins)
for id in "${required_locations[@]}"; do
  jq -e --arg id "$id" 'map(.id) | index($id) != null' data/locations.json >/dev/null || { echo "Missing required location id: $id"; exit 1; }
done

jq -e 'map(.dust_type) | sort == ["Black","Blue","Green","Orange","Red","Silver","White","Yellow"]' data/moons.json >/dev/null || {
  echo "Moon dust types must be exactly Blue/Green/Red/Orange/Yellow/White/Black/Silver"
  exit 1
}

echo "[3/4] Checking required files..."
required=(
  project.godot
  scenes/Main.tscn
  scenes/world/World.tscn
  scenes/player/Player.tscn
  scenes/ui/HUD.tscn
  scenes/ui/ObjectivePanel.tscn
  scripts/services/game_services.gd
  scripts/services/event_log_service.gd
  scripts/controllers/player_controller.gd
  scripts/controllers/enemy_controller.gd
)
for f in "${required[@]}"; do
  test -f "$f" || { echo "Missing required file: $f"; exit 1; }
done

echo "[4/4] Checking res:// reference targets..."
while IFS= read -r path; do
  rel="${path#res://}"
  test -f "$rel" || { echo "Missing target: $path"; exit 1; }
done < <(rg --no-filename -o "res://[^\"' ]+" \
  -g "*.godot" -g "*.tscn" -g "*.gd" \
  project.godot scenes scripts | sort -u)

echo "Smoke check passed."
