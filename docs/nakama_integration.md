# Nakama Integration Notes

Celadora v0.1 does not require Nakama to run. The Nakama path exists so the current authority slice can be replaced incrementally instead of rewriting gameplay services later.

## Current Client Seam
- Provider selector:
  - `CELADORA_NETWORK_PROVIDER=nakama`
  - or set `CELADORA_NAKAMA_URL`
- Client transport:
  - `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/scripts/services/network/nakama_network_service.gd`
- Shared gameplay seam:
  - `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/scripts/services/authority_service.gd`

## Current RPC Contract
- `celadora_connect`
- `celadora_sync_player_state`
- `celadora_fetch_market_listings`
- `celadora_submit_market_order`
- `celadora_submit_reward_claim`
- `celadora_submit_craft_request`
- `celadora_submit_combat_event`
- `celadora_sync_resource_catalog`
- `celadora_submit_resource_mine`

These RPCs map to the same transport contract already used by `LocalNetworkService` and `HttpNetworkService`.

## Current Runtime Module
- `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/nakama/modules/index.js`

It persists one authority record per user in Nakama storage and currently governs:
- inventory mutations
- Celador Credit settlement
- resource catalog registration
- resource mine approval + duplicate prevention
- crafting validation and output grants
- marketplace buy/sell settlement
- reward claim de-duplication
- combat event audit logging

## Not Yet Authoritative
- terrain/resource existence
- enemy simulation and HP
- combat hit verification
- movement/session anti-cheat
- shard or match orchestration

## Integration Order
1. Stand up a local Nakama instance with JavaScript runtime enabled.
2. Install the module at `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/nakama/modules/index.js`.
3. Point the client at Nakama with `CELADORA_NETWORK_PROVIDER=nakama`.
4. Validate bootstrap, resource mine, reward claim, craft, and market flows.
5. Move enemy death, loot generation, and combat resolution server-side.
6. Add session identity, party presence, shard routing, and match/zone authority.

## Design Constraint
Do not bypass `AuthorityService` from gameplay code. As MMO features expand, that boundary is what prevents a rewrite of player systems, crafting, marketplace, and progression flows.
