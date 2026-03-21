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

## Optional Authority Mode
Celadora still runs fully offline by default, but inventory/credits/crafting/marketplace can now be exercised through an optional local authority server.

1. Start the local authority server in a normal terminal:
   - `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/scripts/dev/run_authority_server.sh 8787`
2. Launch Godot from the same terminal with:
   - `CELADORA_AUTHORITY_URL=http://127.0.0.1:8787 godot4 --path '/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora'`
3. Stop the authority server when done:
   - `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/scripts/dev/stop_authority_server.sh`

Authority scope in this slice:
- authoritative now: inventory, Celador Credits, crafting outputs, market settlement, resource reward reservation/duplicate prevention
- still client-simulated: world terrain/resources, enemy simulation, combat hit validation, movement

## Optional Nakama Provider
Celadora also includes a Nakama-ready transport and runtime module skeleton so the current authority contract can move to RPC/storage without changing gameplay services.

Client-side provider selection:
- `CELADORA_NETWORK_PROVIDER=nakama`
- `CELADORA_NAKAMA_URL=http://127.0.0.1:7350`
- optional:
  - `CELADORA_NAKAMA_SERVER_KEY=defaultkey`
  - `CELADORA_NAKAMA_DEVICE_ID=your-device-id`
  - `CELADORA_NAKAMA_USERNAME=Local Pioneer`

Current Nakama artifacts:
- client transport:
  - `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/scripts/services/network/nakama_network_service.gd`
- server runtime module:
  - `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/nakama/modules/index.js`

Nakama scope today:
- mirrors the current authority slice for:
  - connect/bootstrap
  - state sync
  - resource catalog sync
  - resource mining approval
  - reward claims
  - crafting
  - marketplace settlement
  - combat event logging
- remains optional and is not required for v0.1 runtime
- does not yet include matchmaking, shard orchestration, enemy/server combat resolution, or movement/session validation

## Controls
- `W/A/S/D`: Move
- `Shift`: Run
- `Space`: Jump
- `Mouse`: Look
- `Left Click`: Swing equipped first-person tool (mine/attack resolves on impact window)
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
- `F1`: Pin/unpin HUD controls help card
- `Esc`: Toggle mouse capture

HUD notes:
- HUD is now peripheral-first to keep the center view clear during exploration/combat.
- Top center: compact compass + nearest lore marker direction/distance.
- Top right: objective state and route guidance.
- Top left: transient system message toast.
- Bottom left: vitals bars + credits.
- Bottom center: contextual interaction hint (only shown when relevant).
- Bottom right: target status card + optional controls help card (`F1`).
- First-person viewmodel: arms, hands, and active tool are visible; crafted `Moonblade (Prototype)` auto-equips visually
- Completion debrief panel appears at the right side when all v0.1 objectives are done, with run summary stats
- Controls help card auto-hides shortly after spawn; pin it with `F1` when needed
- Hit feedback: lightweight red flash when taking damage

## Gameplay Loop in v0.1
- Spawn on Celadora with eight visible moons.
- First-person embodiment: visible arms/hands/tool with motion sway, bob, fatigue shake, and hit kick.
- Mine dust fragments and energy crystals.
- Moon dust identity loop:
  - each dust type now matches its moon color exactly,
  - each moon dust has a unique particle geometry,
  - each moon dust has distinct gravity/bounce/drag in-world behavior when dropped.
- Glow spectrum:
  - dust glow is data-driven per type (`0.0` no glow -> `1.0` fully luminous).
- Rarity power curve:
  - rarer dust tiers include extra “exotic” stat hooks (for example `critical_chance`, `gravity_resistance`, `jump_boost`).
- Fight Greegion Miner Bots.
- Craft `Celadora Alloy` and `Moonblade (Prototype)`.
- Unlock lore entries at Enok's Kingdom Ridge, Makuna's Shore, and Greegion Ruins.
- Encounter rare Dream Keepers at night for `Dream Seed` drops.
- Prime the locked Greegion Ruins terminal after meeting requirements (Moonblade + Dream Seed + lore unlocks).
- Use local marketplace listings with Celador Credits.

Objective reliability notes:
- Starter resource cache now spawns near the initial area (multiple dust types + energy crystals).
- Starter fast-path was tuned further: denser starter cache and tighter spawn radius for early crafting momentum.
- Dream Keeper now guarantees at least one night encounter after a short delay if you still need a `Dream Seed`.
- Lore markers now use taller pulsing beacons and switch to completion tint once unlocked.
- Ruins terminal now exposes clear missing-requirements messaging and a primed future-boss hook state.
- Marketplace includes `Quick Sell Bot Scrap` for faster early-economy flow.
- Event log service records key gameplay actions for future server-authoritative migration.
- Objectives are now latched and persisted via `world_state` flags so completed milestones stay complete.
- Save service now uses schema migration (`schema_version`) and normalizes legacy saves into current objective/world-state flags.
- Lore marker beacons now highlight the nearest unfinished marker to reinforce route clarity.

## Data-Driven Balancing
All game data is editable JSON under `/data` and loaded at runtime.
Runtime validation enforces required Celadora IDs, moon count/type coverage, and core recipe/enemy/location contracts.
First-person viewmodel tuning is also JSON-driven via `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/data/viewmodel.json`.

### Add a New Dust Type or Item
1. Add a new object in `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/data/items.json`.
2. Provide fields:
   - `id`, `name`, `category`, `tags`, `stackable`, `max_stack`, `base_value`, `description`, `modifier`
3. If it is dust, include `"dust"` in `tags` to make crafting rules discover it.
4. For moon dust, include a `dust_profile` object with:
   - `moon_id`, `shape`, `gravity_scale`, `bounce`, `drag`, `glow_strength`, `rarity`
5. Keep `dust_profile.shape` unique per moon dust type so each particle silhouette is distinct.
6. Set `glow_strength` in the `0.0` to `1.0` range to control emissive intensity.

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

### Tune First-Person Arms/Tool Feel
1. Edit `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/data/viewmodel.json`.
2. Tune:
   - `base_transform`: camera-relative position/rotation for arms/tool.
   - `sway`, `bob`, `fatigue`: movement feel and stamina feedback.
   - `actions.mine` and `actions.attack`: duration + impact timing windows.
   - `tools.states`: per-tool offsets/colors for `miner` and `moonblade`.
3. Re-run preview:
   - `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/scripts/dev/quick_preview.sh 8060`

## Visual Realism Toolkit (Open Source)
- Integrated now (no external assets required):
  - Procedural terrain shader:
    - `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/assets/shaders/terrain_biome.gdshader`
  - Water shader:
    - `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/assets/shaders/celadora_water.gdshader`
  - Sky dome shader:
    - `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/assets/shaders/celadora_skydome.gdshader`
  - Runtime world visuals controller:
    - `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/scripts/world/world_visuals.gd`
- Recommended external OSS stack:
  - [Material Maker](https://github.com/RodZill4/material-maker) (MIT)
  - [Poly Haven](https://polyhaven.com/license) (CC0)
  - [ambientCG](https://ambientcg.com/index.php) (CC0)
  - [Sky3D](https://github.com/TokisanGames/Sky3D) (MIT, optional)
  - [Godot SSR Water](https://github.com/marcelb/GodotSSRWater) (MIT, optional)
  - [godot_spatial_gardener](https://github.com/dreadpon/godot_spatial_gardener) (MIT, optional)
  - [Basis Universal](https://github.com/BinomialLLC/basis_universal) (Apache-2.0, optional texture compression)
- Detailed integration notes:
  - `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/docs/realism_stack.md`
- Renderer note:
  - Web preview currently uses `compatibility` renderer for reliability. Keep this for browser builds; evaluate a separate desktop Forward+ profile when adding heavier visual plugins.

## Architecture Summary
- Autoload singleton: `GameServices`
- Modular services: inventory, crafting, save, lore, marketplace, authority, network.
- Provider seam: `NetworkService` interface + `LocalNetworkService` / `HttpNetworkService` implementations.
- `AuthorityService` now owns the handoff between local runtime state and authoritative inventory/credits/marketplace mutation flows.
- Resource mining now syncs a canonical resource catalog into the authority layer, and depleted nodes must be approved there before rewards are granted.
- Reward claims now carry claim IDs so pickup settlement can be rejected when the same drop is claimed twice.
- Persistent world progression seam: `GameServices.world_state` (used by ruins-terminal state and future world flags).
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
- Run local authority HTTP smoke:
  - `node /Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/scripts/server/authority_smoke.mjs`
- Start the optional local authority server directly with Node:
  - `node /Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/scripts/server/authority_server.mjs`
- Check Nakama runtime module syntax locally:
  - `node --check /Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/nakama/modules/index.js`
- Run automated QA agent (headless + report files):
  - `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/scripts/qa/run_qa_agent.sh`
  - Outputs:
    - `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/docs/reports/qa_latest.md`
    - `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/docs/reports/qa_latest.json`
    - `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/docs/reports/qa_browser_objective_latest.json`
    - `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/docs/reports/qa_combined_latest.md`
- Build combined QA snapshot report only:
  - `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/scripts/qa/build_combined_report.sh`
- Run browser objective-flow QA directly:
  - `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/scripts/qa/run_browser_objective_qa.sh 8060`
  - Notes:
    - Uses Playwright via local Node tooling (`package.json`).
    - Marks result `inconclusive` when headless browser lacks WebGL2 support.
    - Includes a first-person viewmodel visibility gate (arms/hands/tool projected in viewport).
- Run v0.1 goal audit report:
  - `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/scripts/dev/goal_check.sh`
  - Output:
    - `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/docs/reports/goals_status_latest.md`

## AI Agent Workflow (AX)
- See:
  - `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/docs/agent_playbook.md`
- It defines UX/DX/AX priorities, safe iteration checklist, and command sequence for future agent contributions.
- Balancing telemetry:
  - Debug overlay (`F3`) now includes spawn telemetry (resource/enemy/pickup counts + nearest distances), resource mix summary, and fast-path milestone timers.

## Next Milestones
1. **Dedicated server foundation**
   - Expand the authority slice from inventory/resources into enemy state, combat rewards, and player session state.
2. **Nakama integration**
   - Replace `HttpNetworkService` endpoint targets with Nakama RPC/storage APIs.
   - Add session/auth bootstrap, account identity, and matchmaking hooks.
3. **MMO shard/instance strategy**
   - Hybrid model: region shards + instanced high-load zones.
   - Cross-shard travel services and state handoff.
4. **Authoritative economy + anti-cheat**
   - Server-side validation for resource existence, drop claims, trades, and crafting outputs.
   - Event audit logs, anomaly detection, anti-duplication protections, and transaction reconciliation.
5. **Content roadmap**
   - Eight-moon travel loop.
   - Moon Sword questline progression.
   - Dream Keepers narrative arc.
   - Shadow King threat arc and late-game dungeon activation.

## License
MIT. See `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/LICENSE`.
