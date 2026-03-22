# Celadora v0.1 Architecture

## Runtime Graph
- `Main.tscn` composes `World`, `Player`, and `HUD`.
- `GameServices` autoload wires all gameplay services.
- World simulation scripts own generation, resources, day/night, moons, and ambient events.
- HUD includes objective progression, objective checklist panel, compass bearings, lore-marker navigation status, target status, debug overlay, and combat hit feedback so loops stay legible without opening panels.
- Objective progression is latched and persisted via `world_state` flags (`objective_*_complete`) so consumable crafting ingredients do not regress completed milestones.

## Services
- `DataService`: loads JSON definitions from `/data` and validates required Celadora contracts at boot.
- `EventLogService`: captures structured client-side gameplay events and serializes them for analysis/migration.
- `InventoryService`: item quantities, Celador Credits, passive modifier aggregation.
- `CraftingService`: recipe validation/consumption/outputs.
- `SaveService`: local JSON persistence (`user://savegame_v01.json`).
- `LoreJournalService`: unlock tracking for location-based lore entries.
- `MarketplaceService`: local listing simulation with provider seam for server authority.
- `AuthorityService`: merges local save/runtime state with authoritative snapshots and routes reward/crafting/market mutations.
- `AuthorityService` also syncs the runtime resource catalog and requires authority approval before depleted nodes grant rewards.
- `AuthorityService` now also settles enemy defeat rewards against canonical enemy definitions before a bot is removed locally.
- `NetworkService`: stable transport contract for authority calls.
- `LocalNetworkService`: in-process authoritative implementation used by default.
- `HttpNetworkService`: optional desktop transport for a local/external authority process.
- `NakamaNetworkService`: optional Nakama RPC transport that preserves the same authority contract.
- `GameServices.world_state`: lightweight persistent world flags (for example `ruins_terminal_primed`).

## Core Controllers
- `PlayerController`: movement, interaction ray, queued action-impact windows, manual save trigger.
- `ViewModelController`: first-person arms/hands/tool rendering, sway/bob/recoil/fatigue feedback, tool state visuals.
- `EnemyController`: patrol/aggro/attack lifecycle for Greegion Miner Bots.
- `WorldSpawner`: deterministic chunked block terrain + biome coloration.
- `WorldVisuals`: renderer-safe realism layer (procedural sky dome, animated water plane, day/night-driven shader params).
- `ResourceSpawner`: data-aware resource node placement with guaranteed starter pack near spawn.
- `DreamKeeperSpawner`: night-gated encounter scheduler with guaranteed first-night seed access path.
- `RuinsTerminal`: locked-door boss hook with requirement-aware priming state and save/load persistence.
- Browser QA seam: `Main` supports `?qa_objective_auto=1` to run deterministic objective-flow automation and publish a web QA payload for tooling.

## Data-Driven Contracts
All balance data is loaded at runtime:
- `data/items.json`
- `data/recipes.json`
- `data/enemies.json`
- `data/moons.json`
- `data/locations.json`
- `data/viewmodel.json`

Moon dust runtime identity is also data-driven via `items[].dust_profile`:
- `moon_id` binds dust color to the source moon definition.
- `shape` selects a unique mesh silhouette per moon dust.
- `gravity_scale`, `bounce`, `drag` drive dropped-particle terrain interaction.
- `glow_strength` controls emissive intensity from no glow to fully luminous.

## MMO Expansion Seams
- Replace `HttpNetworkService` endpoint targets with Nakama-backed RPC/storage calls while preserving service signatures.
- Keep `AuthorityService` as the single gameplay seam for reward claims, crafting requests, market orders, and state synchronization.
- Reward/pickup settlement now carries explicit `claim_id` values so the authority layer can reject duplicate claims.
- Move resource-claim validation, enemy state, and combat resolution server-side in later slices.
- Enemy defeat rewards are authoritative now, but enemy HP and hit validation remain client-simulated.
- Keep client as prediction/presentation layer while authority transitions to backend.
- Use `NetworkService.wrap_client_event(...)` envelopes as stable client-event contracts when routing through authoritative RPC pipelines.

## Authority Slice (Current)
- Authoritative today:
  - inventory mutations
  - Celador Credit settlement
  - crafting consumption/outputs
  - marketplace buy/sell settlement
- Not authoritative yet:
  - terrain/resource existence
  - enemy simulation and HP
  - movement/position validation
  - combat hit verification
- Optional server process:
  - `scripts/server/authority_server.mjs`
  - persisted local state: `artifacts/authority/state.local.json`
- Resource authority slice:
  - resource nodes get stable IDs from `ResourceSpawner`
  - `ResourceSpawner` syncs canonical resource definitions into authority
  - `PlayerController` requests `mine_resource` approval when a node depletes
  - authority approves the node and reward settlement is committed immediately through the same authority boundary
- Enemy authority slice:
  - enemy nodes get stable instance IDs from `EnemyController`
  - `EnemyController` submits `enemy_defeat` to authority on death
  - authority resolves canonical drops/credits and returns the updated economy snapshot
  - client then marks the bot defeated in `world_state`
- Optional Nakama provider:
  - `scripts/services/network/nakama_network_service.gd`
  - `nakama/modules/index.js`
  - integration notes: `docs/nakama_integration.md`

## Economy Safety Boundary
- `scripts/economy/token_bridge.gd` defines a disabled interface only.
- Token/real-money flows are intentionally disconnected from runtime gameplay in v0.1.
