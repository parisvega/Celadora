extends Node

signal inventory_changed
signal credits_changed(total: int)

var _data_service: Node = null
var _items: Dictionary = {}
var credits: int = 0

func setup(data_service: Node) -> void:
	_data_service = data_service

func add_item(item_id: String, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false
	if _data_service.get_item(item_id).is_empty():
		push_warning("Attempted to add unknown item: %s" % item_id)
		return false
	_items[item_id] = int(_items.get(item_id, 0)) + quantity
	inventory_changed.emit()
	return true

func remove_item(item_id: String, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false
	var current = int(_items.get(item_id, 0))
	if current < quantity:
		return false
	current -= quantity
	if current <= 0:
		_items.erase(item_id)
	else:
		_items[item_id] = current
	inventory_changed.emit()
	return true

func has_item(item_id: String, quantity: int = 1) -> bool:
	return int(_items.get(item_id, 0)) >= quantity

func get_quantity(item_id: String) -> int:
	return int(_items.get(item_id, 0))

func set_inventory(new_inventory: Dictionary) -> void:
	_items = {}
	for item_id in new_inventory.keys():
		_items[item_id] = int(new_inventory[item_id])
	inventory_changed.emit()

func get_all_items() -> Dictionary:
	return _items.duplicate(true)

func clear() -> void:
	_items.clear()
	credits = 0
	inventory_changed.emit()
	credits_changed.emit(credits)

func set_credits(new_total: int) -> void:
	credits = max(new_total, 0)
	credits_changed.emit(credits)

func add_credits(base_amount: int) -> int:
	if base_amount <= 0:
		return 0
	var multiplier = 1.0 + get_modifier_value("credit_gain_multiplier", 0.0)
	var final_amount = int(round(float(base_amount) * max(multiplier, 0.0)))
	credits += max(final_amount, 0)
	credits_changed.emit(credits)
	return final_amount

func spend_credits(amount: int) -> bool:
	if amount <= 0:
		return false
	if credits < amount:
		return false
	credits -= amount
	credits_changed.emit(credits)
	return true

func get_active_modifiers() -> Dictionary:
	var combined: Dictionary = {}
	for item_id in _items.keys():
		if int(_items[item_id]) <= 0:
			continue
		var item_def: Dictionary = _data_service.get_item(item_id)
		if item_def.is_empty():
			continue
		var modifier: Dictionary = item_def.get("modifier", {})
		if typeof(modifier) != TYPE_DICTIONARY:
			continue
		for stat_key in modifier.keys():
			combined[stat_key] = float(combined.get(stat_key, 0.0)) + float(modifier[stat_key])
	return combined

func get_modifier_value(stat_key: String, default_value: float = 0.0) -> float:
	var modifiers: Dictionary = get_active_modifiers()
	return float(modifiers.get(stat_key, default_value))

func get_item_display_rows() -> Array:
	var rows: Array = []
	for item_id in _items.keys():
		var item_def: Dictionary = _data_service.get_item(item_id)
		var name = item_def.get("name", item_id)
		rows.append({
			"id": item_id,
			"name": name,
			"quantity": int(_items[item_id])
		})
	rows.sort_custom(func(a, b): return str(a["name"]) < str(b["name"]))
	return rows
