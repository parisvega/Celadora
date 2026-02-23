extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var world_spawner: Node3D = $World/WorldSpawner

var _autosave_timer: float = 0.0
const AUTOSAVE_INTERVAL = 30.0
const QA_OBJECTIVE_FLAG: String = "qa_objective_auto"
const QA_OBJECTIVE_ORDER = [
	"collect_dust",
	"collect_energy",
	"salvage_bot",
	"forge_alloy",
	"unlock_lore",
	"acquire_dream_seed",
	"craft_moonblade",
	"prime_ruins_terminal"
]

func _ready() -> void:
	GameServices.bootstrap()
	if hud.has_method("set_player"):
		hud.set_player(player)

	var save_data: Dictionary = GameServices.save_service.get_loaded_state()
	var web_force_fresh_spawn: bool = OS.has_feature("web")
	if not web_force_fresh_spawn and save_data.has("player_state"):
		player.load_from_save(save_data["player_state"])
	else:
		player.global_position = Vector3(0.0, 8.0, 0.0)
		player.set_spawn_position(player.global_position)
	_ensure_safe_spawn()

	var welcome_hud = get_tree().get_first_node_in_group("hud")
	if welcome_hud:
		welcome_hud.push_message("Welcome to Celadora v0.1")

	if _is_web_query_flag_enabled(QA_OBJECTIVE_FLAG):
		call_deferred("_run_web_objective_flow_qa")

func _process(delta: float) -> void:
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		GameServices.save_now(player.to_save_data())

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		GameServices.save_now(player.to_save_data())

func _ensure_safe_spawn() -> void:
	if world_spawner == null or not world_spawner.has_method("get_surface_position"):
		return

	var pos: Vector3 = player.global_position
	if world_spawner.has_method("get_world_radius"):
		var radius: float = float(world_spawner.get_world_radius())
		if radius > 0.0:
			pos.x = clamp(pos.x, -radius * 0.95, radius * 0.95)
			pos.z = clamp(pos.z, -radius * 0.95, radius * 0.95)

	if is_nan(pos.x) or is_nan(pos.y) or is_nan(pos.z):
		pos = Vector3(0.0, 8.0, 0.0)

	var surface: Vector3 = world_spawner.get_surface_position(pos.x, pos.z)
	var min_safe_y: float = surface.y + 2.2
	var max_safe_y: float = surface.y + 30.0
	pos.y = clamp(pos.y, min_safe_y, max_safe_y)

	player.global_position = pos
	player.set_spawn_position(pos)

func _run_web_objective_flow_qa() -> void:
	var report: Dictionary = {
		"mode": "objective_flow",
		"started_at_unix": Time.get_unix_time_from_system(),
		"steps": [],
		"finished": false,
		"ok": false,
		"objective_count": QA_OBJECTIVE_ORDER.size(),
		"completed": 0
	}

	_reset_runtime_state_for_qa()
	await get_tree().process_frame

	var viewmodel_status: Dictionary = _collect_viewmodel_status_for_qa()
	report["viewmodel"] = viewmodel_status
	_append_qa_step(report, "viewmodel_visible", bool(viewmodel_status.get("ok", false)), viewmodel_status)

	GameServices.inventory_service.add_item("dust_blue", 1)
	_mark_objective_complete_if_ready("collect_dust")
	_append_qa_step(report, "collect_dust", _is_objective_complete("collect_dust"), {"added": "dust_blue"})

	GameServices.inventory_service.add_item("energy_crystal", 1)
	_mark_objective_complete_if_ready("collect_energy")
	_append_qa_step(report, "collect_energy", _is_objective_complete("collect_energy"), {"added": "energy_crystal"})

	GameServices.inventory_service.add_item("bot_scrap", 1)
	_mark_objective_complete_if_ready("salvage_bot")
	_append_qa_step(report, "salvage_bot", _is_objective_complete("salvage_bot"), {"added": "bot_scrap"})

	GameServices.inventory_service.add_item("dust_green", 1)
	GameServices.inventory_service.add_item("energy_crystal", 2)
	var alloy_result: Dictionary = GameServices.crafting_service.craft("alloy_recipe")
	_mark_objective_complete_if_ready("forge_alloy")
	_append_qa_step(report, "forge_alloy", _is_objective_complete("forge_alloy"), alloy_result)

	for location_id in ["enoks_kingdom_ridge", "makunas_shore", "greegion_ruins"]:
		GameServices.lore_journal_service.unlock_entry(location_id)
	_mark_objective_complete_if_ready("unlock_lore")
	_append_qa_step(report, "unlock_lore", _is_objective_complete("unlock_lore"), {
		"unlocked_count": GameServices.lore_journal_service.get_unlocked_ids().size()
	})

	GameServices.inventory_service.add_item("dream_seed", 1)
	_mark_objective_complete_if_ready("acquire_dream_seed")
	_append_qa_step(report, "acquire_dream_seed", _is_objective_complete("acquire_dream_seed"), {"added": "dream_seed"})

	GameServices.inventory_service.add_item("energy_crystal", 1)
	var moonblade_result: Dictionary = GameServices.crafting_service.craft("moonblade_recipe")
	_mark_objective_complete_if_ready("craft_moonblade")
	_append_qa_step(report, "craft_moonblade", _is_objective_complete("craft_moonblade"), moonblade_result)

	var terminal_result: Dictionary = {}
	var terminal: Node = get_node_or_null("World/GreegionRuins/Terminal")
	if terminal != null and terminal.has_method("interact"):
		terminal_result = terminal.interact(player)
	_mark_objective_complete_if_ready("prime_ruins_terminal")
	_append_qa_step(report, "prime_ruins_terminal", _is_objective_complete("prime_ruins_terminal"), terminal_result)

	var completed: int = 0
	var objective_states: Dictionary = {}
	for objective_id in QA_OBJECTIVE_ORDER:
		var done: bool = _is_objective_complete(objective_id)
		objective_states[objective_id] = done
		if done:
			completed += 1

	report["completed"] = completed
	report["objective_states"] = objective_states
	report["ok"] = completed >= QA_OBJECTIVE_ORDER.size() and bool(viewmodel_status.get("ok", false))
	report["finished"] = true
	report["ended_at_unix"] = Time.get_unix_time_from_system()
	_publish_web_qa_report(report)

func _collect_viewmodel_status_for_qa() -> Dictionary:
	var result: Dictionary = {
		"ok": false,
		"nodes_present": false,
		"visible_points": 0,
		"required_visible_points": 3,
		"left_visible": false,
		"right_visible": false,
		"details": []
	}
	var camera: Camera3D = player.get_node_or_null("Camera") as Camera3D
	var viewmodel: Node3D = player.get_node_or_null("Camera/ViewModelRig") as Node3D
	if camera == null or viewmodel == null:
		return result

	var point_nodes: Array[Node3D] = []
	for node_path in [
		"RigPivot/ArmLeft/ArmLeftMesh",
		"RigPivot/ArmRight/ArmRightMesh",
		"RigPivot/ArmLeft/HandLeftMesh",
		"RigPivot/ArmRight/HandRightMesh",
		"RigPivot/ArmRight/ToolPivot/ToolMesh"
	]:
		var node_3d: Node3D = viewmodel.get_node_or_null(node_path) as Node3D
		if node_3d != null:
			point_nodes.append(node_3d)
	result["nodes_present"] = point_nodes.size() >= 5
	if point_nodes.is_empty():
		return result

	var viewport_size: Vector2 = camera.get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return result

	var visible_points: int = 0
	var left_visible: bool = false
	var right_visible: bool = false
	var details: Array = []
	for node_3d in point_nodes:
		var point: Vector3 = node_3d.global_position
		var in_front: bool = not camera.is_position_behind(point)
		var screen: Vector2 = camera.unproject_position(point)
		var in_bounds: bool = (
			screen.x >= 0.0 and screen.x <= viewport_size.x and
			screen.y >= viewport_size.y * 0.38 and screen.y <= viewport_size.y
		)
		if in_front and in_bounds:
			visible_points += 1
			if node_3d.name.to_lower().contains("left"):
				left_visible = true
			if node_3d.name.to_lower().contains("right") or node_3d.name.to_lower().contains("tool"):
				right_visible = true
		details.append({
			"name": node_3d.name,
			"in_front": in_front,
			"in_bounds": in_bounds,
			"screen": [round(screen.x), round(screen.y)]
		})

	result["visible_points"] = visible_points
	result["left_visible"] = left_visible
	result["right_visible"] = right_visible
	result["details"] = details
	result["ok"] = bool(result.get("nodes_present", false)) and visible_points >= int(result.get("required_visible_points", 3)) and left_visible and right_visible
	return result

func _reset_runtime_state_for_qa() -> void:
	GameServices.inventory_service.clear()
	GameServices.lore_journal_service.set_unlocked_ids([])
	GameServices.marketplace_service.load_state({})
	GameServices.set_world_state({})
	player.global_position = Vector3(0.0, 8.0, 0.0)
	player.set_spawn_position(player.global_position)
	_ensure_safe_spawn()

func _append_qa_step(report: Dictionary, step_id: String, ok: bool, details: Dictionary = {}) -> void:
	var steps: Array = report.get("steps", [])
	steps.append({
		"id": step_id,
		"ok": ok,
		"details": details
	})
	report["steps"] = steps

func _objective_flag_key(objective_id: String) -> String:
	return "objective_%s_complete" % objective_id

func _mark_objective_complete_if_ready(objective_id: String) -> void:
	if _is_objective_complete(objective_id):
		GameServices.set_world_flag(_objective_flag_key(objective_id), true)

func _is_objective_complete(objective_id: String) -> bool:
	if GameServices.get_world_flag(_objective_flag_key(objective_id), false):
		return true
	match objective_id:
		"collect_dust":
			return _count_items_with_tag("dust") >= 1
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

func _count_items_with_tag(tag: String) -> int:
	var total: int = 0
	for row in GameServices.inventory_service.get_item_display_rows():
		var item_id: String = str(row.get("id", ""))
		var item_def: Dictionary = GameServices.get_item_def(item_id)
		var tags: Array = item_def.get("tags", [])
		if tags.has(tag):
			total += int(row.get("quantity", 0))
	return total

func _publish_web_qa_report(report: Dictionary) -> void:
	print("[WebQA] Objective flow result: %s" % JSON.stringify(report))
	if not OS.has_feature("web"):
		return
	if not ClassDB.class_exists("JavaScriptBridge"):
		return
	var report_json: String = JSON.stringify(report)
	JavaScriptBridge.eval("window.__celadoraObjectiveQa = " + report_json + ";", true)
	JavaScriptBridge.eval("window.__celadoraObjectiveQaReady = true;", true)
	JavaScriptBridge.eval("console.log('[CeladoraObjectiveQA]' + JSON.stringify(window.__celadoraObjectiveQa));", true)

func _is_web_query_flag_enabled(flag_id: String) -> bool:
	var params: Dictionary = _web_query_params()
	if not params.has(flag_id):
		return false
	var value: String = str(params.get(flag_id, "1")).to_lower()
	return value.is_empty() or value == "1" or value == "true" or value == "yes" or value == "on"

func _web_query_params() -> Dictionary:
	if not OS.has_feature("web"):
		return {}
	if not ClassDB.class_exists("JavaScriptBridge"):
		return {}
	var raw_search: Variant = JavaScriptBridge.eval("window.location.search", true)
	return _parse_query_string(str(raw_search))

func _parse_query_string(search: String) -> Dictionary:
	var out: Dictionary = {}
	var raw: String = search
	if raw.begins_with("?"):
		raw = raw.substr(1)
	for chunk in raw.split("&", false):
		if chunk.is_empty():
			continue
		var parts: PackedStringArray = chunk.split("=", false, 1)
		var key: String = parts[0].uri_decode()
		var value: String = "1"
		if parts.size() > 1:
			value = parts[1].uri_decode()
		if not key.is_empty():
			out[key] = value
	return out
