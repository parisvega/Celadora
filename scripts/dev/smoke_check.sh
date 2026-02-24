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

jq -e --slurpfile moons data/moons.json '
  def baseline($id):
    if $id == "dust_blue" then ["stamina_regen"]
    elif $id == "dust_green" then ["health_regen"]
    elif $id == "dust_red" then ["damage_bonus"]
    elif $id == "dust_orange" then ["mining_speed"]
    elif $id == "dust_yellow" then ["move_speed"]
    elif $id == "dust_white" then ["shield_regen"]
    elif $id == "dust_black" then ["aggro_radius_multiplier"]
    elif $id == "dust_silver" then ["credit_gain_multiplier"]
    else [] end;
  def exotic_min($rarity):
    if $rarity == "common" then 0
    elif $rarity == "uncommon" then 1
    elif $rarity == "rare" then 1
    elif $rarity == "epic" then 2
    elif $rarity == "legendary" then 3
    else 999 end;
  (map(select(.id | startswith("dust_"))) as $dusts |
    ($dusts | length) == 8 and
    ($dusts | all(.dust_profile != null and
      (.dust_profile.shape | type == "string") and
      (.dust_profile.moon_id | type == "string") and
      (.dust_profile.gravity_scale | type == "number") and
      (.dust_profile.glow_strength | type == "number") and
      (.dust_profile.rarity | type == "string")
    )) and
    (($dusts | map(.dust_profile.shape) | unique | length) == 8) and
    ($dusts | all((.dust_profile.glow_strength >= 0.0) and (.dust_profile.glow_strength <= 1.0))) and
    (($dusts | map(.dust_profile.glow_strength) | min) == 0.0) and
    (($dusts | map(.dust_profile.glow_strength) | max) == 1.0) and
    ($dusts | all(.dust_profile.moon_id as $mid | ($moons[0] | map(.id) | index($mid) != null))) and
    ($dusts | all(
      . as $item |
      ($item.id | sub("^dust_"; "")) as $expected_dust |
      (($moons[0] | map(select(.id == $item.dust_profile.moon_id)) | .[0].dust_type | ascii_downcase) == $expected_dust)
    )) and
    ($dusts | all(
      . as $item |
      (.dust_profile.rarity | ascii_downcase) as $rarity |
      ((($item.modifier // {}) | keys_unsorted - baseline($item.id) | length) >= exotic_min($rarity))
    ))
  )
' data/items.json >/dev/null || {
  echo "Dust profiles must define unique shapes, moon mapping, full glow spectrum, and rarity-based exotic modifiers."
  exit 1
}

echo "[3/4] Checking required files..."
required=(
  project.godot
  data/viewmodel.json
  scenes/Main.tscn
  scenes/world/World.tscn
  scenes/player/Player.tscn
  scenes/player/ViewModelRig.tscn
  scenes/player/ViewTool_Miner.tscn
  scenes/ui/HUD.tscn
  scenes/ui/ObjectivePanel.tscn
  assets/shaders/terrain_biome.gdshader
  assets/shaders/celadora_water.gdshader
  assets/shaders/celadora_skydome.gdshader
  scripts/resources/dust_shape_library.gd
  scripts/services/game_services.gd
  scripts/services/event_log_service.gd
  scripts/controllers/player_controller.gd
  scripts/controllers/viewmodel_controller.gd
  scripts/controllers/enemy_controller.gd
  scripts/world/world_visuals.gd
  docs/realism_stack.md
)
for f in "${required[@]}"; do
  test -f "$f" || { echo "Missing required file: $f"; exit 1; }
done

echo "[4/4] Checking res:// reference targets..."
while IFS= read -r path; do
  rel="${path#res://}"
  test -e "$rel" || { echo "Missing target: $path"; exit 1; }
done < <(rg --no-filename -o "res://[^\"' ]+" \
  -g "*.godot" -g "*.tscn" -g "*.gd" \
  project.godot scenes scripts | sort -u)

echo "Smoke check passed."
