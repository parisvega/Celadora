extends CanvasLayer

@onready var damage_flash: ColorRect = $DamageFlash
@onready var top_atmosphere: ColorRect = $TopAtmosphere
@onready var top_edge: ColorRect = $TopEdge
@onready var stats_card: Panel = $StatsCard
@onready var stats_label: Label = $StatsLabel
@onready var hp_label: Label = $HPLabel
@onready var stamina_label: Label = $StaminaLabel
@onready var shield_label: Label = $ShieldLabel
@onready var hp_bar: ProgressBar = $HPBar
@onready var stamina_bar: ProgressBar = $StaminaBar
@onready var shield_bar: ProgressBar = $ShieldBar
@onready var compass_card: Panel = $CompassCard
@onready var compass_label: Label = $CompassLabel
@onready var message_card: Panel = $MessageCard
@onready var route_label: Label = $RouteLabel
@onready var target_status_label: Label = $TargetStatusLabel
@onready var target_status_card: Panel = $TargetStatusCard
@onready var objective_label: Label = $ObjectiveLabel
@onready var world_status_label: Label = $WorldStatusLabel
@onready var help_label: Label = $HelpLabel
@onready var message_label: Label = $MessageLabel
@onready var movement_label: Label = $MovementLabel
@onready var interaction_label: Label = $InteractionLabel
@onready var crosshair: Label = $Crosshair
@onready var crosshair_halo: ColorRect = $CrosshairHalo
@onready var bottom_hud_background: ColorRect = $BottomHUDBackground
@onready var route_strip_card: Panel = $RouteStripCard
@onready var objective_strip_card: Panel = $ObjectiveStripCard
@onready var world_strip_card: Panel = $WorldStripCard
@onready var interaction_strip_card: Panel = $InteractionStripCard
@onready var controls_card: Panel = $ControlsCard
@onready var inventory_panel: Panel = $InventoryPanel
@onready var objective_panel: Panel = $ObjectivePanel
@onready var crafting_panel: Panel = $CraftingPanel
@onready var lore_panel: Panel = $LoreJournalPanel
@onready var marketplace_panel: Panel = $MarketplacePanel
@onready var completion_panel: Panel = $CompletionPanel
@onready var completion_summary: RichTextLabel = $CompletionPanel/VBox/Summary
@onready var completion_meta: Label = $CompletionPanel/VBox/Meta
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
var _objective_sync_busy: bool = false
var _session_started_unix: float = 0.0
var _completion_panel_time_left: float = 0.0
var _ui_anim_time: float = 0.0
var _last_compact_mode: bool = false

const HUD_COLORS := {
	"cyan": Color(0.44, 0.93, 1.0, 1.0),
	"cyan_dim": Color(0.21, 0.44, 0.53, 1.0),
	"lime": Color(0.54, 0.94, 0.66, 1.0),
	"amber": Color(1.0, 0.76, 0.34, 1.0),
	"red": Color(1.0, 0.37, 0.43, 1.0),
	"ink": Color(0.03, 0.08, 0.13, 0.88),
	"ink_soft": Color(0.06, 0.12, 0.18, 0.68),
	"text": Color(0.91, 0.97, 1.0, 1.0),
	"text_muted": Color(0.71, 0.85, 0.92, 1.0)
}

const OBJECTIVE_ORDER = [
	"collect_dust",
	"collect_energy",
	"salvage_bot",
	"forge_alloy",
	"unlock_lore",
	"acquire_dream_seed",
	"craft_moonblade",
	"prime_ruins_terminal"
]

const OBJECTIVE_TITLES = {
	"collect_dust": "Collect any Moon Dust fragment",
	"collect_energy": "Collect an Energy Crystal",
	"salvage_bot": "Salvage Greegion Bot Scrap",
	"forge_alloy": "Craft Celadora Alloy",
	"unlock_lore": "Unlock all 3 lore markers",
	"acquire_dream_seed": "Acquire a Dream Seed at night",
	"craft_moonblade": "Craft Moonblade (Prototype)",
	"prime_ruins_terminal": "Prime the Greegion Ruins terminal"
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
	_session_started_unix = Time.get_unix_time_from_system()
	add_to_group("hud")
	_apply_hud_design_system()
	_apply_responsive_layout(true)
	crosshair.text = "+"
	help_label.text = "I Inventory  |  O Objectives  |  C Crafting  |  J Lore  |  M Market  |  E Interact  |  Left Click Swing (Mine/Attack)  |  F5 Save  |  F8 Time Skip  |  F9 Reset  |  F3 Debug"
	movement_label.text = "Movement: W/A/S/D Move  |  Shift Run  |  Space Jump  |  Mouse Look  |  Esc Cursor"
	compass_label.text = "Facing N"
	route_label.text = "Route: Initializing..."
	target_status_label.text = ""
	interaction_label.text = "Interact: Scan nearby node, terminal, or bot."
	objective_label.text = "Objective: Initializing..."
	world_status_label.text = "World: ..."
	debug_panel.visible = false
	debug_body.text = ""
	completion_panel.visible = false
	completion_summary.text = ""
	completion_meta.text = ""
	_set_all_panels_hidden()
	_cache_world_refs()

	GameServices.inventory_service.inventory_changed.connect(_on_inventory_changed)
	GameServices.inventory_service.credits_changed.connect(_on_credits_changed)
	GameServices.lore_journal_service.entry_unlocked.connect(_on_lore_entry_unlocked)
	GameServices.marketplace_service.listings_updated.connect(_on_market_updated)
	GameServices.crafting_service.crafted.connect(_on_item_crafted)
	GameServices.world_state_changed.connect(_on_world_state_changed)
	GameServices.world_state_reloaded.connect(_on_world_state_reloaded)

	_hydrate_objective_state_from_world_flags()
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
	if _player and _player.has_signal("interaction_target_changed"):
		_player.interaction_target_changed.connect(_on_interaction_target_changed)
	if _player and _player.has_signal("damaged"):
		_player.damaged.connect(_on_player_damaged)
	_update_stats_text()

func _process(delta: float) -> void:
	_ui_anim_time += delta
	if _message_time_left > 0.0:
		_message_time_left -= delta
		if _message_time_left <= 0.0:
			message_label.text = ""
	if _completion_panel_time_left > 0.0:
		_completion_panel_time_left -= delta
		if _completion_panel_time_left <= 0.0 and completion_panel.visible:
			completion_panel.visible = false

	if Input.is_action_just_pressed("toggle_inventory"):
		toggle_panel("inventory")
	if Input.is_action_just_pressed("toggle_objectives"):
		toggle_panel("objectives")
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
	_animate_hud(delta)
	_apply_responsive_layout(false)

func toggle_panel(name: String) -> void:
	match name:
		"inventory":
			inventory_panel.visible = not inventory_panel.visible
			if inventory_panel.visible and inventory_panel.has_method("refresh"):
				inventory_panel.refresh()
		"objectives":
			objective_panel.visible = not objective_panel.visible
			if objective_panel.visible and objective_panel.has_method("refresh"):
				objective_panel.refresh()
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

func _apply_hud_design_system() -> void:
	top_atmosphere.color = Color(0.03, 0.09, 0.15, 0.42)
	top_edge.color = Color(0.5, 0.94, 1.0, 0.35)
	bottom_hud_background.color = Color(0.01, 0.05, 0.1, 0.64)
	crosshair_halo.color = Color(0.52, 0.92, 1.0, 0.13)
	damage_flash.color = Color(1.0, 0.2, 0.24, 0.0)

	_style_panel(stats_card, HUD_COLORS["ink"], HUD_COLORS["cyan_dim"], 14.0)
	_style_panel(compass_card, Color(0.04, 0.1, 0.16, 0.84), HUD_COLORS["cyan_dim"], 14.0)
	_style_panel(message_card, Color(0.05, 0.1, 0.16, 0.86), Color(0.34, 0.68, 0.82, 0.45), 10.0)
	_style_panel(target_status_card, Color(0.04, 0.1, 0.16, 0.86), HUD_COLORS["cyan_dim"], 12.0)
	_style_panel(route_strip_card, Color(0.06, 0.15, 0.24, 0.84), Color(0.27, 0.66, 0.82, 0.45), 10.0)
	_style_panel(objective_strip_card, Color(0.05, 0.12, 0.2, 0.84), Color(0.24, 0.58, 0.76, 0.4), 10.0)
	_style_panel(world_strip_card, Color(0.05, 0.11, 0.18, 0.82), Color(0.2, 0.5, 0.7, 0.38), 10.0)
	_style_panel(interaction_strip_card, Color(0.05, 0.11, 0.18, 0.82), Color(0.2, 0.5, 0.7, 0.38), 10.0)
	_style_panel(controls_card, Color(0.04, 0.09, 0.16, 0.85), Color(0.2, 0.5, 0.7, 0.42), 10.0)
	_style_panel(debug_panel, Color(0.03, 0.08, 0.13, 0.94), HUD_COLORS["cyan_dim"], 12.0)
	_style_panel(completion_panel, Color(0.03, 0.08, 0.13, 0.95), Color(0.35, 0.78, 0.95, 0.6), 14.0)
	_style_progress_bar(hp_bar, HUD_COLORS["red"])
	_style_progress_bar(stamina_bar, HUD_COLORS["amber"])
	_style_progress_bar(shield_bar, HUD_COLORS["cyan"])

	_style_label(stats_label, HUD_COLORS["text"], 16, true)
	_style_label(compass_label, HUD_COLORS["text"], 16, true)
	_style_label(route_label, HUD_COLORS["cyan"], 15, true)
	_style_label(objective_label, HUD_COLORS["text"], 15, true)
	_style_label(world_status_label, HUD_COLORS["text_muted"], 14, false)
	_style_label(interaction_label, HUD_COLORS["lime"], 14, false)
	_style_label(help_label, HUD_COLORS["text_muted"], 14, false)
	_style_label(movement_label, HUD_COLORS["text_muted"], 14, false)
	_style_label(message_label, HUD_COLORS["text"], 15, false)
	_style_label(target_status_label, HUD_COLORS["text"], 14, true)
	_style_label(hp_label, HUD_COLORS["red"], 13, true)
	_style_label(stamina_label, HUD_COLORS["amber"], 13, true)
	_style_label(shield_label, HUD_COLORS["cyan"], 13, true)
	_style_label(crosshair, HUD_COLORS["cyan"], 28, true)
	_style_label(completion_meta, HUD_COLORS["text_muted"], 14, false)
	_style_label(get_node("CompletionPanel/VBox/Title") as Label, HUD_COLORS["cyan"], 22, true)
	debug_body.add_theme_color_override("default_color", HUD_COLORS["text"])
	completion_summary.add_theme_color_override("default_color", HUD_COLORS["text"])
	completion_summary.add_theme_font_size_override("normal_font_size", 17)

func _style_panel(panel: Panel, bg_color: Color, border_color: Color, corner_radius: float = 10.0) -> void:
	if panel == null:
		return
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = int(corner_radius)
	style.corner_radius_top_right = int(corner_radius)
	style.corner_radius_bottom_left = int(corner_radius)
	style.corner_radius_bottom_right = int(corner_radius)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	style.shadow_size = 4
	panel.add_theme_stylebox_override("panel", style)

func _style_progress_bar(bar: ProgressBar, fill_color: Color) -> void:
	if bar == null:
		return
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.02, 0.06, 0.09, 0.92)
	bg.corner_radius_top_left = 5
	bg.corner_radius_top_right = 5
	bg.corner_radius_bottom_left = 5
	bg.corner_radius_bottom_right = 5
	bg.border_color = Color(0.2, 0.35, 0.45, 0.55)
	bg.border_width_left = 1
	bg.border_width_top = 1
	bg.border_width_right = 1
	bg.border_width_bottom = 1

	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.corner_radius_top_left = 5
	fill.corner_radius_top_right = 5
	fill.corner_radius_bottom_left = 5
	fill.corner_radius_bottom_right = 5
	fill.shadow_color = fill_color * Color(1, 1, 1, 0.35)
	fill.shadow_size = 2

	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)

func _style_label(label: Label, font_color: Color, size: int, uppercase: bool) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_font_size_override("font_size", size)
	if uppercase:
		label.uppercase = true

func _set_all_panels_hidden() -> void:
	inventory_panel.visible = false
	objective_panel.visible = false
	crafting_panel.visible = false
	lore_panel.visible = false
	marketplace_panel.visible = false

func _refresh_all_panels() -> void:
	if inventory_panel.has_method("refresh"):
		inventory_panel.refresh()
	if objective_panel.has_method("refresh"):
		objective_panel.refresh()
	if crafting_panel.has_method("refresh"):
		crafting_panel.refresh()
	if lore_panel.has_method("refresh"):
		lore_panel.refresh()
	if marketplace_panel.has_method("refresh"):
		marketplace_panel.refresh()

func _update_stats_text() -> void:
	if _player == null:
		stats_label.text = ""
		hp_bar.value = 0.0
		stamina_bar.value = 0.0
		shield_bar.value = 0.0
		return
	var health = float(_player.get("health"))
	var stamina = float(_player.get("stamina"))
	var shield = float(_player.get("shield"))
	hp_bar.value = clamp(health, 0.0, hp_bar.max_value)
	stamina_bar.value = clamp(stamina, 0.0, stamina_bar.max_value)
	shield_bar.value = clamp(shield, 0.0, shield_bar.max_value)
	stats_label.text = "Vitals  |  HP %.0f  STA %.0f  SHD %.0f  |  Credits %d" % [
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
	if objective_panel.has_method("refresh"):
		objective_panel.refresh()
	_update_objectives(true)

func _on_credits_changed(_total: int) -> void:
	_update_stats_text()
	if marketplace_panel.has_method("refresh"):
		marketplace_panel.refresh()

func _on_lore_entry_unlocked(location_id: String) -> void:
	if lore_panel.has_method("refresh"):
		lore_panel.refresh()
	if objective_panel.has_method("refresh"):
		objective_panel.refresh()
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
	if objective_panel.has_method("refresh"):
		objective_panel.refresh()
	_update_objectives(true)

func _on_interaction_hint_changed(text: String) -> void:
	if text.is_empty():
		interaction_label.text = "Interact: Scan nearby node, terminal, or bot."
		_style_panel(interaction_strip_card, Color(0.05, 0.11, 0.18, 0.82), Color(0.2, 0.5, 0.7, 0.38), 10.0)
		return
	interaction_label.text = "Interact: %s" % text
	_style_panel(interaction_strip_card, Color(0.07, 0.16, 0.22, 0.9), Color(0.44, 0.93, 1.0, 0.52), 10.0)

func _on_interaction_target_changed(status: Dictionary) -> void:
	if status.is_empty():
		target_status_label.text = ""
		_style_panel(target_status_card, Color(0.04, 0.1, 0.16, 0.86), HUD_COLORS["cyan_dim"], 12.0)
		return
	var kind: String = str(status.get("type", ""))
	match kind:
		"resource":
			_style_panel(target_status_card, Color(0.06, 0.14, 0.2, 0.9), Color(0.44, 0.93, 1.0, 0.64), 12.0)
			target_status_label.text = "%s Integrity %d%%" % [
				str(status.get("name", "Resource")),
				int(round(float(status.get("progress_pct", 0.0))))
			]
		"enemy":
			_style_panel(target_status_card, Color(0.22, 0.08, 0.11, 0.9), Color(1.0, 0.42, 0.46, 0.7), 12.0)
			target_status_label.text = "%s HP %.0f/%.0f" % [
				str(status.get("name", "Enemy")),
				float(status.get("hp", 0.0)),
				float(status.get("hp_max", 0.0))
			]
		"terminal":
			_style_panel(target_status_card, Color(0.12, 0.11, 0.05, 0.9), Color(1.0, 0.78, 0.32, 0.64), 12.0)
			var state_text: String = str(status.get("state", "locked")).capitalize()
			var missing_count: int = int(status.get("requirements_missing", 0))
			if missing_count > 0:
				target_status_label.text = "%s %s (%d req missing)" % [
					str(status.get("name", "Terminal")),
					state_text,
					missing_count
				]
			else:
				target_status_label.text = "%s %s" % [
					str(status.get("name", "Terminal")),
					state_text
				]
		_:
			_style_panel(target_status_card, Color(0.04, 0.1, 0.16, 0.86), HUD_COLORS["cyan_dim"], 12.0)
			var action: String = str(status.get("action", ""))
			var name_text: String = str(status.get("name", "Target"))
			target_status_label.text = ("%s %s" % [action, name_text]).strip_edges()

func _update_objectives(announce: bool) -> void:
	_objective_sync_busy = true
	var completed_count: int = 0
	var newly_completed: Array[String] = []

	for objective_id in OBJECTIVE_ORDER:
		var runtime_complete: bool = _is_objective_complete(objective_id)
		var flag_key: String = _objective_flag_key(objective_id)
		var persisted_complete: bool = GameServices.get_world_flag(flag_key, false)
		var was_complete: bool = bool(_objective_state.get(objective_id, persisted_complete))
		var now_complete: bool = was_complete or persisted_complete or runtime_complete
		_objective_state[objective_id] = now_complete
		if now_complete:
			completed_count += 1
		if now_complete and not persisted_complete:
			GameServices.set_world_flag(flag_key, true)
		if announce and now_complete and not was_complete:
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
		_style_panel(objective_strip_card, Color(0.08, 0.2, 0.15, 0.9), Color(0.55, 0.94, 0.66, 0.62), 10.0)
		if announce and not _all_objectives_announced:
			push_message("All objectives complete: Celadora v0.1 secured.")
			_show_completion_panel()
		_all_objectives_announced = true
	else:
		_style_panel(objective_strip_card, Color(0.05, 0.12, 0.2, 0.84), Color(0.24, 0.58, 0.76, 0.4), 10.0)
		_all_objectives_announced = false
	_objective_sync_busy = false

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
		"prime_ruins_terminal":
			return GameServices.get_world_flag("ruins_terminal_primed", false)
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

func _objective_flag_key(objective_id: String) -> String:
	return "objective_%s_complete" % objective_id

func _hydrate_objective_state_from_world_flags() -> void:
	_objective_state.clear()
	for objective_id in OBJECTIVE_ORDER:
		_objective_state[objective_id] = GameServices.get_world_flag(_objective_flag_key(objective_id), false)

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
		route_label.text = "Route: waiting for player..."
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
	route_label.text = _build_route_text(nav, phase_text, dream_text)
	if phase_text == "Night":
		_style_panel(world_strip_card, Color(0.08, 0.08, 0.18, 0.86), Color(0.62, 0.74, 1.0, 0.42), 10.0)
	else:
		_style_panel(world_strip_card, Color(0.05, 0.11, 0.18, 0.82), Color(0.2, 0.5, 0.7, 0.38), 10.0)
	if bool(nav.get("unlocked", false)):
		_style_panel(route_strip_card, Color(0.08, 0.18, 0.14, 0.86), Color(0.55, 0.94, 0.66, 0.52), 10.0)
	else:
		_style_panel(route_strip_card, Color(0.06, 0.15, 0.24, 0.84), Color(0.27, 0.66, 0.82, 0.45), 10.0)

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
	var nav_name: String = str(current_nav.get("name", "No marker"))
	var nav_direction: String = str(current_nav.get("direction", "N"))
	var nav_distance: int = int(current_nav.get("distance_m", 0))
	var nav_state: String = "DONE" if bool(current_nav.get("unlocked", false)) else "NEW"
	var lore_progress: String = "%d/3" % GameServices.lore_journal_service.get_unlocked_ids().size()
	compass_label.text = "Facing %s  |  Next %s %s %dm (%s)  |  Lore %s" % [
		facing,
		nav_name,
		nav_direction,
		nav_distance,
		nav_state,
		lore_progress
	]

func _build_route_text(nav: Dictionary, phase_text: String, dream_text: String) -> String:
	var objective_id: String = _next_incomplete_objective_id()
	if objective_id.is_empty():
		return "Route: All objectives complete. Move to next roadmap milestones."

	match objective_id:
		"collect_dust":
			var dust_distance: float = _nearest_resource_distance("", true)
			if is_inf(dust_distance):
				return "Route: Locate any Moon Dust node and mine it."
			return "Route: Mine nearby Moon Dust (%dm)." % int(round(dust_distance))
		"collect_energy":
			var crystal_distance: float = _nearest_resource_distance("energy_crystal", false)
			if is_inf(crystal_distance):
				return "Route: Locate cyan Energy Crystal deposits."
			return "Route: Mine Energy Crystal node (%dm)." % int(round(crystal_distance))
		"salvage_bot":
			var enemy_distance: float = _nearest_distance_for_group("enemy_bot")
			if is_inf(enemy_distance):
				return "Route: Patrol for Greegion Miner Bots."
			return "Route: Engage nearest Greegion Miner Bot (%dm)." % int(round(enemy_distance))
		"forge_alloy":
			return "Route: Open Crafting (C) and forge Celadora Alloy."
		"unlock_lore":
			return "Route: Reach %s %dm %s." % [
				str(nav.get("name", "Lore marker")),
				int(nav.get("distance_m", 0)),
				str(nav.get("direction", "N"))
			]
		"acquire_dream_seed":
			if phase_text == "Night":
				return "Route: Night active. Locate Dream Keeper (%s)." % dream_text
			return "Route: Wait for night (or F8), then secure Dream Seed."
		"craft_moonblade":
			return "Route: Craft Moonblade (Prototype) in Crafting (C)."
		"prime_ruins_terminal":
			var ruins_distance: int = _distance_to_location("greegion_ruins")
			if ruins_distance < 0:
				return "Route: Reach Greegion Ruins terminal and prime protocol."
			return "Route: Prime Greegion Ruins terminal (%dm)." % ruins_distance
		_:
			return "Route: Continue objective progression."

func _next_incomplete_objective_id() -> String:
	for objective_id in OBJECTIVE_ORDER:
		if not bool(_objective_state.get(objective_id, false)):
			return objective_id
	return ""

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
	var resource_count: int = get_tree().get_nodes_in_group("resource_node").size()
	var enemy_count: int = get_tree().get_nodes_in_group("enemy_bot").size()
	var pickup_count: int = get_tree().get_nodes_in_group("pickup_item").size()
	var nearest_enemy: float = _nearest_distance_for_group("enemy_bot")
	var nearest_resource: float = _nearest_distance_for_group("resource_node")
	var nearest_pickup: float = _nearest_distance_for_group("pickup_item")

	lines.append("FPS: %d" % int(round(Engine.get_frames_per_second())))
	lines.append("Position: (%.1f, %.1f, %.1f)" % [
		_player.global_position.x,
		_player.global_position.y,
		_player.global_position.z
	])
	lines.append("Biome: %s" % biome_text)
	lines.append("Objective: %d/%d" % [objective_done, OBJECTIVE_ORDER.size()])
	lines.append("Lore unlocked: %d/3" % GameServices.lore_journal_service.get_unlocked_ids().size())
	lines.append("Spawns: resources %d | enemies %d | pickups %d" % [resource_count, enemy_count, pickup_count])
	lines.append("Nearest: enemy %s | resource %s | pickup %s" % [
		_distance_label(nearest_enemy),
		_distance_label(nearest_resource),
		_distance_label(nearest_pickup)
	])
	lines.append("Resource mix: %s" % _resource_mix_summary())
	lines.append("Dream keeper: %s" % dream_text)
	lines.append("Credits: %d" % GameServices.inventory_service.credits)
	lines.append("Fast-path: alloy %s | moonblade %s | terminal %s" % [
		_format_elapsed(_first_milestone_elapsed("crafting.recipe_crafted", "recipe_id", "alloy_recipe")),
		_format_elapsed(_first_milestone_elapsed("crafting.recipe_crafted", "recipe_id", "moonblade_recipe")),
		_format_elapsed(_first_milestone_elapsed("ruins.terminal_primed"))
	])
	var viewmodel_tool: String = "none"
	var viewmodel_node: Node = _player.get_node_or_null("Camera/ViewModelRig")
	if viewmodel_node != null and viewmodel_node.has_method("get_active_tool"):
		viewmodel_tool = str(viewmodel_node.get_active_tool())
	lines.append("Viewmodel tool: %s" % viewmodel_tool)
	if GameServices.event_log_service != null:
		var last_event: Dictionary = GameServices.event_log_service.get_last_event()
		lines.append("Events: %d" % GameServices.event_log_service.get_count())
		lines.append("Last event: %s" % str(last_event.get("type", "none")))
	debug_body.text = _join_parts(lines, "\n")

func _animate_hud(_delta: float) -> void:
	var route_pulse: float = 0.78 + 0.22 * (sin(_ui_anim_time * 2.6) * 0.5 + 0.5)
	route_label.modulate = Color(1.0, 1.0, 1.0, route_pulse)
	route_strip_card.modulate = Color(1.0, 1.0, 1.0, 0.88 + route_pulse * 0.12)

	var halo_strength: float = 0.09 + 0.08 * (sin(_ui_anim_time * 3.8) * 0.5 + 0.5)
	crosshair_halo.color = Color(0.52, 0.92, 1.0, halo_strength)
	var halo_size: float = 20.0 + (sin(_ui_anim_time * 3.8) * 2.4)
	crosshair_halo.offset_left = -halo_size
	crosshair_halo.offset_top = -halo_size
	crosshair_halo.offset_right = halo_size
	crosshair_halo.offset_bottom = halo_size

	if _message_time_left > 0.0:
		message_card.visible = true
		var fade: float = clamp(_message_time_left / 4.0, 0.15, 1.0)
		message_card.modulate = Color(1.0, 1.0, 1.0, 0.55 + fade * 0.45)
	else:
		message_card.modulate = Color(1.0, 1.0, 1.0, 0.34)

	if completion_panel.visible:
		var completion_pulse: float = 0.9 + 0.1 * (sin(_ui_anim_time * 2.2) * 0.5 + 0.5)
		completion_panel.modulate = Color(1.0, 1.0, 1.0, completion_pulse)

func _apply_responsive_layout(force: bool) -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var compact_mode: bool = viewport_size.x < 1140.0
	if not force and compact_mode == _last_compact_mode:
		return
	_last_compact_mode = compact_mode

	var main_font_size: int = 13 if compact_mode else 15
	var info_font_size: int = 12 if compact_mode else 14
	var small_font_size: int = 11 if compact_mode else 13

	for label in [route_label, objective_label]:
		label.add_theme_font_size_override("font_size", main_font_size)
	for label in [world_status_label, interaction_label, help_label, movement_label, target_status_label]:
		label.add_theme_font_size_override("font_size", info_font_size)
	for label in [hp_label, stamina_label, shield_label]:
		label.add_theme_font_size_override("font_size", small_font_size)
	stats_label.add_theme_font_size_override("font_size", 14 if compact_mode else 16)
	compass_label.add_theme_font_size_override("font_size", 14 if compact_mode else 16)
	message_label.add_theme_font_size_override("font_size", info_font_size)

	if compact_mode:
		bottom_hud_background.offset_top = -278.0
	else:
		bottom_hud_background.offset_top = -254.0

func _join_parts(parts: Array[String], separator: String) -> String:
	if parts.is_empty():
		return ""
	var joined: String = parts[0]
	for i in range(1, parts.size()):
		joined += separator + parts[i]
	return joined

func _nearest_distance_for_group(group_name: String) -> float:
	if _player == null:
		return INF
	var best: float = INF
	for node in get_tree().get_nodes_in_group(group_name):
		if not (node is Node3D):
			continue
		var node_3d: Node3D = node as Node3D
		var distance: float = _player.global_position.distance_to(node_3d.global_position)
		if distance < best:
			best = distance
	return best

func _nearest_resource_distance(item_id_filter: String, require_dust_tag: bool) -> float:
	if _player == null:
		return INF
	var best: float = INF
	for node in get_tree().get_nodes_in_group("resource_node"):
		if not (node is Node3D):
			continue
		var item_id: String = str(node.get("item_id"))
		if not item_id_filter.is_empty() and item_id != item_id_filter:
			continue
		if require_dust_tag:
			var item_def: Dictionary = GameServices.get_item_def(item_id)
			var tags: Array = item_def.get("tags", [])
			if not tags.has("dust"):
				continue
		var node_3d: Node3D = node as Node3D
		var distance: float = _player.global_position.distance_to(node_3d.global_position)
		if distance < best:
			best = distance
	return best

func _distance_to_location(location_id: String) -> int:
	if _player == null:
		return -1
	var location: Dictionary = GameServices.data_service.get_location(location_id)
	if location.is_empty():
		return -1
	var position_values: Array = location.get("position", [])
	if position_values.size() != 3:
		return -1
	var target: Vector3 = Vector3(
		float(position_values[0]),
		float(position_values[1]),
		float(position_values[2])
	)
	return int(round(Vector2(
		target.x - _player.global_position.x,
		target.z - _player.global_position.z
	).length()))

func _distance_label(value: float) -> String:
	if is_inf(value):
		return "n/a"
	return "%dm" % int(round(value))

func _resource_mix_summary(limit: int = 4) -> String:
	var counts: Dictionary = {}
	for node in get_tree().get_nodes_in_group("resource_node"):
		if not (node is Node):
			continue
		var item_id: String = str(node.get("item_id"))
		if item_id.is_empty():
			continue
		counts[item_id] = int(counts.get(item_id, 0)) + 1
	if counts.is_empty():
		return "none"

	var rows: Array[Dictionary] = []
	for item_id in counts.keys():
		rows.append({"item_id": item_id, "count": int(counts[item_id])})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["count"]) > int(b["count"]))

	var labels: Array[String] = []
	for i in range(min(limit, rows.size())):
		var row: Dictionary = rows[i]
		var item_id: String = str(row.get("item_id", "unknown"))
		var item_def: Dictionary = GameServices.get_item_def(item_id)
		var short_name: String = str(item_def.get("name", item_id))
		if short_name.ends_with(" Fragment"):
			short_name = short_name.replace(" Moon Dust Fragment", "")
		labels.append("%s:%d" % [short_name, int(row.get("count", 0))])
	return _join_parts(labels, ", ")

func _first_milestone_elapsed(event_type: String, payload_key: String = "", payload_value: String = "") -> float:
	if GameServices.event_log_service == null or not GameServices.event_log_service.has_method("get_all"):
		return -1.0
	for event_payload in GameServices.event_log_service.get_all():
		if typeof(event_payload) != TYPE_DICTIONARY:
			continue
		if str(event_payload.get("type", "")) != event_type:
			continue
		var timestamp: float = float(event_payload.get("timestamp_unix_sec", 0.0))
		if timestamp < _session_started_unix:
			continue
		if payload_key != "":
			var payload: Dictionary = event_payload.get("payload", {})
			if str(payload.get(payload_key, "")) != payload_value:
				continue
		return max(0.0, timestamp - _session_started_unix)
	return -1.0

func _format_elapsed(value: float) -> String:
	if value < 0.0:
		return "--"
	return "%.0fs" % value

func _show_completion_panel() -> void:
	if completion_panel == null:
		return
	completion_summary.text = _build_completion_summary()
	completion_meta.text = "Debrief auto-closes in 12s. Reopen objective checklist with O."
	completion_panel.visible = true
	_completion_panel_time_left = 12.0

func _build_completion_summary() -> String:
	var elapsed_sec: float = max(1.0, Time.get_unix_time_from_system() - _session_started_unix)
	var mined: int = _count_events("mining.node_mined")
	var crafted: int = _count_events("crafting.recipe_crafted")
	var defeated: int = _count_events("combat.enemy_defeated")
	var trades: int = _count_events("market.buy") + _count_events("market.sell")
	var lore_count: int = GameServices.lore_journal_service.get_unlocked_ids().size()
	var lines: Array[String] = []
	lines.append("Session %.0fs | Credits %d" % [elapsed_sec, GameServices.inventory_service.credits])
	lines.append("Mined %d nodes | Crafted %d recipes | Defeated %d bots | Trades %d" % [mined, crafted, defeated, trades])
	lines.append("Lore unlocked %d/3 | Ruins terminal primed: %s" % [
		lore_count,
		"yes" if GameServices.get_world_flag("ruins_terminal_primed", false) else "no"
	])
	lines.append("")
	lines.append("Next: dedicated server authority + Nakama seams + anti-cheat economy path.")
	return _join_parts(lines, "\n")

func _count_events(event_type: String) -> int:
	if GameServices.event_log_service == null:
		return 0
	var total: int = 0
	for event_payload in GameServices.event_log_service.get_all():
		if typeof(event_payload) != TYPE_DICTIONARY:
			continue
		if str(event_payload.get("type", "")) == event_type:
			total += 1
	return total

func _on_player_damaged(amount: float) -> void:
	_damage_flash_alpha = clamp(_damage_flash_alpha + (0.12 + amount * 0.01), 0.0, 0.52)
	_update_damage_flash(0.0)

func _on_world_state_changed(_flag_id: String, _value: Variant) -> void:
	if _objective_sync_busy:
		return
	if objective_panel.has_method("refresh"):
		objective_panel.refresh()
	_update_objectives(true)

func _on_world_state_reloaded(_state: Dictionary) -> void:
	_hydrate_objective_state_from_world_flags()
	if objective_panel.has_method("refresh"):
		objective_panel.refresh()
	completion_panel.visible = false
	_completion_panel_time_left = 0.0
	_update_objectives(false)

func _update_damage_flash(delta: float) -> void:
	_damage_flash_alpha = max(_damage_flash_alpha - delta * 1.8, 0.0)
	var color = damage_flash.color
	color.a = _damage_flash_alpha
	damage_flash.color = color

func _get_navigation_status() -> Dictionary:
	var best_locked: Dictionary = {}
	var best_locked_distance: float = INF
	var best_any: Dictionary = {}
	var best_any_distance: float = INF

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
		var marker_status: Dictionary = {
			"id": location_id,
			"name": LOCATION_SHORT_NAMES.get(location_id, location.get("name", location_id)),
			"distance_m": int(round(distance)),
			"direction": _cardinal_from_delta(planar_delta),
			"unlocked": GameServices.lore_journal_service.is_unlocked(location_id)
		}
		if distance < best_any_distance:
			best_any_distance = distance
			best_any = marker_status
		if not bool(marker_status.get("unlocked", false)) and distance < best_locked_distance:
			best_locked_distance = distance
			best_locked = marker_status

	var best: Dictionary = best_locked if not best_locked.is_empty() else best_any
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
