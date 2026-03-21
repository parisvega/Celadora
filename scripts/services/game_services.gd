extends Node

signal services_ready
signal world_state_changed(key: String, value: Variant)
signal world_state_reloaded(state: Dictionary)

const DataServiceScript = preload("res://scripts/services/data_service.gd")
const EventLogServiceScript = preload("res://scripts/services/event_log_service.gd")
const InventoryServiceScript = preload("res://scripts/services/inventory_service.gd")
const CraftingServiceScript = preload("res://scripts/services/crafting_service.gd")
const SaveServiceScript = preload("res://scripts/services/save_service.gd")
const LoreJournalServiceScript = preload("res://scripts/services/lore_journal_service.gd")
const MarketplaceServiceScript = preload("res://scripts/services/marketplace_service.gd")
const AuthorityServiceScript = preload("res://scripts/services/authority_service.gd")
const HttpNetworkServiceScript = preload("res://scripts/services/network/http_network_service.gd")
const LocalNetworkServiceScript = preload("res://scripts/services/network/local_network_service.gd")

var data_service: Node = null
var event_log_service: Node = null
var inventory_service: Node = null
var crafting_service: Node = null
var save_service: Node = null
var lore_journal_service: Node = null
var marketplace_service: Node = null
var network_service: Node = null
var authority_service: Node = null
var world_state: Dictionary = {}

var _bootstrapped: bool = false

func _ready() -> void:
	bootstrap()

func bootstrap() -> void:
	if _bootstrapped:
		return

	data_service = DataServiceScript.new()
	add_child(data_service)
	var data_ok: bool = data_service.load_all()
	if not data_ok:
		push_error("[GameServices] Data validation failed. See DataService errors in output.")

	event_log_service = EventLogServiceScript.new()
	add_child(event_log_service)

	inventory_service = InventoryServiceScript.new()
	add_child(inventory_service)
	inventory_service.setup(data_service)

	crafting_service = CraftingServiceScript.new()
	add_child(crafting_service)
	crafting_service.setup(data_service, inventory_service)

	lore_journal_service = LoreJournalServiceScript.new()
	add_child(lore_journal_service)
	lore_journal_service.setup(data_service)

	network_service = _create_network_service()
	add_child(network_service)

	marketplace_service = MarketplaceServiceScript.new()
	add_child(marketplace_service)
	marketplace_service.setup(inventory_service, data_service, network_service)

	save_service = SaveServiceScript.new()
	add_child(save_service)
	save_service.setup(
		inventory_service,
		lore_journal_service,
		marketplace_service,
		event_log_service,
		self
	)
	save_service.save_loaded.connect(_on_save_loaded)
	save_service.load_game()

	authority_service = AuthorityServiceScript.new()
	add_child(authority_service)
	authority_service.setup(
		network_service,
		inventory_service,
		marketplace_service,
		lore_journal_service,
		save_service,
		self
	)

	var authority_result: Dictionary = authority_service.connect_and_bootstrap(
		{"name": "Local Pioneer"},
		save_service.get_loaded_state()
	)
	if authority_result.get("ok", false):
		var resolved_state: Dictionary = authority_result.get("data", {}).get("resolved_state", save_service.get_loaded_state())
		save_service.replace_loaded_state(resolved_state, true)
		crafting_service.set_authority_service(authority_service)
		marketplace_service.set_authority_service(authority_service)
	else:
		push_warning("[GameServices] Authority bootstrap failed: %s" % str(authority_result.get("error", "unknown")))
		save_service.replace_loaded_state(save_service.get_loaded_state(), true)

	_bootstrapped = true
	services_ready.emit()

func save_now(player_state: Dictionary = {}) -> bool:
	if not _bootstrapped:
		bootstrap()
	if authority_service != null and authority_service.has_method("is_authority_connected") and authority_service.is_authority_connected():
		authority_service.sync_state(save_service.build_state_snapshot(player_state))
	return save_service.save_game(player_state)

func get_item_def(item_id: String) -> Dictionary:
	return data_service.get_item(item_id)

func get_enemy_def(enemy_id: String) -> Dictionary:
	return data_service.get_enemy(enemy_id)

func get_recipe_def(recipe_id: String) -> Dictionary:
	return data_service.get_recipe(recipe_id)

func get_data_validation_report() -> Dictionary:
	return data_service.get_validation_report()

func get_world_state() -> Dictionary:
	return world_state.duplicate(true)

func set_world_state(state: Dictionary) -> void:
	world_state = state.duplicate(true)
	world_state_reloaded.emit(get_world_state())

func get_world_flag(flag_id: String, default_value: bool = false) -> bool:
	return bool(world_state.get(flag_id, default_value))

func set_world_flag(flag_id: String, enabled: bool) -> void:
	world_state[flag_id] = enabled
	world_state_changed.emit(flag_id, enabled)
	log_event("world.flag_changed", {"flag_id": flag_id, "enabled": enabled})

func log_event(event_type: String, payload: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	if event_log_service == null:
		return {}
	return event_log_service.record(event_type, payload, context)

func reset_local_progress() -> Dictionary:
	if not _bootstrapped:
		bootstrap()

	var deleted: bool = save_service.delete_save_file()
	inventory_service.clear()
	lore_journal_service.set_unlocked_ids([])
	marketplace_service.load_state({})
	world_state = {}
	world_state_reloaded.emit({})
	if event_log_service:
		event_log_service.clear()
		event_log_service.record("system.progress_reset", {"save_path": "user://savegame_v01.json"})
	if authority_service != null and authority_service.has_method("is_authority_connected") and authority_service.is_authority_connected():
		var reset_state: Dictionary = save_service.normalize_state_for_load({})
		authority_service.sync_state(reset_state, true)
		save_service.replace_loaded_state(reset_state, true)

	return {
		"ok": deleted,
		"reason": "Local progress reset." if deleted else "Failed to reset save file.",
		"save_path": "user://savegame_v01.json"
	}

func _on_save_loaded(state: Dictionary) -> void:
	_set_world_state_from_loaded(state)

func _set_world_state_from_loaded(state: Dictionary) -> void:
	var loaded_world_state: Dictionary = state.get("world_state", {})
	set_world_state(loaded_world_state)

func _create_network_service() -> Node:
	var authority_url: String = OS.get_environment("CELADORA_AUTHORITY_URL").strip_edges()
	if not authority_url.is_empty():
		var http_service := HttpNetworkServiceScript.new()
		http_service.setup(authority_url)
		return http_service
	var local_service := LocalNetworkServiceScript.new()
	if local_service.has_method("setup"):
		local_service.setup(data_service)
	return local_service
