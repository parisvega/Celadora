extends Node

const DATA_FILES = {
	"items": "res://data/items.json",
	"recipes": "res://data/recipes.json",
	"enemies": "res://data/enemies.json",
	"moons": "res://data/moons.json",
	"locations": "res://data/locations.json",
	"viewmodel": "res://data/viewmodel.json"
}

const REQUIRED_DUST_IDS = [
	"dust_blue",
	"dust_green",
	"dust_red",
	"dust_orange",
	"dust_yellow",
	"dust_white",
	"dust_black",
	"dust_silver"
]

const REQUIRED_ITEM_IDS = [
	"energy_crystal",
	"alloy",
	"moonblade_prototype",
	"dream_seed",
	"bot_scrap"
]

const REQUIRED_RECIPE_IDS = [
	"alloy_recipe",
	"moonblade_recipe"
]

const REQUIRED_LOCATION_IDS = [
	"enoks_kingdom_ridge",
	"makunas_shore",
	"greegion_ruins"
]

const REQUIRED_DUST_TYPES = [
	"Blue",
	"Green",
	"Red",
	"Orange",
	"Yellow",
	"White",
	"Black",
	"Silver"
]

const REQUIRED_DUST_MODIFIERS = {
	"dust_blue": {"stamina_regen": 0.10},
	"dust_green": {"health_regen": 0.08},
	"dust_red": {"damage_bonus": 0.10},
	"dust_orange": {"mining_speed": 0.12},
	"dust_yellow": {"move_speed": 0.08},
	"dust_white": {"shield_regen": 0.10},
	"dust_black": {"aggro_radius_multiplier": -0.10},
	"dust_silver": {"credit_gain_multiplier": 0.15}
}

var items_by_id: Dictionary = {}
var recipes_by_id: Dictionary = {}
var enemies_by_id: Dictionary = {}
var moons: Array = []
var locations_by_id: Dictionary = {}
var viewmodel_config: Dictionary = {}
var validation_errors: Array[String] = []
var validation_warnings: Array[String] = []

func load_all() -> bool:
	validation_errors.clear()
	validation_warnings.clear()

	var item_rows: Array = _load_array("items")
	var recipe_rows: Array = _load_array("recipes")
	var enemy_rows: Array = _load_array("enemies")
	var location_rows: Array = _load_array("locations")
	var viewmodel_dict: Dictionary = _load_dict("viewmodel")

	items_by_id = _index_by_id("items", item_rows)
	recipes_by_id = _index_by_id("recipes", recipe_rows)
	enemies_by_id = _index_by_id("enemies", enemy_rows)
	moons = _load_array("moons")
	locations_by_id = _index_by_id("locations", location_rows)
	viewmodel_config = viewmodel_dict

	_validate_items()
	_validate_recipes()
	_validate_enemies()
	_validate_moons()
	_validate_locations()
	_validate_viewmodel_config()
	_validate_cross_references()
	_emit_validation_report()
	return validation_errors.is_empty()

func get_item(item_id: String) -> Dictionary:
	return items_by_id.get(item_id, {})

func get_recipe(recipe_id: String) -> Dictionary:
	return recipes_by_id.get(recipe_id, {})

func get_enemy(enemy_id: String) -> Dictionary:
	return enemies_by_id.get(enemy_id, {})

func get_moons() -> Array:
	return moons.duplicate(true)

func get_location(location_id: String) -> Dictionary:
	return locations_by_id.get(location_id, {})

func get_all_recipes() -> Array:
	return recipes_by_id.values()

func get_all_items() -> Array:
	return items_by_id.values()

func get_all_locations() -> Array:
	return locations_by_id.values()

func get_viewmodel_config() -> Dictionary:
	return viewmodel_config.duplicate(true)

func get_validation_report() -> Dictionary:
	return {
		"ok": validation_errors.is_empty(),
		"errors": validation_errors.duplicate(),
		"warnings": validation_warnings.duplicate()
	}

func _load_array(key: String) -> Array:
	var path: String = DATA_FILES.get(key, "")
	if path.is_empty():
		_push_error("Unknown data key: %s" % key)
		return []
	if not FileAccess.file_exists(path):
		_push_error("Missing data file: %s" % path)
		return []
	var raw_text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(raw_text)
	if typeof(parsed) != TYPE_ARRAY:
		_push_error("Data file must contain a JSON array: %s" % path)
		return []
	return parsed

func _load_dict(key: String) -> Dictionary:
	var path: String = DATA_FILES.get(key, "")
	if path.is_empty():
		_push_error("Unknown data key: %s" % key)
		return {}
	if not FileAccess.file_exists(path):
		_push_error("Missing data file: %s" % path)
		return {}
	var raw_text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(raw_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_push_error("Data file must contain a JSON object: %s" % path)
		return {}
	return parsed

func _index_by_id(collection_name: String, entries: Array) -> Dictionary:
	var out: Dictionary = {}
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			_push_warning("Ignored non-dictionary row in %s." % collection_name)
			continue
		var id: String = str(entry.get("id", ""))
		if id.is_empty():
			_push_warning("Ignored row without id in %s." % collection_name)
			continue
		if out.has(id):
			_push_error("Duplicate id '%s' in %s." % [id, collection_name])
			continue
		out[id] = entry
	return out

func _validate_items() -> void:
	for item_id in REQUIRED_DUST_IDS:
		if not items_by_id.has(item_id):
			_push_error("Missing required dust item: %s" % item_id)
	for item_id in REQUIRED_ITEM_IDS:
		if not items_by_id.has(item_id):
			_push_error("Missing required item: %s" % item_id)

	for dust_id in REQUIRED_DUST_MODIFIERS.keys():
		var item: Dictionary = items_by_id.get(dust_id, {})
		if item.is_empty():
			continue
		var tags: Array = item.get("tags", [])
		if not tags.has("dust"):
			_push_error("Dust item '%s' must include 'dust' tag." % dust_id)
		var expected_modifier: Dictionary = REQUIRED_DUST_MODIFIERS[dust_id]
		var actual_modifier: Dictionary = item.get("modifier", {})
		for stat_key in expected_modifier.keys():
			if not actual_modifier.has(stat_key):
				_push_error("Dust item '%s' missing modifier '%s'." % [dust_id, stat_key])
				continue
			var expected_value: float = float(expected_modifier[stat_key])
			var actual_value: float = float(actual_modifier[stat_key])
			if abs(actual_value - expected_value) > 0.0001:
				_push_error(
					"Dust item '%s' modifier '%s' expected %.2f, got %.2f." %
					[dust_id, stat_key, expected_value, actual_value]
				)

func _validate_recipes() -> void:
	for recipe_id in REQUIRED_RECIPE_IDS:
		if not recipes_by_id.has(recipe_id):
			_push_error("Missing required recipe: %s" % recipe_id)

	for recipe_id in recipes_by_id.keys():
		var recipe: Dictionary = recipes_by_id[recipe_id]
		for key in ["ingredients", "outputs", "craft_time_sec"]:
			if not recipe.has(key):
				_push_error("Recipe '%s' missing field '%s'." % [recipe_id, key])
		var craft_time: float = float(recipe.get("craft_time_sec", 0.0))
		if craft_time <= 0.0:
			_push_error("Recipe '%s' craft_time_sec must be > 0." % recipe_id)

	var alloy_recipe: Dictionary = recipes_by_id.get("alloy_recipe", {})
	if not alloy_recipe.is_empty():
		var alloy_ingredients: Dictionary = alloy_recipe.get("ingredients", {})
		if int(alloy_ingredients.get("energy_crystal", 0)) < 1:
			_push_error("Recipe 'alloy_recipe' must require energy_crystal.")
		var alloy_special: Dictionary = alloy_recipe.get("special", {})
		if int(alloy_special.get("distinct_dust_count", 0)) < 2:
			_push_error("Recipe 'alloy_recipe' must require at least 2 distinct dust types.")
		var alloy_outputs: Dictionary = alloy_recipe.get("outputs", {})
		if int(alloy_outputs.get("alloy", 0)) < 1:
			_push_error("Recipe 'alloy_recipe' must output alloy.")

	var moonblade_recipe: Dictionary = recipes_by_id.get("moonblade_recipe", {})
	if not moonblade_recipe.is_empty():
		var moonblade_ingredients: Dictionary = moonblade_recipe.get("ingredients", {})
		for item_id in ["alloy", "energy_crystal", "dream_seed"]:
			if int(moonblade_ingredients.get(item_id, 0)) < 1:
				_push_error("Recipe 'moonblade_recipe' must require %s." % item_id)
		var moonblade_outputs: Dictionary = moonblade_recipe.get("outputs", {})
		if int(moonblade_outputs.get("moonblade_prototype", 0)) < 1:
			_push_error("Recipe 'moonblade_recipe' must output moonblade_prototype.")

func _validate_enemies() -> void:
	if not enemies_by_id.has("greegion_miner_bot"):
		_push_error("Missing required enemy: greegion_miner_bot")
	var required_fields: Array = [
		"max_hp",
		"move_speed",
		"attack_damage",
		"attack_cooldown",
		"aggro_range",
		"patrol_radius",
		"drops",
		"credit_reward"
	]
	for enemy_id in enemies_by_id.keys():
		var enemy: Dictionary = enemies_by_id[enemy_id]
		for field_name in required_fields:
			if not enemy.has(field_name):
				_push_error("Enemy '%s' missing field '%s'." % [enemy_id, field_name])

func _validate_moons() -> void:
	if moons.size() != 8:
		_push_error("moons.json must define exactly 8 moons, found %d." % moons.size())

	var seen_dust_types: Dictionary = {}
	for moon_def in moons:
		if typeof(moon_def) != TYPE_DICTIONARY:
			_push_error("moons.json contains non-dictionary row.")
			continue
		for key in ["id", "display_name", "dust_type", "color", "orbit_radius", "orbit_speed", "scale"]:
			if not moon_def.has(key):
				_push_error("Moon entry missing field '%s'." % key)

		var dust_type: String = str(moon_def.get("dust_type", ""))
		if not REQUIRED_DUST_TYPES.has(dust_type):
			_push_error("Moon '%s' has unsupported dust_type '%s'." % [moon_def.get("id", "?"), dust_type])
		elif seen_dust_types.has(dust_type):
			_push_error("Duplicate moon dust_type '%s' in moons.json." % dust_type)
		else:
			seen_dust_types[dust_type] = true

		var color_hex: String = str(moon_def.get("color", ""))
		if not Color.html_is_valid(color_hex):
			_push_error("Moon '%s' has invalid color '%s'." % [moon_def.get("id", "?"), color_hex])

	for dust_type in REQUIRED_DUST_TYPES:
		if not seen_dust_types.has(dust_type):
			_push_error("Missing moon definition for dust_type '%s'." % dust_type)

func _validate_locations() -> void:
	for location_id in REQUIRED_LOCATION_IDS:
		if not locations_by_id.has(location_id):
			_push_error("Missing required location: %s" % location_id)

	for location_id in locations_by_id.keys():
		var location: Dictionary = locations_by_id[location_id]
		for key in ["name", "position", "journal_title", "journal_text"]:
			if not location.has(key):
				_push_error("Location '%s' missing field '%s'." % [location_id, key])

func _validate_viewmodel_config() -> void:
	if viewmodel_config.is_empty():
		_push_warning("viewmodel.json is empty. First-person viewmodel will use script defaults.")
		return
	var actions: Dictionary = viewmodel_config.get("actions", {})
	for action_name in ["mine", "attack"]:
		if not actions.has(action_name):
			_push_warning("viewmodel.json missing actions.%s config." % action_name)

func _validate_cross_references() -> void:
	for recipe_id in recipes_by_id.keys():
		var recipe: Dictionary = recipes_by_id[recipe_id]
		var ingredients: Dictionary = recipe.get("ingredients", {})
		for item_id in ingredients.keys():
			if not items_by_id.has(item_id):
				_push_error("Recipe '%s' references missing ingredient '%s'." % [recipe_id, item_id])
		var outputs: Dictionary = recipe.get("outputs", {})
		for out_id in outputs.keys():
			if not items_by_id.has(out_id):
				_push_error("Recipe '%s' outputs unknown item '%s'." % [recipe_id, out_id])

	for enemy_id in enemies_by_id.keys():
		var enemy: Dictionary = enemies_by_id[enemy_id]
		var drops: Array = enemy.get("drops", [])
		for drop in drops:
			if typeof(drop) != TYPE_DICTIONARY:
				_push_error("Enemy '%s' drop row must be a dictionary." % enemy_id)
				continue
			var item_id: String = str(drop.get("item_id", ""))
			if item_id.is_empty() or not items_by_id.has(item_id):
				_push_error("Enemy '%s' drop references unknown item '%s'." % [enemy_id, item_id])

	for moon_def in moons:
		if typeof(moon_def) != TYPE_DICTIONARY:
			continue
		var dust_type: String = str(moon_def.get("dust_type", "")).to_lower()
		if dust_type.is_empty():
			continue
		var dust_item_id: String = "dust_%s" % dust_type
		if not items_by_id.has(dust_item_id):
			_push_warning(
				"Moon '%s' dust_type maps to missing item '%s'." %
				[moon_def.get("id", "?"), dust_item_id]
			)

func _emit_validation_report() -> void:
	for warning_text in validation_warnings:
		push_warning("[DataService] %s" % warning_text)
	for error_text in validation_errors:
		push_error("[DataService] %s" % error_text)
	if validation_errors.is_empty():
		print("[DataService] Validation passed (%d items, %d recipes, %d enemies)." % [
			items_by_id.size(),
			recipes_by_id.size(),
			enemies_by_id.size()
		])

func _push_warning(text: String) -> void:
	if not validation_warnings.has(text):
		validation_warnings.append(text)

func _push_error(text: String) -> void:
	if not validation_errors.has(text):
		validation_errors.append(text)
