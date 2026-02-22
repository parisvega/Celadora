extends Node

signal services_ready

const DataServiceScript = preload("res://scripts/services/data_service.gd")
const EventLogServiceScript = preload("res://scripts/services/event_log_service.gd")
const InventoryServiceScript = preload("res://scripts/services/inventory_service.gd")
const CraftingServiceScript = preload("res://scripts/services/crafting_service.gd")
const SaveServiceScript = preload("res://scripts/services/save_service.gd")
const LoreJournalServiceScript = preload("res://scripts/services/lore_journal_service.gd")
const MarketplaceServiceScript = preload("res://scripts/services/marketplace_service.gd")
const LocalNetworkServiceScript = preload("res://scripts/services/network/local_network_service.gd")

var data_service: Node = null
var event_log_service: Node = null
var inventory_service: Node = null
var crafting_service: Node = null
var save_service: Node = null
var lore_journal_service: Node = null
var marketplace_service: Node = null
var network_service: Node = null

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

	network_service = LocalNetworkServiceScript.new()
	add_child(network_service)
	network_service.connect_player({"name": "Local Pioneer"})

	marketplace_service = MarketplaceServiceScript.new()
	add_child(marketplace_service)
	marketplace_service.setup(inventory_service, data_service, network_service)

	save_service = SaveServiceScript.new()
	add_child(save_service)
	save_service.setup(inventory_service, lore_journal_service, marketplace_service, event_log_service)
	save_service.load_game()

	_bootstrapped = true
	services_ready.emit()

func save_now(player_state: Dictionary = {}) -> bool:
	if not _bootstrapped:
		bootstrap()
	return save_service.save_game(player_state)

func get_item_def(item_id: String) -> Dictionary:
	return data_service.get_item(item_id)

func get_enemy_def(enemy_id: String) -> Dictionary:
	return data_service.get_enemy(enemy_id)

func get_recipe_def(recipe_id: String) -> Dictionary:
	return data_service.get_recipe(recipe_id)

func get_data_validation_report() -> Dictionary:
	return data_service.get_validation_report()

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
	if event_log_service:
		event_log_service.clear()
		event_log_service.record("system.progress_reset", {"save_path": "user://savegame_v01.json"})

	return {
		"ok": deleted,
		"reason": "Local progress reset." if deleted else "Failed to reset save file.",
		"save_path": "user://savegame_v01.json"
	}
