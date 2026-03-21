extends "res://scripts/services/network/network_service.gd"

var _connected: bool = false
var _data_service: Node = null
var _session_id: String = ""
var _state_present: bool = false
var _item_defs: Dictionary = {}
var _recipe_defs: Dictionary = {}
var _authoritative_state: Dictionary = {}
var _claimed_reward_ids: Dictionary = {}
var _resource_catalog: Dictionary = {}
var _mined_resource_ids: Dictionary = {}
var _reserved_reward_claims: Dictionary = {}

func setup(data_service: Node) -> void:
	_data_service = data_service
	_cache_catalog()
	_reset_authoritative_state(false)

func connect_player(profile: Dictionary) -> Dictionary:
	_connected = true
	if _session_id.is_empty():
		_session_id = "local_%d" % Time.get_unix_time_from_system()
	_ensure_market_seeded()
	return {
		"ok": true,
		"error": "",
		"data": {
			"profile": profile.duplicate(true),
			"mode": "local_authority",
			"session_id": _session_id,
			"state_present": _state_present,
			"snapshot": _snapshot()
		}
	}

func sync_player_state(payload: Dictionary) -> Dictionary:
	if not _connected:
		return {"ok": false, "error": "Not connected.", "data": {}}

	var state: Variant = payload.get("state", {})
	if typeof(state) != TYPE_DICTIONARY:
		return {"ok": false, "error": "State payload must be a dictionary.", "data": {}}

	var force_bootstrap: bool = bool(payload.get("force_bootstrap", false))
	if force_bootstrap or not _state_present:
		_apply_external_state(state as Dictionary)
	else:
		_merge_runtime_state(state as Dictionary)
	_state_present = true
	return {"ok": true, "error": "", "data": {"snapshot": _snapshot()}}

func fetch_market_listings() -> Dictionary:
	if not _connected:
		return {"ok": false, "error": "Not connected.", "data": {}}
	_ensure_market_seeded()
	return {
		"ok": true,
		"error": "",
		"data": {
			"listings": _authoritative_state.get("marketplace", {}).get("listings", []).duplicate(true),
			"snapshot": _economy_snapshot()
		}
	}

func submit_market_order(order: Dictionary) -> Dictionary:
	if not _connected:
		return {"ok": false, "error": "Not connected.", "data": {}}
	var action: String = str(order.get("action", "")).strip_edges().to_lower()
	match action:
		"buy":
			return _process_buy_order(order)
		"sell":
			return _process_sell_order(order)
		_:
			return {"ok": false, "error": "Unknown market action.", "data": {}}

func submit_combat_event(event_payload: Dictionary) -> Dictionary:
	if not _connected:
		return {"ok": false, "error": "Not connected.", "data": {}}
	return {"ok": true, "error": "", "data": event_payload.duplicate(true)}

func submit_reward_claim(claim: Dictionary) -> Dictionary:
	if not _connected:
		return {"ok": false, "error": "Not connected.", "data": {}}

	var item_id: String = str(claim.get("item_id", "")).strip_edges()
	var claim_id: String = str(claim.get("claim_id", "")).strip_edges()
	var quantity: int = max(0, int(claim.get("quantity", 0)))
	var base_credits: int = max(0, int(claim.get("credits", 0)))
	if not claim_id.is_empty() and _reserved_reward_claims.has(claim_id):
		var reserved: Dictionary = _reserved_reward_claims.get(claim_id, {})
		item_id = str(reserved.get("item_id", item_id)).strip_edges()
		quantity = max(0, int(reserved.get("quantity", quantity)))
		base_credits = max(0, int(reserved.get("credits", base_credits)))
	if item_id.is_empty() and base_credits <= 0:
		return {"ok": false, "error": "Reward claim must include an item or credits.", "data": {}}
	if not item_id.is_empty() and quantity <= 0:
		return {"ok": false, "error": "Reward claim quantity must be at least 1.", "data": {}}
	if not item_id.is_empty() and _item_defs.is_empty() == false and _item_defs.has(item_id) == false:
		return {"ok": false, "error": "Unknown item reward.", "data": {}}
	if not claim_id.is_empty():
		if _claimed_reward_ids.has(claim_id):
			return {"ok": false, "error": "Reward claim already consumed.", "data": {}}
		_claimed_reward_ids[claim_id] = true
		_reserved_reward_claims.erase(claim_id)

	if not item_id.is_empty():
		var inventory: Dictionary = _get_inventory_state()
		inventory[item_id] = int(inventory.get(item_id, 0)) + quantity
		_authoritative_state["inventory"] = inventory

	var final_credits: int = _apply_credit_gain(base_credits)
	return {
		"ok": true,
		"error": "",
		"data": {
			"granted_item_id": item_id,
			"granted_quantity": quantity,
			"granted_credits": final_credits,
			"snapshot": _economy_snapshot()
		}
	}

func submit_craft_request(request: Dictionary) -> Dictionary:
	if not _connected:
		return {"ok": false, "error": "Not connected.", "data": {}}

	var recipe_id: String = str(request.get("recipe_id", "")).strip_edges()
	var recipe: Dictionary = _recipe_defs.get(recipe_id, {})
	if recipe.is_empty():
		return {"ok": false, "error": "Unknown recipe.", "data": {}}

	var validation: Dictionary = _validate_recipe(recipe)
	if not validation.get("ok", false):
		return {"ok": false, "error": str(validation.get("reason", "Craft failed.")), "data": {}}

	var inventory: Dictionary = _get_inventory_state()
	var ingredients: Dictionary = recipe.get("ingredients", {})
	for item_id in ingredients.keys():
		var amount: int = int(ingredients.get(item_id, 0))
		inventory[item_id] = int(inventory.get(item_id, 0)) - amount
		if int(inventory[item_id]) <= 0:
			inventory.erase(item_id)

	var special: Dictionary = recipe.get("special", {})
	var distinct_dust_count: int = int(special.get("distinct_dust_count", 0))
	if distinct_dust_count > 0:
		var available_dust_ids: Array = _get_available_dust_ids(inventory)
		for i in range(min(distinct_dust_count, available_dust_ids.size())):
			var dust_item_id: String = str(available_dust_ids[i])
			inventory[dust_item_id] = int(inventory.get(dust_item_id, 0)) - 1
			if int(inventory[dust_item_id]) <= 0:
				inventory.erase(dust_item_id)

	var outputs: Dictionary = recipe.get("outputs", {})
	for out_item_id in outputs.keys():
		inventory[out_item_id] = int(inventory.get(out_item_id, 0)) + int(outputs.get(out_item_id, 0))

	_authoritative_state["inventory"] = inventory
	return {
		"ok": true,
		"error": "",
		"data": {
			"recipe_id": recipe_id,
			"recipe_name": str(recipe.get("name", recipe_id)),
			"outputs": outputs.duplicate(true),
			"snapshot": _economy_snapshot()
		}
	}

func sync_resource_catalog(payload: Dictionary) -> Dictionary:
	if not _connected:
		return {"ok": false, "error": "Not connected.", "data": {}}
	var raw_resources: Variant = payload.get("resources", [])
	if typeof(raw_resources) != TYPE_ARRAY:
		return {"ok": false, "error": "Resource catalog must be an array.", "data": {}}
	var registered: int = 0
	for row in raw_resources:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var resource: Dictionary = _sanitize_resource_def(row as Dictionary)
		if resource.is_empty():
			continue
		var resource_id: String = str(resource.get("resource_id", ""))
		_resource_catalog[resource_id] = resource
		registered += 1
	return {"ok": true, "error": "", "data": {"registered": registered}}

func submit_resource_mine(request: Dictionary) -> Dictionary:
	if not _connected:
		return {"ok": false, "error": "Not connected.", "data": {}}
	var raw_resource: Variant = request.get("resource", {})
	if typeof(raw_resource) != TYPE_DICTIONARY:
		return {"ok": false, "error": "Resource mine payload must be a dictionary.", "data": {}}
	var resource_id: String = str((raw_resource as Dictionary).get("resource_id", "")).strip_edges()
	if resource_id.is_empty():
		return {"ok": false, "error": "Resource ID is required.", "data": {}}
	if _mined_resource_ids.has(resource_id):
		return {"ok": false, "error": "Resource already mined.", "data": {}}
	var resource: Dictionary = _resource_catalog.get(resource_id, {})
	if resource.is_empty():
		return {"ok": false, "error": "Unknown resource node.", "data": {}}

	var claim_id: String = "resource:%s" % resource_id
	var reward: Dictionary = {
		"item_id": str(resource.get("item_id", "")),
		"quantity": max(1, int(resource.get("quantity", 1))),
		"credits": max(0, int(resource.get("credits", 0))),
		"source": "resource:%s" % resource_id
	}
	_reserved_reward_claims[claim_id] = reward
	_mined_resource_ids[resource_id] = true
	return {
		"ok": true,
		"error": "",
		"data": {
			"resource_id": resource_id,
			"claim_id": claim_id,
			"item_id": reward.get("item_id", ""),
			"quantity": reward.get("quantity", 1),
			"credits": reward.get("credits", 0)
		}
	}

func _process_buy_order(order: Dictionary) -> Dictionary:
	var listing_id: String = str(order.get("listing_id", "")).strip_edges()
	var quantity: int = int(order.get("quantity", 0))
	if listing_id.is_empty():
		return {"ok": false, "error": "Listing ID is required.", "data": {}}
	if quantity <= 0:
		return {"ok": false, "error": "Quantity must be at least 1.", "data": {}}

	var market_state: Dictionary = _get_market_state()
	var listings: Array = market_state.get("listings", []).duplicate(true)
	for i in range(listings.size()):
		var listing: Dictionary = listings[i]
		if str(listing.get("id", "")) != listing_id:
			continue
		var available: int = int(listing.get("quantity", 0))
		if available < quantity:
			return {"ok": false, "error": "Listing does not have enough stock.", "data": {}}
		var unit_price: int = int(listing.get("unit_price", 0))
		var total: int = unit_price * quantity
		if int(_authoritative_state.get("credits", 0)) < total:
			return {"ok": false, "error": "Not enough Celador Credits.", "data": {}}

		var inventory: Dictionary = _get_inventory_state()
		var item_id: String = str(listing.get("item_id", ""))
		inventory[item_id] = int(inventory.get(item_id, 0)) + quantity
		_authoritative_state["inventory"] = inventory
		_authoritative_state["credits"] = int(_authoritative_state.get("credits", 0)) - total

		listing["quantity"] = available - quantity
		if int(listing.get("quantity", 0)) <= 0:
			listings.remove_at(i)
		else:
			listings[i] = listing
		market_state["listings"] = listings
		_authoritative_state["marketplace"] = market_state
		return {
			"ok": true,
			"error": "",
			"data": {
				"accepted": true,
				"reason": "Purchased %d x %s" % [quantity, item_id],
				"listings": listings.duplicate(true),
				"snapshot": _economy_snapshot()
			}
		}

	return {"ok": false, "error": "Listing not found.", "data": {}}

func _process_sell_order(order: Dictionary) -> Dictionary:
	var item_id: String = str(order.get("item_id", "")).strip_edges()
	var quantity: int = int(order.get("quantity", 0))
	var unit_price: int = int(order.get("unit_price", 0))
	if item_id.is_empty():
		return {"ok": false, "error": "Item ID is required.", "data": {}}
	if quantity <= 0:
		return {"ok": false, "error": "Quantity must be at least 1.", "data": {}}
	if unit_price <= 0:
		return {"ok": false, "error": "Unit price must be positive.", "data": {}}
	if _item_defs.is_empty() == false and _item_defs.has(item_id) == false:
		return {"ok": false, "error": "Unknown item ID.", "data": {}}

	var inventory: Dictionary = _get_inventory_state()
	var current: int = int(inventory.get(item_id, 0))
	if current < quantity:
		return {"ok": false, "error": "You do not have enough of this item.", "data": {}}

	current -= quantity
	if current <= 0:
		inventory.erase(item_id)
	else:
		inventory[item_id] = current
	_authoritative_state["inventory"] = inventory

	var market_state: Dictionary = _get_market_state()
	var listings: Array = market_state.get("listings", []).duplicate(true)
	var listing_id: String = _allocate_listing_id(market_state)
	var listing: Dictionary = {
		"id": listing_id,
		"item_id": item_id,
		"quantity": quantity,
		"unit_price": unit_price,
		"seller": str(order.get("seller", "Player"))
	}
	listings.append(listing)
	market_state["listings"] = listings
	_authoritative_state["marketplace"] = market_state
	return {
		"ok": true,
		"error": "",
		"data": {
			"accepted": true,
			"reason": "Listed %d x %s" % [quantity, item_id],
			"listing": listing.duplicate(true),
			"listings": listings.duplicate(true),
			"snapshot": _economy_snapshot()
		}
	}

func _cache_catalog() -> void:
	_item_defs.clear()
	_recipe_defs.clear()
	if _data_service == null:
		return
	for item_def in _data_service.get_all_items():
		var item_id: String = str(item_def.get("id", "")).strip_edges()
		if item_id.is_empty():
			continue
		_item_defs[item_id] = item_def.duplicate(true)
	for recipe_def in _data_service.get_all_recipes():
		var recipe_id: String = str(recipe_def.get("id", "")).strip_edges()
		if recipe_id.is_empty():
			continue
		_recipe_defs[recipe_id] = recipe_def.duplicate(true)

func _reset_authoritative_state(state_present: bool) -> void:
	_authoritative_state = {
		"inventory": {},
		"credits": 0,
		"marketplace": {
			"listings": [],
			"next_listing_id": 1
		},
		"player_state": {},
		"world_state": {},
		"unlocked_lore": [],
		"timestamp": ""
	}
	_state_present = state_present
	_claimed_reward_ids = {}
	_resource_catalog = {}
	_mined_resource_ids = {}
	_reserved_reward_claims = {}

func _apply_external_state(state: Dictionary) -> void:
	_reset_authoritative_state(true)
	_authoritative_state["inventory"] = _sanitize_inventory(state.get("inventory", {}))
	_authoritative_state["credits"] = max(0, int(state.get("credits", 0)))
	_authoritative_state["marketplace"] = _sanitize_marketplace_state(state.get("marketplace", {}))
	_authoritative_state["player_state"] = _sanitize_player_state(state.get("player_state", {}))
	_authoritative_state["world_state"] = _sanitize_world_state(state.get("world_state", {}))
	_authoritative_state["unlocked_lore"] = _sanitize_string_array(state.get("unlocked_lore", []))
	_authoritative_state["timestamp"] = str(state.get("timestamp", ""))
	_rebuild_mined_resources_from_world_state()
	_ensure_market_seeded()

func _merge_runtime_state(state: Dictionary) -> void:
	_authoritative_state["player_state"] = _sanitize_player_state(state.get("player_state", _authoritative_state.get("player_state", {})))
	_authoritative_state["world_state"] = _sanitize_world_state(state.get("world_state", _authoritative_state.get("world_state", {})))
	_authoritative_state["unlocked_lore"] = _sanitize_string_array(state.get("unlocked_lore", _authoritative_state.get("unlocked_lore", [])))
	_authoritative_state["timestamp"] = str(state.get("timestamp", _authoritative_state.get("timestamp", "")))
	_rebuild_mined_resources_from_world_state()

func _snapshot() -> Dictionary:
	return {
		"inventory": _get_inventory_state(),
		"credits": int(_authoritative_state.get("credits", 0)),
		"marketplace": _get_market_state(),
		"player_state": (_authoritative_state.get("player_state", {}) as Dictionary).duplicate(true),
		"world_state": (_authoritative_state.get("world_state", {}) as Dictionary).duplicate(true),
		"unlocked_lore": (_authoritative_state.get("unlocked_lore", []) as Array).duplicate(true),
		"timestamp": str(_authoritative_state.get("timestamp", ""))
	}

func _economy_snapshot() -> Dictionary:
	return {
		"inventory": _get_inventory_state(),
		"credits": int(_authoritative_state.get("credits", 0)),
		"marketplace": _get_market_state()
	}

func _get_inventory_state() -> Dictionary:
	return (_authoritative_state.get("inventory", {}) as Dictionary).duplicate(true)

func _get_market_state() -> Dictionary:
	return (_authoritative_state.get("marketplace", {}) as Dictionary).duplicate(true)

func _ensure_market_seeded() -> void:
	var market_state: Dictionary = _get_market_state()
	var listings: Array = market_state.get("listings", [])
	if not listings.is_empty():
		return
	market_state["listings"] = [
		{"id": _allocate_listing_id(market_state), "item_id": "dust_blue", "quantity": 12, "unit_price": 7, "seller": "Frontier Guild"},
		{"id": _allocate_listing_id(market_state), "item_id": "energy_crystal", "quantity": 6, "unit_price": 20, "seller": "Makuna Exchange"},
		{"id": _allocate_listing_id(market_state), "item_id": "alloy", "quantity": 3, "unit_price": 50, "seller": "Ridge Smithy"}
	]
	_authoritative_state["marketplace"] = market_state

func _allocate_listing_id(market_state: Dictionary) -> String:
	var next_listing_id: int = max(1, int(market_state.get("next_listing_id", 1)))
	var listing_id: String = "listing_%d" % next_listing_id
	market_state["next_listing_id"] = next_listing_id + 1
	return listing_id

func _apply_credit_gain(base_amount: int) -> int:
	if base_amount <= 0:
		return 0
	var final_amount: int = int(round(float(base_amount) * (1.0 + _get_modifier_total("credit_gain_multiplier"))))
	final_amount = max(final_amount, 0)
	_authoritative_state["credits"] = int(_authoritative_state.get("credits", 0)) + final_amount
	return final_amount

func _get_modifier_total(stat_key: String) -> float:
	var total: float = 0.0
	var inventory: Dictionary = _get_inventory_state()
	for item_id in inventory.keys():
		var quantity: int = int(inventory.get(item_id, 0))
		if quantity <= 0:
			continue
		var item_def: Dictionary = _item_defs.get(str(item_id), {})
		if item_def.is_empty():
			continue
		var modifier: Dictionary = item_def.get("modifier", {})
		if typeof(modifier) != TYPE_DICTIONARY:
			continue
		total += float(modifier.get(stat_key, 0.0))
	return total

func _validate_recipe(recipe: Dictionary) -> Dictionary:
	var inventory: Dictionary = _get_inventory_state()
	var ingredients: Dictionary = recipe.get("ingredients", {})
	for item_id in ingredients.keys():
		var amount: int = int(ingredients.get(item_id, 0))
		if int(inventory.get(item_id, 0)) < amount:
			return {"ok": false, "reason": "Missing %s x%d" % [str(item_id), amount]}

	var special: Dictionary = recipe.get("special", {})
	var distinct_dust_count: int = int(special.get("distinct_dust_count", 0))
	if distinct_dust_count > 0:
		var dust_ids: Array = _get_available_dust_ids(inventory)
		if dust_ids.size() < distinct_dust_count:
			return {"ok": false, "reason": "Need %d distinct moon dust types." % distinct_dust_count}

	return {"ok": true, "reason": ""}

func _get_available_dust_ids(inventory: Dictionary) -> Array:
	var available: Array = []
	for item_id in inventory.keys():
		if int(inventory.get(item_id, 0)) <= 0:
			continue
		var item_def: Dictionary = _item_defs.get(str(item_id), {})
		if item_def.is_empty():
			continue
		var tags: Array = item_def.get("tags", [])
		if tags.has("dust"):
			available.append(str(item_id))
	available.sort()
	return available

func _sanitize_inventory(raw_inventory: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw_inventory) != TYPE_DICTIONARY:
		return out
	for key in (raw_inventory as Dictionary).keys():
		var item_id: String = str(key).strip_edges()
		if item_id.is_empty():
			continue
		if _item_defs.is_empty() == false and _item_defs.has(item_id) == false:
			continue
		var quantity: int = int((raw_inventory as Dictionary).get(key, 0))
		if quantity <= 0:
			continue
		out[item_id] = quantity
	return out

func _sanitize_marketplace_state(raw_marketplace: Variant) -> Dictionary:
	var out: Dictionary = {
		"listings": [],
		"next_listing_id": 1
	}
	if typeof(raw_marketplace) != TYPE_DICTIONARY:
		return out
	var market: Dictionary = raw_marketplace as Dictionary
	var sanitized_listings: Array = []
	if typeof(market.get("listings", [])) == TYPE_ARRAY:
		for row in market.get("listings", []):
			if typeof(row) != TYPE_DICTIONARY:
				continue
			var listing: Dictionary = row.duplicate(true)
			if str(listing.get("id", "")).is_empty():
				continue
			if str(listing.get("item_id", "")).is_empty():
				continue
			listing["quantity"] = max(0, int(listing.get("quantity", 0)))
			listing["unit_price"] = max(0, int(listing.get("unit_price", 0)))
			if int(listing.get("quantity", 0)) <= 0 or int(listing.get("unit_price", 0)) <= 0:
				continue
			sanitized_listings.append(listing)
	out["listings"] = sanitized_listings
	out["next_listing_id"] = max(1, int(market.get("next_listing_id", sanitized_listings.size() + 1)))
	return out

func _sanitize_player_state(raw_player_state: Variant) -> Dictionary:
	if typeof(raw_player_state) != TYPE_DICTIONARY:
		return {}
	return (raw_player_state as Dictionary).duplicate(true)

func _sanitize_world_state(raw_world_state: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw_world_state) != TYPE_DICTIONARY:
		return out
	for key in (raw_world_state as Dictionary).keys():
		var flag_id: String = str(key).strip_edges()
		if flag_id.is_empty():
			continue
		out[flag_id] = bool((raw_world_state as Dictionary).get(key, false))
	return out

func _sanitize_string_array(raw_values: Variant) -> Array:
	var out: Array = []
	if typeof(raw_values) != TYPE_ARRAY:
		return out
	var seen: Dictionary = {}
	for value in raw_values:
		var text: String = str(value).strip_edges()
		if text.is_empty() or seen.has(text):
			continue
		seen[text] = true
		out.append(text)
	return out

func _sanitize_resource_def(resource: Dictionary) -> Dictionary:
	var resource_id: String = str(resource.get("resource_id", "")).strip_edges()
	var item_id: String = str(resource.get("item_id", "")).strip_edges()
	if resource_id.is_empty() or item_id.is_empty():
		return {}
	if _item_defs.is_empty() == false and _item_defs.has(item_id) == false:
		return {}
	return {
		"resource_id": resource_id,
		"item_id": item_id,
		"quantity": max(1, int(resource.get("quantity", 1))),
		"credits": max(0, int(resource.get("credits", 0))),
		"position": resource.get("position", []).duplicate(true) if typeof(resource.get("position", [])) == TYPE_ARRAY else []
	}

func _rebuild_mined_resources_from_world_state() -> void:
	_mined_resource_ids = {}
	var world_state: Dictionary = _authoritative_state.get("world_state", {})
	for key in world_state.keys():
		var flag_id: String = str(key).strip_edges()
		if not flag_id.begins_with("resource_mined:"):
			continue
		if not bool(world_state.get(flag_id, false)):
			continue
		var resource_id: String = flag_id.trim_prefix("resource_mined:")
		if resource_id.is_empty():
			continue
		_mined_resource_ids[resource_id] = true
