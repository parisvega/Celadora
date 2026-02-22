# Celadora (Godot 4.3) - v0.1 Vertical Slice

Celadora is an open-source sci-fi fantasy RPG prototype built in Godot 4.3. This release is a playable single-player vertical slice designed with service seams for future MMO networking.

## Requirements
- Godot Engine `4.3` (stable)
- Desktop platform (tested design target: keyboard + mouse)

## Run Locally
1. Open Godot 4.3.
2. Import project from:
   - `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/project.godot`
3. Click **Run Project** (`F5`).

## Build / Export
1. In Godot, open **Project > Export**.
2. Add your target preset (Windows/macOS/Linux).
3. Export using default settings (no external binary dependency required for v0.1).

## Controls
- `W/A/S/D`: Move
- `Shift`: Run
- `Space`: Jump
- `Mouse`: Look
- `Left Click`: Primary action (mine/attack)
- `E`: Interact (terminals and interactables)
- `I`: Toggle Inventory
- `O`: Toggle Objective Checklist
- `C`: Toggle Crafting
- `J`: Toggle Lore Journal
- `M`: Toggle Marketplace
- `F5`: Manual save
- `F8`: Skip day/night phase (dev/test convenience)
- `F9`: Reset local progress (save + inventory + lore + market state)
- `F3`: Toggle debug overlay (FPS/position/biome/objective/dream status)
- `Esc`: Toggle mouse capture

HUD notes:
- Top row: compass and marker bearings
- Bottom row 1: current objective progression
- Bottom row 2: world status (day/night, biome, Dream Keeper window, next lore marker direction/distance)
- Bottom row 3: contextual interaction hint (mine/attack/interact target)
- Center status line: current target integrity/HP
- Bottom row 4: system controls (inventory/crafting/lore/market/interact/save/reset)
- Bottom row 5: movement controls
- Hit feedback: lightweight red flash when taking damage

## Gameplay Loop in v0.1
- Spawn on Celadora with eight visible moons.
- Mine dust fragments and energy crystals.
- Fight Greegion Miner Bots.
- Craft `Celadora Alloy` and `Moonblade (Prototype)`.
- Unlock lore entries at Enok's Kingdom Ridge, Makuna's Shore, and Greegion Ruins.
- Encounter rare Dream Keepers at night for `Dream Seed` drops.
- Use local marketplace listings with Celador Credits.

Objective reliability notes:
- Starter resource cache now spawns near the initial area (multiple dust types + energy crystals).
- Dream Keeper now guarantees at least one night encounter after a short delay if you still need a `Dream Seed`.
- Lore markers now use taller pulsing beacons and switch to completion tint once unlocked.
- Marketplace includes `Quick Sell Bot Scrap` for faster early-economy flow.
- Event log service records key gameplay actions for future server-authoritative migration.

## Data-Driven Balancing
All game data is editable JSON under `/data` and loaded at runtime.
Runtime validation enforces required Celadora IDs, moon count/type coverage, and core recipe/enemy/location contracts.

### Add a New Dust Type or Item
1. Add a new object in `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/data/items.json`.
2. Provide fields:
   - `id`, `name`, `category`, `tags`, `stackable`, `max_stack`, `base_value`, `description`, `modifier`
3. If it is dust, include `"dust"` in `tags` to make crafting rules discover it.

### Add a New Recipe
1. Add recipe object to `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/data/recipes.json`.
2. Set `ingredients`, optional `special`, and `outputs` maps.
3. Crafting UI reads this file automatically on startup.

### Add/Balance Enemies
- Edit `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/data/enemies.json`.
- Tune HP, speed, aggro, damage, and drop values.

### Expand World Size/Biomes
- Edit exported values in `WorldSpawner` node inside `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/scenes/world/World.tscn`:
  - `world_radius_tiles`
  - `tile_size`
  - `height_scale`
- Biome thresholds are in `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/scripts/world/world_spawner.gd`.

## Architecture Summary
- Autoload singleton: `GameServices`
- Modular services: inventory, crafting, save, lore, marketplace, network stub.
- Provider seam: `NetworkService` interface + `LocalNetworkService` implementation.
- Economy isolation: disabled `TokenBridge` stubs in `/scripts/economy`.

## Developer Shortcuts (DX)
- One-command validate+export+preview+open:
  - `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/scripts/dev/quick_preview.sh 8060`
- Export Web quickly:
  - `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/scripts/dev/export_web.sh`
- Start local Web preview:
  - `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/scripts/dev/run_web_preview.sh 8060`
- Stop local Web preview:
  - `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/scripts/dev/stop_web_preview.sh`
- Run smoke checks:
  - `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/scripts/dev/smoke_check.sh`

## AI Agent Workflow (AX)
- See:
  - `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/docs/agent_playbook.md`
- It defines UX/DX/AX priorities, safe iteration checklist, and command sequence for future agent contributions.

## Next Milestones
1. **Dedicated server foundation**
   - Move simulation authority for inventory/combat/economy to a backend process.
2. **Nakama integration**
   - Implement `NetworkService` methods against Nakama RPC/storage APIs.
   - Add session/auth bootstrap and matchmaking hooks.
3. **MMO shard/instance strategy**
   - Hybrid model: region shards + instanced high-load zones.
   - Cross-shard travel services and state handoff.
4. **Authoritative economy + anti-cheat**
   - Server-side validation for resource drops, trades, and crafting outputs.
   - Event audit logs, anomaly detection, anti-duplication protections.
5. **Content roadmap**
   - Eight-moon travel loop.
   - Moon Sword questline progression.
   - Dream Keepers narrative arc.
   - Shadow King threat arc and late-game dungeon activation.

## License
MIT. See `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/LICENSE`.
