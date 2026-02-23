extends Node

signal save_loaded(state: Dictionary)
signal save_written(path: String)
signal save_deleted(path: String)

const SAVE_PATH: String = "user://savegame_v01.json"
const SAVE_SCHEMA_VERSION: int = 2
const SAVE_LABEL_VERSION: String = "0.1"

var _inventory_service: Node = null
var _lore_service: Node = null
var _marketplace_service: Node = null
var _event_log_service: Node = null
var _world_state_provider: Node = null
var loaded_state: Dictionary = {}

func setup(
	inventory_service: Node,
	lore_service: Node,
	marketplace_service: Node,
	event_log_service: Node,
	world_state_provider: Node = null
) -> void:
	_inventory_service = inventory_service
	_lore_service = lore_service
	_marketplace_service = marketplace_service
	_event_log_service = event_log_service
	_world_state_provider = world_state_provider

func load_game() -> Dictionary:
	var raw_state: Dictionary = {}
	if FileAccess.file_exists(SAVE_PATH):
		var raw_text: String = FileAccess.get_file_as_string(SAVE_PATH)
		var parsed: Variant = JSON.parse_string(raw_text)
		if typeof(parsed) == TYPE_DICTIONARY:
			raw_state = parsed

	loaded_state = normalize_state_for_load(raw_state)
	_apply_loaded_state(loaded_state)
	if _event_log_service != null:
		_event_log_service.record("system.save_loaded", {
			"path": SAVE_PATH,
			"schema_version": int(loaded_state.get("schema_version", 1))
		})
	save_loaded.emit(loaded_state)
	return loaded_state

func save_game(player_state: Dictionary) -> bool:
	var world_state_snapshot: Dictionary = {}
	if _world_state_provider != null and _world_state_provider.has_method("get_world_state"):
		world_state_snapshot = _world_state_provider.get_world_state()
	var save_state_raw: Dictionary = {
		"schema_version": SAVE_SCHEMA_VERSION,
		"version": SAVE_LABEL_VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		"player_state": player_state,
		"inventory": _inventory_service.get_all_items(),
		"credits": _inventory_service.credits,
		"unlocked_lore": _lore_service.get_unlocked_ids(),
		"marketplace": _marketplace_service.serialize_state(),
		"world_state": world_state_snapshot,
		"event_log": _event_log_service.serialize_state() if _event_log_service != null else []
	}
	var state_to_write: Dictionary = normalize_state_for_load(save_state_raw)

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Unable to open save file: %s" % SAVE_PATH)
		return false
	file.store_string(JSON.stringify(state_to_write, "\t"))
	file.close()

	loaded_state = state_to_write
	if _event_log_service != null:
		_event_log_service.record("system.save_written", {
			"path": SAVE_PATH,
			"schema_version": SAVE_SCHEMA_VERSION
		})
	save_written.emit(SAVE_PATH)
	return true

func normalize_state_for_load(raw_state: Dictionary) -> Dictionary:
	var normalized: Dictionary = _default_state()
	if raw_state.is_empty():
		return normalized

	normalized["schema_version"] = max(1, int(raw_state.get("schema_version", 1)))
	normalized["version"] = str(raw_state.get("version", SAVE_LABEL_VERSION))
	normalized["timestamp"] = str(raw_state.get("timestamp", ""))
	normalized["player_state"] = _sanitize_player_state(raw_state.get("player_state", {}))
	normalized["inventory"] = _sanitize_inventory(raw_state.get("inventory", {}))
	normalized["credits"] = max(0, int(raw_state.get("credits", 0)))
	normalized["unlocked_lore"] = _sanitize_string_array(raw_state.get("unlocked_lore", []), true)
	normalized["world_state"] = _sanitize_world_state(raw_state.get("world_state", {}))
	normalized["event_log"] = _sanitize_event_log(raw_state.get("event_log", []))

	var marketplace_state: Variant = raw_state.get("marketplace", {})
	if typeof(marketplace_state) == TYPE_DICTIONARY:
		normalized["marketplace"] = (marketplace_state as Dictionary).duplicate(true)
	else:
		normalized["marketplace"] = {}

	if int(normalized.get("schema_version", 1)) < SAVE_SCHEMA_VERSION:
		normalized = _migrate_legacy_state(normalized)
	normalized["schema_version"] = SAVE_SCHEMA_VERSION
	if str(normalized.get("version", "")).is_empty():
		normalized["version"] = SAVE_LABEL_VERSION
	return normalized

func get_loaded_state() -> Dictionary:
	return loaded_state.duplicate(true)

func delete_save_file() -> bool:
	loaded_state = _default_state()
	if not FileAccess.file_exists(SAVE_PATH):
		if _event_log_service != null:
			_event_log_service.record("system.save_deleted", {"path": SAVE_PATH, "already_missing": true})
		save_deleted.emit(SAVE_PATH)
		return true
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		push_error("Unable to open save directory for delete.")
		return false
	var err: int = dir.remove("savegame_v01.json")
	if err != OK:
		push_error("Unable to delete save file: %s (err=%d)" % [SAVE_PATH, err])
		return false
	if _event_log_service != null:
		_event_log_service.record("system.save_deleted", {"path": SAVE_PATH, "already_missing": false})
	save_deleted.emit(SAVE_PATH)
	return true

func _apply_loaded_state(state: Dictionary) -> void:
	_inventory_service.set_inventory(state.get("inventory", {}))
	_inventory_service.set_credits(int(state.get("credits", 0)))
	_lore_service.set_unlocked_ids(state.get("unlocked_lore", []))
	_marketplace_service.load_state(state.get("marketplace", {}))
	if _event_log_service != null:
		_event_log_service.load_state(state.get("event_log", []))

func _default_state() -> Dictionary:
	return {
		"schema_version": SAVE_SCHEMA_VERSION,
		"version": SAVE_LABEL_VERSION,
		"timestamp": "",
		"player_state": _sanitize_player_state({}),
		"inventory": {},
		"credits": 0,
		"unlocked_lore": [],
		"marketplace": {},
		"world_state": {},
		"event_log": []
	}

func _migrate_legacy_state(state: Dictionary) -> Dictionary:
	var migrated: Dictionary = state.duplicate(true)
	var market_state: Dictionary = migrated.get("marketplace", {})
	if not market_state.has("listings"):
		market_state["listings"] = []
	if not market_state.has("next_listing_id"):
		market_state["next_listing_id"] = 1
	migrated["marketplace"] = market_state
	migrated["world_state"] = _derive_objective_flags_from_state(migrated)
	return migrated

func _derive_objective_flags_from_state(state: Dictionary) -> Dictionary:
	var world_state: Dictionary = _sanitize_world_state(state.get("world_state", {}))
	var inventory: Dictionary = _sanitize_inventory(state.get("inventory", {}))
	var unlocked_lore: Array = _sanitize_string_array(state.get("unlocked_lore", []), true)

	var dust_total: int = 0
	for item_id in inventory.keys():
		var item_key: String = str(item_id)
		if item_key.begins_with("dust_"):
			dust_total += int(inventory.get(item_id, 0))

	if not world_state.has("objective_collect_dust_complete"):
		world_state["objective_collect_dust_complete"] = dust_total >= 1
	if not world_state.has("objective_collect_energy_complete"):
		world_state["objective_collect_energy_complete"] = int(inventory.get("energy_crystal", 0)) >= 1
	if not world_state.has("objective_salvage_bot_complete"):
		world_state["objective_salvage_bot_complete"] = int(inventory.get("bot_scrap", 0)) >= 1
	if not world_state.has("objective_forge_alloy_complete"):
		world_state["objective_forge_alloy_complete"] = int(inventory.get("alloy", 0)) >= 1
	if not world_state.has("objective_unlock_lore_complete"):
		world_state["objective_unlock_lore_complete"] = unlocked_lore.size() >= 3
	if not world_state.has("objective_acquire_dream_seed_complete"):
		world_state["objective_acquire_dream_seed_complete"] = int(inventory.get("dream_seed", 0)) >= 1
	if not world_state.has("objective_craft_moonblade_complete"):
		world_state["objective_craft_moonblade_complete"] = int(inventory.get("moonblade_prototype", 0)) >= 1
	if not world_state.has("objective_prime_ruins_terminal_complete"):
		world_state["objective_prime_ruins_terminal_complete"] = bool(world_state.get("ruins_terminal_primed", false))

	return world_state

func _sanitize_player_state(raw_state: Variant) -> Dictionary:
	var player_state: Dictionary = {}
	if typeof(raw_state) == TYPE_DICTIONARY:
		player_state = (raw_state as Dictionary).duplicate(true)
	var position: Array = [0.0, 8.0, 0.0]
	if typeof(player_state.get("position", [])) == TYPE_ARRAY:
		var source: Array = player_state.get("position", [])
		if source.size() == 3:
			position = [float(source[0]), float(source[1]), float(source[2])]
	return {
		"position": position,
		"health": float(player_state.get("health", 100.0)),
		"stamina": float(player_state.get("stamina", 100.0)),
		"shield": float(player_state.get("shield", 0.0))
	}

func _sanitize_inventory(raw_inventory: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw_inventory) != TYPE_DICTIONARY:
		return out
	for key in (raw_inventory as Dictionary).keys():
		var item_id: String = str(key)
		if item_id.is_empty():
			continue
		var qty: int = int((raw_inventory as Dictionary).get(key, 0))
		if qty <= 0:
			continue
		out[item_id] = qty
	return out

func _sanitize_world_state(raw_world_state: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw_world_state) != TYPE_DICTIONARY:
		return out
	for key in (raw_world_state as Dictionary).keys():
		var flag_id: String = str(key)
		if flag_id.is_empty():
			continue
		out[flag_id] = bool((raw_world_state as Dictionary).get(key, false))
	return out

func _sanitize_event_log(raw_event_log: Variant) -> Array:
	var out: Array = []
	if typeof(raw_event_log) != TYPE_ARRAY:
		return out
	for row in raw_event_log:
		if typeof(row) == TYPE_DICTIONARY:
			out.append((row as Dictionary).duplicate(true))
	return out

func _sanitize_string_array(raw_values: Variant, dedupe: bool) -> Array:
	var out: Array = []
	if typeof(raw_values) != TYPE_ARRAY:
		return out
	var seen: Dictionary = {}
	for value in raw_values:
		if typeof(value) != TYPE_STRING:
			continue
		var text: String = str(value).strip_edges()
		if text.is_empty():
			continue
		if dedupe and seen.has(text):
			continue
		seen[text] = true
		out.append(text)
	return out
