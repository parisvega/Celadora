extends Node

signal crafted(recipe_id: String, outputs: Dictionary)

var _data_service: Node = null
var _inventory_service: Node = null

func setup(data_service: Node, inventory_service: Node) -> void:
	_data_service = data_service
	_inventory_service = inventory_service

func can_craft(recipe_id: String) -> Dictionary:
	var recipe: Dictionary = _data_service.get_recipe(recipe_id)
	if recipe.is_empty():
		return {"ok": false, "reason": "Unknown recipe."}

	var ingredients: Dictionary = recipe.get("ingredients", {})
	for item_id in ingredients.keys():
		var amount = int(ingredients[item_id])
		if not _inventory_service.has_item(item_id, amount):
			return {"ok": false, "reason": "Missing %s x%d" % [item_id, amount]}

	var special: Dictionary = recipe.get("special", {})
	var distinct_dust_count = int(special.get("distinct_dust_count", 0))
	if distinct_dust_count > 0:
		var dust_ids = _get_available_dust_ids()
		if dust_ids.size() < distinct_dust_count:
			return {
				"ok": false,
				"reason": "Need %d distinct moon dust types." % distinct_dust_count
			}

	return {"ok": true, "reason": ""}

func craft(recipe_id: String) -> Dictionary:
	var validation: Dictionary = can_craft(recipe_id)
	if not validation.get("ok", false):
		return validation

	var recipe: Dictionary = _data_service.get_recipe(recipe_id)
	var ingredients: Dictionary = recipe.get("ingredients", {})
	for item_id in ingredients.keys():
		var amount = int(ingredients[item_id])
		if not _inventory_service.remove_item(item_id, amount):
			return {"ok": false, "reason": "Failed to consume %s." % item_id}

	var special: Dictionary = recipe.get("special", {})
	var distinct_dust_count = int(special.get("distinct_dust_count", 0))
	if distinct_dust_count > 0:
		var available_dust_ids = _get_available_dust_ids()
		for i in range(distinct_dust_count):
			if i >= available_dust_ids.size():
				break
			_inventory_service.remove_item(available_dust_ids[i], 1)

	var outputs: Dictionary = recipe.get("outputs", {})
	for out_item_id in outputs.keys():
		_inventory_service.add_item(out_item_id, int(outputs[out_item_id]))

	GameServices.log_event("crafting.recipe_crafted", {
		"recipe_id": recipe_id,
		"outputs": outputs
	})
	crafted.emit(recipe_id, outputs)
	return {"ok": true, "reason": "Crafted %s" % recipe.get("name", recipe_id), "outputs": outputs}

func get_recipes() -> Array:
	return _data_service.get_all_recipes()

func _get_available_dust_ids() -> Array:
	var available: Array = []
	for row in _inventory_service.get_item_display_rows():
		if int(row["quantity"]) <= 0:
			continue
		var item_id: String = str(row["id"])
		var item_def: Dictionary = _data_service.get_item(item_id)
		var tags: Array = item_def.get("tags", [])
		if tags.has("dust"):
			available.append(item_id)
	available.sort()
	return available
