extends Node

signal snapshot_applied(snapshot: Dictionary)

var _network_service: Node = null
var _inventory_service: Node = null
var _marketplace_service: Node = null
var _lore_service: Node = null
var _save_service: Node = null
var _world_state_provider: Node = null

var _connected: bool = false
var _mode: String = "local"
var _session_id: String = ""
var _last_snapshot: Dictionary = {}

func setup(
	network_service: Node,
	inventory_service: Node,
	marketplace_service: Node,
	lore_service: Node,
	save_service: Node,
	world_state_provider: Node
) -> void:
	_network_service = network_service
	_inventory_service = inventory_service
	_marketplace_service = marketplace_service
	_lore_service = lore_service
	_save_service = save_service
	_world_state_provider = world_state_provider

func connect_and_bootstrap(profile: Dictionary, local_state: Dictionary) -> Dictionary:
	var response: Dictionary = _network_service.connect_player(profile)
	if not response.get("ok", false):
		return response

	_connected = true
	var payload: Dictionary = response.get("data", {})
	_mode = str(payload.get("mode", "local"))
	_session_id = str(payload.get("session_id", ""))

	var state_present: bool = bool(payload.get("state_present", false))
	var resolved_state: Dictionary = local_state.duplicate(true)
	if state_present:
		var snapshot: Dictionary = payload.get("snapshot", {})
		resolved_state = _merge_state(local_state, snapshot)
		_apply_state(resolved_state)
		return {
			"ok": true,
			"error": "",
			"data": {
				"mode": _mode,
				"session_id": _session_id,
				"resolved_state": resolved_state
			}
		}

	var bootstrap_result: Dictionary = sync_state(local_state, true)
	if bootstrap_result.get("ok", false):
		resolved_state = bootstrap_result.get("data", {}).get("resolved_state", local_state).duplicate(true)
		return {
			"ok": true,
			"error": "",
			"data": {
				"mode": _mode,
				"session_id": _session_id,
				"resolved_state": resolved_state
			}
		}

	return bootstrap_result

func sync_state(local_state: Dictionary, force_bootstrap: bool = false) -> Dictionary:
	if not _connected:
		return {"ok": false, "error": "Authority service is not connected.", "data": {}}

	var payload: Dictionary = {
		"session_id": _session_id,
		"force_bootstrap": force_bootstrap,
		"state": local_state.duplicate(true)
	}
	var response: Dictionary = _network_service.sync_player_state(payload)
	if not response.get("ok", false):
		return response

	var snapshot: Dictionary = response.get("data", {}).get("snapshot", {})
	var resolved_state: Dictionary = _merge_state(local_state, snapshot)
	_apply_state(resolved_state)
	return {"ok": true, "error": "", "data": {"resolved_state": resolved_state}}

func claim_reward(item_id: String, quantity: int = 0, credits: int = 0, source: String = "", metadata: Dictionary = {}) -> Dictionary:
	if not _connected:
		return {"ok": false, "reason": "Authority service is not connected."}
	var claim_id: String = str(metadata.get("claim_id", "")).strip_edges()
	var response: Dictionary = _network_service.submit_reward_claim({
		"session_id": _session_id,
		"claim_id": claim_id,
		"item_id": item_id,
		"quantity": quantity,
		"credits": credits,
		"source": source,
		"metadata": metadata.duplicate(true)
	})
	if not response.get("ok", false):
		return {"ok": false, "reason": str(response.get("error", "Reward claim failed."))}

	var snapshot: Dictionary = response.get("data", {}).get("snapshot", {})
	_apply_snapshot(snapshot)
	var final_credits: int = int(response.get("data", {}).get("granted_credits", 0))
	var reason: String = "Reward granted."
	if not item_id.is_empty():
		reason = "Received %s x%d" % [item_id, max(quantity, 1)]
	GameServices.log_event("authority.reward_claimed", {
		"item_id": item_id,
		"quantity": quantity,
		"credits": final_credits,
		"source": source
	})
	return {
		"ok": true,
		"reason": reason,
		"credits": final_credits
	}

func craft_recipe(recipe_id: String) -> Dictionary:
	if not _connected:
		return {"ok": false, "reason": "Authority service is not connected."}
	var response: Dictionary = _network_service.submit_craft_request({
		"session_id": _session_id,
		"recipe_id": recipe_id
	})
	if not response.get("ok", false):
		return {"ok": false, "reason": str(response.get("error", "Craft failed."))}

	var payload: Dictionary = response.get("data", {})
	_apply_snapshot(payload.get("snapshot", {}))
	var outputs: Dictionary = payload.get("outputs", {})
	GameServices.log_event("crafting.recipe_crafted", {
		"recipe_id": recipe_id,
		"outputs": outputs
	})
	return {
		"ok": true,
		"reason": "Crafted %s" % str(payload.get("recipe_name", recipe_id)),
		"outputs": outputs.duplicate(true)
	}

func refresh_market() -> Dictionary:
	if not _connected:
		return {"ok": false, "reason": "Authority service is not connected."}
	var response: Dictionary = _network_service.fetch_market_listings()
	if not response.get("ok", false):
		return {"ok": false, "reason": str(response.get("error", "Market refresh failed."))}
	var payload: Dictionary = response.get("data", {})
	_apply_snapshot(payload.get("snapshot", {}))
	return {
		"ok": true,
		"reason": "Listings refreshed.",
		"listings": payload.get("listings", []).duplicate(true)
	}

func buy_listing(listing_id: String, quantity: int) -> Dictionary:
	if not _connected:
		return {"ok": false, "reason": "Authority service is not connected."}
	var response: Dictionary = _network_service.submit_market_order({
		"session_id": _session_id,
		"action": "buy",
		"listing_id": listing_id,
		"quantity": quantity
	})
	if not response.get("ok", false):
		return {"ok": false, "reason": str(response.get("error", "Buy failed."))}
	var payload: Dictionary = response.get("data", {})
	_apply_snapshot(payload.get("snapshot", {}))
	GameServices.log_event("market.buy", {
		"listing_id": listing_id,
		"quantity": quantity
	})
	return {
		"ok": true,
		"reason": str(payload.get("reason", "Purchase complete.")),
		"listing_id": listing_id
	}

func sell_item(item_id: String, quantity: int, unit_price: int) -> Dictionary:
	if not _connected:
		return {"ok": false, "reason": "Authority service is not connected."}
	var response: Dictionary = _network_service.submit_market_order({
		"session_id": _session_id,
		"action": "sell",
		"item_id": item_id,
		"quantity": quantity,
		"unit_price": unit_price,
		"seller": "Player"
	})
	if not response.get("ok", false):
		return {"ok": false, "reason": str(response.get("error", "Sell failed."))}
	var payload: Dictionary = response.get("data", {})
	_apply_snapshot(payload.get("snapshot", {}))
	GameServices.log_event("market.sell", {
		"item_id": item_id,
		"quantity": quantity,
		"unit_price": unit_price
	})
	return {
		"ok": true,
		"reason": str(payload.get("reason", "Listing created.")),
		"listing": payload.get("listing", {}).duplicate(true)
	}

func get_last_snapshot() -> Dictionary:
	return _last_snapshot.duplicate(true)

func is_authority_connected() -> bool:
	return _connected

func get_mode() -> String:
	return _mode

func _apply_state(state: Dictionary) -> void:
	_last_snapshot = {
		"inventory": state.get("inventory", {}).duplicate(true),
		"credits": int(state.get("credits", 0)),
		"marketplace": state.get("marketplace", {}).duplicate(true),
		"player_state": state.get("player_state", {}).duplicate(true),
		"world_state": state.get("world_state", {}).duplicate(true),
		"unlocked_lore": state.get("unlocked_lore", []).duplicate(true),
		"timestamp": str(state.get("timestamp", ""))
	}
	if _inventory_service != null:
		_inventory_service.set_inventory(state.get("inventory", {}))
		_inventory_service.set_credits(int(state.get("credits", 0)))
	if _marketplace_service != null and _marketplace_service.has_method("apply_authoritative_state"):
		_marketplace_service.apply_authoritative_state(state.get("marketplace", {}))
	if _lore_service != null:
		_lore_service.set_unlocked_ids(state.get("unlocked_lore", []))
	if _world_state_provider != null and _world_state_provider.has_method("set_world_state"):
		_world_state_provider.set_world_state(state.get("world_state", {}))
	if _save_service != null and _save_service.has_method("replace_loaded_state"):
		_save_service.replace_loaded_state(state, false)
	snapshot_applied.emit(_last_snapshot.duplicate(true))

func _apply_snapshot(snapshot: Dictionary) -> void:
	if typeof(snapshot) != TYPE_DICTIONARY:
		return
	var base_state: Dictionary = _build_runtime_state()
	_apply_state(_merge_state(base_state, snapshot))

func _merge_state(local_state: Dictionary, snapshot: Dictionary) -> Dictionary:
	var merged: Dictionary = {}
	if _save_service != null and _save_service.has_method("normalize_state_for_load"):
		merged = _save_service.normalize_state_for_load(local_state)
	else:
		merged = local_state.duplicate(true)

	if typeof(snapshot) != TYPE_DICTIONARY:
		return merged
	if snapshot.has("inventory"):
		merged["inventory"] = (snapshot.get("inventory", {}) as Dictionary).duplicate(true)
	if snapshot.has("credits"):
		merged["credits"] = int(snapshot.get("credits", 0))
	if snapshot.has("marketplace"):
		merged["marketplace"] = (snapshot.get("marketplace", {}) as Dictionary).duplicate(true)
	if snapshot.has("player_state") and typeof(snapshot.get("player_state")) == TYPE_DICTIONARY and not (snapshot.get("player_state") as Dictionary).is_empty():
		merged["player_state"] = (snapshot.get("player_state", {}) as Dictionary).duplicate(true)
	if snapshot.has("world_state"):
		merged["world_state"] = (snapshot.get("world_state", {}) as Dictionary).duplicate(true)
	if snapshot.has("unlocked_lore"):
		merged["unlocked_lore"] = (snapshot.get("unlocked_lore", []) as Array).duplicate(true)
	if snapshot.has("timestamp"):
		merged["timestamp"] = str(snapshot.get("timestamp", ""))

	if _save_service != null and _save_service.has_method("normalize_state_for_load"):
		return _save_service.normalize_state_for_load(merged)
	return merged

func _build_runtime_state() -> Dictionary:
	var state: Dictionary = _save_service.get_loaded_state() if _save_service != null else {}
	if _inventory_service != null:
		state["inventory"] = _inventory_service.get_all_items()
		state["credits"] = _inventory_service.credits
	if _marketplace_service != null and _marketplace_service.has_method("serialize_state"):
		state["marketplace"] = _marketplace_service.serialize_state()
	if _lore_service != null and _lore_service.has_method("get_unlocked_ids"):
		state["unlocked_lore"] = _lore_service.get_unlocked_ids()
	if _world_state_provider != null and _world_state_provider.has_method("get_world_state"):
		state["world_state"] = _world_state_provider.get_world_state()
	if _save_service != null and _save_service.has_method("normalize_state_for_load"):
		return _save_service.normalize_state_for_load(state)
	return state
