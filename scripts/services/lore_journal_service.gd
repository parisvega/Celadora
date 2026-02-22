extends Node

signal entry_unlocked(location_id: String)

var _data_service: Node = null
var _unlocked: Dictionary = {}

func setup(data_service: Node) -> void:
	_data_service = data_service

func unlock_entry(location_id: String) -> bool:
	if _unlocked.get(location_id, false):
		return false
	var location: Dictionary = _data_service.get_location(location_id)
	if location.is_empty():
		push_warning("Unknown lore location: %s" % location_id)
		return false
	_unlocked[location_id] = true
	GameServices.log_event("lore.entry_unlocked", {"location_id": location_id})
	entry_unlocked.emit(location_id)
	return true

func is_unlocked(location_id: String) -> bool:
	return bool(_unlocked.get(location_id, false))

func get_unlocked_ids() -> Array:
	return _unlocked.keys()

func get_unlocked_entries() -> Array:
	var entries: Array = []
	for location_id in _unlocked.keys():
		var entry: Dictionary = _data_service.get_location(location_id)
		if not entry.is_empty():
			entries.append(entry)
	entries.sort_custom(func(a, b): return str(a.get("name", "")) < str(b.get("name", "")))
	return entries

func set_unlocked_ids(ids: Array) -> void:
	_unlocked.clear()
	for id in ids:
		_unlocked[str(id)] = true
