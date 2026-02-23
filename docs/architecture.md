# Celadora v0.1 Architecture

## Runtime Graph
- `Main.tscn` composes `World`, `Player`, and `HUD`.
- `GameServices` autoload wires all gameplay services.
- World simulation scripts own generation, resources, day/night, moons, and ambient events.
- HUD includes objective progression, objective checklist panel, compass bearings, lore-marker navigation status, target status, debug overlay, and combat hit feedback so loops stay legible without opening panels.

## Services
- `DataService`: loads JSON definitions from `/data` and validates required Celadora contracts at boot.
- `EventLogService`: captures structured client-side gameplay events and serializes them for analysis/migration.
- `InventoryService`: item quantities, Celador Credits, passive modifier aggregation.
- `CraftingService`: recipe validation/consumption/outputs.
- `SaveService`: local JSON persistence (`user://savegame_v01.json`).
- `LoreJournalService`: unlock tracking for location-based lore entries.
- `MarketplaceService`: local listing simulation with provider seam for server authority.
- `NetworkService` + `LocalNetworkService`: future MMO/Nakama insertion point.
- `GameServices.world_state`: lightweight persistent world flags (for example `ruins_terminal_primed`).

## Core Controllers
- `PlayerController`: movement, interaction ray, queued action-impact windows, manual save trigger.
- `ViewModelController`: first-person arms/hands/tool rendering, sway/bob/recoil/fatigue feedback, tool state visuals.
- `EnemyController`: patrol/aggro/attack lifecycle for Greegion Miner Bots.
- `WorldSpawner`: deterministic chunked block terrain + biome coloration.
- `ResourceSpawner`: data-aware resource node placement with guaranteed starter pack near spawn.
- `DreamKeeperSpawner`: night-gated encounter scheduler with guaranteed first-night seed access path.
- `RuinsTerminal`: locked-door boss hook with requirement-aware priming state and save/load persistence.

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
- Replace `LocalNetworkService` with a Nakama-backed implementation while preserving service signatures.
- Move marketplace settlement, inventory mutation, and combat event validation server-side.
- Keep client as prediction/presentation layer while authority transitions to backend.
- Use `NetworkService.wrap_client_event(...)` envelopes as stable client-event contracts when routing through authoritative RPC pipelines.

## Economy Safety Boundary
- `scripts/economy/token_bridge.gd` defines a disabled interface only.
- Token/real-money flows are intentionally disconnected from runtime gameplay in v0.1.
