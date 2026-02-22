extends Node

signal save_loaded(state: Dictionary)
signal save_written(path: String)
signal save_deleted(path: String)

const SAVE_PATH = "user://savegame_v01.json"

var _inventory_service: Node = null
var _lore_service: Node = null
var _marketplace_service: Node = null
var loaded_state: Dictionary = {}

func setup(inventory_service: Node, lore_service: Node, marketplace_service: Node) -> void:
	_inventory_service = inventory_service
	_lore_service = lore_service
	_marketplace_service = marketplace_service

func load_game() -> Dictionary:
	loaded_state = {}
	if FileAccess.file_exists(SAVE_PATH):
		var raw_text = FileAccess.get_file_as_string(SAVE_PATH)
		var parsed = JSON.parse_string(raw_text)
		if typeof(parsed) == TYPE_DICTIONARY:
			loaded_state = parsed

	var inventory: Dictionary = loaded_state.get("inventory", {})
	var credits = int(loaded_state.get("credits", 0))
	var unlocked_lore: Array = loaded_state.get("unlocked_lore", [])
	var marketplace_state: Dictionary = loaded_state.get("marketplace", {})

	_inventory_service.set_inventory(inventory)
	_inventory_service.set_credits(credits)
	_lore_service.set_unlocked_ids(unlocked_lore)
	_marketplace_service.load_state(marketplace_state)
	save_loaded.emit(loaded_state)
	return loaded_state

func save_game(player_state: Dictionary) -> bool:
	var state_to_write = {
		"version": "0.1",
		"timestamp": Time.get_datetime_string_from_system(),
		"player_state": player_state,
		"inventory": _inventory_service.get_all_items(),
		"credits": _inventory_service.credits,
		"unlocked_lore": _lore_service.get_unlocked_ids(),
		"marketplace": _marketplace_service.serialize_state()
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Unable to open save file: %s" % SAVE_PATH)
		return false
	file.store_string(JSON.stringify(state_to_write, "\t"))
	loaded_state = state_to_write
	save_written.emit(SAVE_PATH)
	return true

func get_loaded_state() -> Dictionary:
	return loaded_state.duplicate(true)

func delete_save_file() -> bool:
	loaded_state = {}
	if not FileAccess.file_exists(SAVE_PATH):
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
	save_deleted.emit(SAVE_PATH)
	return true
