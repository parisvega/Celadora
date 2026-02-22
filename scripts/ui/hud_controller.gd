extends CanvasLayer

@onready var damage_flash: ColorRect = $DamageFlash
@onready var stats_label: Label = $StatsLabel
@onready var compass_label: Label = $CompassLabel
@onready var objective_label: Label = $ObjectiveLabel
@onready var world_status_label: Label = $WorldStatusLabel
@onready var help_label: Label = $HelpLabel
@onready var message_label: Label = $MessageLabel
@onready var movement_label: Label = $MovementLabel
@onready var interaction_label: Label = $InteractionLabel
@onready var crosshair: Label = $Crosshair
@onready var inventory_panel: Panel = $InventoryPanel
@onready var crafting_panel: Panel = $CraftingPanel
@onready var lore_panel: Panel = $LoreJournalPanel
@onready var marketplace_panel: Panel = $MarketplacePanel
@onready var debug_panel: Panel = $DebugPanel
@onready var debug_body: RichTextLabel = $DebugPanel/DebugVBox/DebugBody

var _player: Node = null
var _message_time_left: float = 0.0
var _objective_state: Dictionary = {}
var _last_world_status_refresh: float = 0.0
var _day_night_cycle: Node = null
var _world_spawner: Node = null
var _dream_keeper_spawner: Node = null
var _damage_flash_alpha: float = 0.0
var _all_objectives_announced: bool = false
var _debug_overlay_visible: bool = false
var _debug_refresh_left: float = 0.0

const OBJECTIVE_ORDER = [
	"collect_dust",
	"collect_energy",
	"salvage_bot",
	"forge_alloy",
	"unlock_lore",
	"acquire_dream_seed",
	"craft_moonblade"
]

const OBJECTIVE_TITLES = {
	"collect_dust": "Collect any Moon Dust fragment",
	"collect_energy": "Collect an Energy Crystal",
	"salvage_bot": "Salvage Greegion Bot Scrap",
	"forge_alloy": "Craft Celadora Alloy",
	"unlock_lore": "Unlock all 3 lore markers",
	"acquire_dream_seed": "Acquire a Dream Seed at night",
	"craft_moonblade": "Craft Moonblade (Prototype)"
}

const LORE_ROUTE = [
	"enoks_kingdom_ridge",
	"makunas_shore",
	"greegion_ruins"
]

const LOCATION_SHORT_NAMES = {
	"enoks_kingdom_ridge": "Enok Ridge",
	"makunas_shore": "Makuna Shore",
	"greegion_ruins": "Greegion Ruins"
}

func _ready() -> void:
	add_to_group("hud")
	crosshair.text = "+"
	help_label.text = "I Inventory  |  C Crafting  |  J Lore  |  M Market  |  E Interact  |  Left Click Mine/Attack  |  F5 Save  |  F9 Reset  |  F3 Debug"
	movement_label.text = "Movement: W/A/S/D Move  |  Shift Run  |  Space Jump  |  Mouse Look  |  Esc Cursor"
	compass_label.text = "Facing N"
	objective_label.text = "Objective: Initializing..."
	world_status_label.text = "World: ..."
	debug_panel.visible = false
	debug_body.text = ""
	_set_all_panels_hidden()
	_cache_world_refs()

	GameServices.inventory_service.inventory_changed.connect(_on_inventory_changed)
	GameServices.inventory_service.credits_changed.connect(_on_credits_changed)
	GameServices.lore_journal_service.entry_unlocked.connect(_on_lore_entry_unlocked)
	GameServices.marketplace_service.listings_updated.connect(_on_market_updated)
	GameServices.crafting_service.crafted.connect(_on_item_crafted)

	_refresh_all_panels()
	_update_objectives(false)
	_update_world_status(1.0)
	push_message("Systems online.")
	_show_data_validation_state()
	_update_damage_flash(0.0)

func set_player(player: Node) -> void:
	_player = player
	if _player and _player.has_signal("stats_updated"):
		_player.stats_updated.connect(_on_player_stats_updated)
	if _player and _player.has_signal("interaction_hint_changed"):
		_player.interaction_hint_changed.connect(_on_interaction_hint_changed)
	if _player and _player.has_signal("damaged"):
		_player.damaged.connect(_on_player_damaged)
	_update_stats_text()

func _process(delta: float) -> void:
	if _message_time_left > 0.0:
		_message_time_left -= delta
		if _message_time_left <= 0.0:
			message_label.text = ""

	if Input.is_action_just_pressed("toggle_inventory"):
		toggle_panel("inventory")
	if Input.is_action_just_pressed("toggle_crafting"):
		toggle_panel("crafting")
	if Input.is_action_just_pressed("toggle_journal"):
		toggle_panel("lore")
	if Input.is_action_just_pressed("toggle_market"):
		toggle_panel("market")
	if Input.is_action_just_pressed("toggle_debug"):
		_toggle_debug_overlay()

	_update_stats_text()
	_update_world_status(delta)
	_update_damage_flash(delta)
	_update_debug_overlay(delta)

func toggle_panel(name: String) -> void:
	match name:
		"inventory":
			inventory_panel.visible = not inventory_panel.visible
			if inventory_panel.visible and inventory_panel.has_method("refresh"):
				inventory_panel.refresh()
		"crafting":
			crafting_panel.visible = not crafting_panel.visible
			if crafting_panel.visible and crafting_panel.has_method("refresh"):
				crafting_panel.refresh()
		"lore":
			lore_panel.visible = not lore_panel.visible
			if lore_panel.visible and lore_panel.has_method("refresh"):
				lore_panel.refresh()
		"market":
			marketplace_panel.visible = not marketplace_panel.visible
			if marketplace_panel.visible and marketplace_panel.has_method("refresh"):
				marketplace_panel.refresh()

func push_message(text: String) -> void:
	message_label.text = text
	_message_time_left = 4.0

func _set_all_panels_hidden() -> void:
	inventory_panel.visible = false
	crafting_panel.visible = false
	lore_panel.visible = false
	marketplace_panel.visible = false

func _refresh_all_panels() -> void:
	if inventory_panel.has_method("refresh"):
		inventory_panel.refresh()
	if crafting_panel.has_method("refresh"):
		crafting_panel.refresh()
	if lore_panel.has_method("refresh"):
		lore_panel.refresh()
	if marketplace_panel.has_method("refresh"):
		marketplace_panel.refresh()

func _update_stats_text() -> void:
	if _player == null:
		stats_label.text = ""
		return
	var health = float(_player.get("health"))
	var stamina = float(_player.get("stamina"))
	var shield = float(_player.get("shield"))
	stats_label.text = "HP %.0f | STA %.0f | SHD %.0f | CR %d" % [
		health,
		stamina,
		shield,
		GameServices.inventory_service.credits
	]

func _on_player_stats_updated() -> void:
	_update_stats_text()

func _on_inventory_changed() -> void:
	if inventory_panel.has_method("refresh"):
		inventory_panel.refresh()
	_update_objectives(true)

func _on_credits_changed(_total: int) -> void:
	_update_stats_text()
	if marketplace_panel.has_method("refresh"):
		marketplace_panel.refresh()

func _on_lore_entry_unlocked(location_id: String) -> void:
	if lore_panel.has_method("refresh"):
		lore_panel.refresh()
	var location = GameServices.data_service.get_location(location_id)
	push_message("Journal entry added: %s" % location.get("name", location_id))
	_update_objectives(true)

func _on_market_updated() -> void:
	if marketplace_panel.has_method("refresh"):
		marketplace_panel.refresh()

func _on_item_crafted(recipe_id: String, _outputs: Dictionary) -> void:
	var recipe = GameServices.data_service.get_recipe(recipe_id)
	push_message("Crafted: %s" % recipe.get("name", recipe_id))
	if inventory_panel.has_method("refresh"):
		inventory_panel.refresh()
	_update_objectives(true)

func _on_interaction_hint_changed(text: String) -> void:
	interaction_label.text = text

func _update_objectives(announce: bool) -> void:
	var completed_count: int = 0
	var newly_completed: Array[String] = []

	for objective_id in OBJECTIVE_ORDER:
		var is_complete: bool = _is_objective_complete(objective_id)
		var was_complete: bool = bool(_objective_state.get(objective_id, false))
		_objective_state[objective_id] = is_complete
		if is_complete:
			completed_count += 1
		if announce and is_complete and not was_complete:
			newly_completed.append(objective_id)

	for objective_id in newly_completed:
		var title: String = str(OBJECTIVE_TITLES.get(objective_id, objective_id))
		push_message("Objective complete: %s" % title)

	var next_objective: String = "All v0.1 objectives complete."
	for objective_id in OBJECTIVE_ORDER:
		if not bool(_objective_state.get(objective_id, false)):
			next_objective = str(OBJECTIVE_TITLES.get(objective_id, objective_id))
			break

	objective_label.text = "Objective %d/%d: %s" % [completed_count, OBJECTIVE_ORDER.size(), next_objective]
	if completed_count >= OBJECTIVE_ORDER.size():
		if announce and not _all_objectives_announced:
			push_message("All objectives complete: Celadora v0.1 secured.")
		_all_objectives_announced = true
	else:
		_all_objectives_announced = false

func _is_objective_complete(objective_id: String) -> bool:
	match objective_id:
		"collect_dust":
			return _get_item_count_by_tag("dust") >= 1
		"collect_energy":
			return GameServices.inventory_service.get_quantity("energy_crystal") >= 1
		"salvage_bot":
			return GameServices.inventory_service.get_quantity("bot_scrap") >= 1
		"forge_alloy":
			return GameServices.inventory_service.get_quantity("alloy") >= 1
		"unlock_lore":
			return GameServices.lore_journal_service.get_unlocked_ids().size() >= 3
		"acquire_dream_seed":
			return GameServices.inventory_service.get_quantity("dream_seed") >= 1
		"craft_moonblade":
			return GameServices.inventory_service.get_quantity("moonblade_prototype") >= 1
		_:
			return false

func _get_item_count_by_tag(tag: String) -> int:
	var total: int = 0
	for row in GameServices.inventory_service.get_item_display_rows():
		var item_id: String = str(row.get("id", ""))
		var item_def: Dictionary = GameServices.get_item_def(item_id)
		var tags: Array = item_def.get("tags", [])
		if tags.has(tag):
			total += int(row.get("quantity", 0))
	return total

func _cache_world_refs() -> void:
	_day_night_cycle = get_tree().get_first_node_in_group("day_night")
	_world_spawner = get_tree().get_first_node_in_group("world_spawner")
	_dream_keeper_spawner = get_tree().get_first_node_in_group("dream_keeper_spawner")

func _update_world_status(delta: float) -> void:
	_last_world_status_refresh += delta
	if _last_world_status_refresh < 0.2:
		return
	_last_world_status_refresh = 0.0

	if _player == null:
		world_status_label.text = "World: waiting for player..."
		return
	if _day_night_cycle == null or _world_spawner == null or _dream_keeper_spawner == null:
		_cache_world_refs()

	var time_of_day: float = 0.0
	var phase_text: String = "Day"
	var dream_text: String = "Dormant"
	if _day_night_cycle != null:
		time_of_day = float(_day_night_cycle.get("time_of_day"))
		var is_night: bool = false
		if _day_night_cycle.has_method("is_night"):
			is_night = bool(_day_night_cycle.is_night())
		else:
			is_night = (time_of_day < 6.0 or time_of_day >= 18.0)
		phase_text = "Night" if is_night else "Day"
		dream_text = "Active" if is_night else "Dormant"

	if _dream_keeper_spawner != null and _dream_keeper_spawner.has_method("get_status"):
		var dream_status: Dictionary = _dream_keeper_spawner.get_status()
		var dream_night: bool = bool(dream_status.get("is_night", phase_text == "Night"))
		var dream_active: bool = bool(dream_status.get("active", false))
		var dream_eta: float = float(dream_status.get("eta_sec", -1.0))
		if not dream_night:
			dream_text = "Dormant"
		elif dream_active:
			dream_text = "Present"
		elif dream_eta >= 0.0:
			dream_text = "ETA %ds" % int(ceil(dream_eta))
		else:
			dream_text = "Searching"

	var biome_text: String = "Unknown"
	if _world_spawner != null and _world_spawner.has_method("get_biome_name_at_position"):
		biome_text = str(_world_spawner.get_biome_name_at_position(
			_player.global_position.x,
			_player.global_position.z
		))

	var nav: Dictionary = _get_navigation_status()
	var target_text: String = str(nav.get("name", "Unknown"))
	var target_distance: int = int(nav.get("distance_m", 0))
	var target_direction: String = str(nav.get("direction", "N"))
	var target_state: String = "DONE" if bool(nav.get("unlocked", false)) else "NEW"
	_update_compass_text(nav)

	world_status_label.text = "Target %s %dm %s (%s)  |  Pos %.0f,%.0f  |  %s %.1fh  |  %s  |  Dream %s" % [
		target_text,
		target_distance,
		target_direction,
		target_state,
		_player.global_position.x,
		_player.global_position.z,
		phase_text,
		time_of_day,
		biome_text,
		dream_text
	]

func _show_data_validation_state() -> void:
	var report: Dictionary = GameServices.get_data_validation_report()
	var errors: Array = report.get("errors", [])
	var warnings: Array = report.get("warnings", [])
	if not bool(report.get("ok", true)):
		push_message("Data validation errors detected. Check console output.")
		return
	if warnings.size() > 0:
		push_message("Data loaded with warnings.")

func _update_compass_text(current_nav: Dictionary) -> void:
	if _player == null:
		compass_label.text = "Facing N"
		return

	var forward: Vector3 = -_player.global_transform.basis.z
	var facing: String = _cardinal_from_delta(Vector2(forward.x, forward.z))

	var parts: Array[String] = []
	parts.append("Facing %s" % facing)
	for location_id in LORE_ROUTE:
		var location: Dictionary = GameServices.data_service.get_location(location_id)
		if location.is_empty():
			continue
		var position_values: Array = location.get("position", [])
		if position_values.size() != 3:
			continue
		var target: Vector3 = Vector3(
			float(position_values[0]),
			float(position_values[1]),
			float(position_values[2])
		)
		var planar_delta: Vector2 = Vector2(
			target.x - _player.global_position.x,
			target.z - _player.global_position.z
		)
		var direction: String = _cardinal_from_delta(planar_delta)
		var distance_m: int = int(round(planar_delta.length()))
		var is_unlocked: bool = GameServices.lore_journal_service.is_unlocked(location_id)
		var marker_state: String = "DONE" if is_unlocked else "NEW"
		parts.append("%s %s %dm %s" % [
			str(LOCATION_SHORT_NAMES.get(location_id, location_id)),
			direction,
			distance_m,
			marker_state
		])

	if current_nav.has("id"):
		var nav_id: String = str(current_nav.get("id", ""))
		if nav_id != "none":
			parts.append("Nearest %s" % str(current_nav.get("name", nav_id)))

	compass_label.text = _join_parts(parts, "  |  ")

func _toggle_debug_overlay() -> void:
	_debug_overlay_visible = not _debug_overlay_visible
	debug_panel.visible = _debug_overlay_visible
	if _debug_overlay_visible:
		_debug_refresh_left = 0.0
		push_message("Debug overlay enabled.")
	else:
		push_message("Debug overlay disabled.")

func _update_debug_overlay(delta: float) -> void:
	if not _debug_overlay_visible:
		return
	_debug_refresh_left -= delta
	if _debug_refresh_left > 0.0:
		return
	_debug_refresh_left = 0.2
	if _player == null:
		debug_body.text = "Waiting for player..."
		return

	var objective_done: int = 0
	for objective_id in OBJECTIVE_ORDER:
		if bool(_objective_state.get(objective_id, false)):
			objective_done += 1

	var dream_text: String = "n/a"
	if _dream_keeper_spawner != null and _dream_keeper_spawner.has_method("get_status"):
		var dream_status: Dictionary = _dream_keeper_spawner.get_status()
		if bool(dream_status.get("active", false)):
			dream_text = "present"
		elif bool(dream_status.get("is_night", false)):
			var eta: float = float(dream_status.get("eta_sec", -1.0))
			dream_text = "eta %ds" % int(max(0.0, eta))
		else:
			dream_text = "dormant"

	var biome_text: String = "Unknown"
	if _world_spawner != null and _world_spawner.has_method("get_biome_name_at_position"):
		biome_text = str(_world_spawner.get_biome_name_at_position(
			_player.global_position.x,
			_player.global_position.z
		))

	var lines: Array[String] = []
	lines.append("FPS: %d" % int(round(Engine.get_frames_per_second())))
	lines.append("Position: (%.1f, %.1f, %.1f)" % [
		_player.global_position.x,
		_player.global_position.y,
		_player.global_position.z
	])
	lines.append("Biome: %s" % biome_text)
	lines.append("Objective: %d/%d" % [objective_done, OBJECTIVE_ORDER.size()])
	lines.append("Lore unlocked: %d/3" % GameServices.lore_journal_service.get_unlocked_ids().size())
	lines.append("Dream keeper: %s" % dream_text)
	lines.append("Credits: %d" % GameServices.inventory_service.credits)
	debug_body.text = _join_parts(lines, "\n")

func _join_parts(parts: Array[String], separator: String) -> String:
	if parts.is_empty():
		return ""
	var joined: String = parts[0]
	for i in range(1, parts.size()):
		joined += separator + parts[i]
	return joined

func _on_player_damaged(amount: float) -> void:
	_damage_flash_alpha = clamp(_damage_flash_alpha + (0.12 + amount * 0.01), 0.0, 0.52)
	_update_damage_flash(0.0)

func _update_damage_flash(delta: float) -> void:
	_damage_flash_alpha = max(_damage_flash_alpha - delta * 1.8, 0.0)
	var color = damage_flash.color
	color.a = _damage_flash_alpha
	damage_flash.color = color

func _get_navigation_status() -> Dictionary:
	var best: Dictionary = {}
	var best_distance: float = INF

	for location_id in LORE_ROUTE:
		var location: Dictionary = GameServices.data_service.get_location(location_id)
		if location.is_empty():
			continue
		var position_values: Array = location.get("position", [])
		if position_values.size() != 3:
			continue

		var target = Vector3(
			float(position_values[0]),
			float(position_values[1]),
			float(position_values[2])
		)
		var planar_delta = Vector2(
			target.x - _player.global_position.x,
			target.z - _player.global_position.z
		)
		var distance: float = planar_delta.length()
		if distance < best_distance:
			best_distance = distance
			best = {
				"id": location_id,
				"name": LOCATION_SHORT_NAMES.get(location_id, location.get("name", location_id)),
				"distance_m": int(round(distance)),
				"direction": _cardinal_from_delta(planar_delta),
				"unlocked": GameServices.lore_journal_service.is_unlocked(location_id)
			}

	if best.is_empty():
		return {
			"id": "none",
			"name": "No marker",
			"distance_m": 0,
			"direction": "N",
			"unlocked": false
		}
	return best

func _cardinal_from_delta(delta: Vector2) -> String:
	if delta.length() < 0.1:
		return "Here"
	var angle: float = atan2(delta.x, -delta.y)
	var octant: int = int(round(angle / (PI / 4.0))) % 8
	if octant < 0:
		octant += 8
	var names: Array[String] = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	return names[octant]
