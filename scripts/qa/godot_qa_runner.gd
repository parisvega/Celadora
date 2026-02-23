extends SceneTree

var _checks: Array[Dictionary] = []
var _started_at: String = ""
var _ended_at: String = ""

func _initialize() -> void:
	_started_at = Time.get_datetime_string_from_system(true)
	call_deferred("_run")

func _run() -> void:
	await _run_checks()
	_ended_at = Time.get_datetime_string_from_system(true)
	var summary: Dictionary = _summary()
	var report: Dictionary = {
		"started_at": _started_at,
		"ended_at": _ended_at,
		"checks": _checks,
		"summary": summary
	}
	_write_reports(report)
	quit(0 if int(summary.get("failed", 0)) == 0 else 2)

func _run_checks() -> void:
	var main_scene_res: PackedScene = load("res://scenes/Main.tscn")
	_add_check("main_scene_loads", main_scene_res != null, {"path": "res://scenes/Main.tscn"}, "critical")
	if main_scene_res == null:
		return

	var main: Node = main_scene_res.instantiate()
	root.add_child(main)
	for _i in range(10):
		await process_frame

	var player: Node = main.get_node_or_null("Player")
	var world: Node = main.get_node_or_null("World")
	var hud: Node = main.get_node_or_null("HUD")
	_add_check("main_nodes_present", player != null and world != null and hud != null, {
		"player": player != null,
		"world": world != null,
		"hud": hud != null
	}, "critical")
	if player == null:
		return

	var camera: Camera3D = player.get_node_or_null("Camera") as Camera3D
	var viewmodel: Node3D = player.get_node_or_null("Camera/ViewModelRig") as Node3D
	_add_check("camera_and_viewmodel_present", camera != null and viewmodel != null, {
		"camera": camera != null,
		"viewmodel": viewmodel != null
	}, "critical")

	if camera != null:
		var cull_mask_ok: bool = (camera.cull_mask & 2) != 0
		_add_check("camera_renders_viewmodel_layer", cull_mask_ok, {"cull_mask": camera.cull_mask}, "critical")

	if viewmodel != null:
		var arm_left: MeshInstance3D = viewmodel.get_node_or_null("RigPivot/ArmLeft/ArmLeftMesh") as MeshInstance3D
		var arm_right: MeshInstance3D = viewmodel.get_node_or_null("RigPivot/ArmRight/ArmRightMesh") as MeshInstance3D
		var hand_left: MeshInstance3D = viewmodel.get_node_or_null("RigPivot/ArmLeft/HandLeftMesh") as MeshInstance3D
		var hand_right: MeshInstance3D = viewmodel.get_node_or_null("RigPivot/ArmRight/HandRightMesh") as MeshInstance3D
		var tool_mesh: MeshInstance3D = viewmodel.get_node_or_null("RigPivot/ArmRight/ToolPivot/ToolMesh") as MeshInstance3D

		var mesh_ok: bool = (
			arm_left != null and arm_left.mesh != null and
			arm_right != null and arm_right.mesh != null and
			hand_left != null and hand_left.mesh != null and
			hand_right != null and hand_right.mesh != null and
			tool_mesh != null and tool_mesh.mesh != null
		)
		_add_check("viewmodel_meshes_ready", mesh_ok, {
			"arm_left": arm_left != null,
			"arm_right": arm_right != null,
			"hand_left": hand_left != null,
			"hand_right": hand_right != null,
			"tool_mesh": tool_mesh != null
		}, "critical")

		if tool_mesh != null and tool_mesh.material_override is StandardMaterial3D:
			var material: StandardMaterial3D = tool_mesh.material_override as StandardMaterial3D
			_add_check("viewmodel_unshaded_material", material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, {
				"shading_mode": material.shading_mode
			}, "critical")
		else:
			_add_check("viewmodel_unshaded_material", false, {"reason": "tool material missing"}, "critical")

		if viewmodel.has_method("get_active_tool"):
			_add_check("viewmodel_has_active_tool", str(viewmodel.call("get_active_tool")) != "", {
				"active_tool": str(viewmodel.call("get_active_tool"))
			}, "critical")
		else:
			_add_check("viewmodel_has_active_tool", false, {"reason": "method missing"}, "critical")

		if viewmodel.has_method("play_action"):
			var pivot: Node3D = viewmodel.get_node_or_null("RigPivot/ArmRight/ToolPivot") as Node3D
			var before_rot: Vector3 = pivot.rotation_degrees if pivot != null else Vector3.ZERO
			viewmodel.call("play_action", "mine")
			for _j in range(4):
				await process_frame
			var during_rot: Vector3 = pivot.rotation_degrees if pivot != null else Vector3.ZERO
			var moved: bool = before_rot.distance_to(during_rot) > 0.5
			_add_check("viewmodel_mine_action_animates", moved, {
				"before": [before_rot.x, before_rot.y, before_rot.z],
				"during": [during_rot.x, during_rot.y, during_rot.z],
				"delta": before_rot.distance_to(during_rot)
			}, "critical")
		else:
			_add_check("viewmodel_mine_action_animates", false, {"reason": "play_action missing"}, "critical")

		if camera != null:
			var viewport_size: Vector2 = camera.get_viewport().get_visible_rect().size
			var probe_nodes: Array = [arm_left, arm_right, hand_left, hand_right, tool_mesh]
			var visible_points: int = 0
			var left_visible: bool = false
			var right_visible: bool = false
			var probe_details: Array = []
			for probe_node in probe_nodes:
				if probe_node == null:
					continue
				var point: Vector3 = probe_node.global_position
				var in_front: bool = not camera.is_position_behind(point)
				var screen: Vector2 = camera.unproject_position(point)
				var in_bounds: bool = (
					screen.x >= 0.0 and screen.x <= viewport_size.x and
					screen.y >= viewport_size.y * 0.38 and screen.y <= viewport_size.y
				)
				if in_front and in_bounds:
					visible_points += 1
					if probe_node.name.to_lower().contains("left"):
						left_visible = true
					if probe_node.name.to_lower().contains("right") or probe_node.name.to_lower().contains("tool"):
						right_visible = true
				probe_details.append({
					"name": probe_node.name,
					"in_front": in_front,
					"in_bounds": in_bounds,
					"screen": [round(screen.x), round(screen.y)]
				})

			var projection_ok: bool = visible_points >= 3 and left_visible and right_visible
			_add_check("viewmodel_points_project_into_view", projection_ok, {
				"visible_points": visible_points,
				"left_visible": left_visible,
				"right_visible": right_visible,
				"viewport": [viewport_size.x, viewport_size.y],
				"probes": probe_details
			}, "critical")
		else:
			_add_check("viewmodel_points_project_into_view", false, {"reason": "camera missing"}, "critical")

	var moon_system: Node = main.get_node_or_null("World/MoonSystem")
	var moon_children: int = moon_system.get_child_count() if moon_system != null else 0
	_add_check("moon_system_spawns_8", moon_children == 8, {
		"moon_children": moon_children
	}, "critical")

	var game_services: Node = get_root().get_node_or_null("GameServices")
	var data_service: Node = game_services.get("data_service") if game_services != null else null
	var inventory_service: Node = game_services.get("inventory_service") if game_services != null else null
	var lore_service: Node = game_services.get("lore_journal_service") if game_services != null else null
	var save_service: Node = game_services.get("save_service") if game_services != null else null
	var items_ok: bool = false
	var viewmodel_cfg_ok: bool = false
	var dust_profiles_ok: bool = false
	var dust_color_match_ok: bool = false
	var dust_shape_unique_ok: bool = false
	var dust_glow_spectrum_ok: bool = false
	var dust_rarity_exotic_ok: bool = false
	var dust_shape_library_ok: bool = false
	var ruins_terminal_present: bool = false
	var ruins_terminal_starts_locked: bool = false
	var ruins_terminal_can_be_primed: bool = false
	var save_load_world_flag_roundtrip: bool = false
	var save_legacy_migration_ok: bool = false
	if data_service != null:
		var required_items := [
			"dust_blue", "dust_green", "dust_red", "dust_orange",
			"dust_yellow", "dust_white", "dust_black", "dust_silver",
			"energy_crystal", "alloy", "moonblade_prototype", "dream_seed", "bot_scrap"
		]
		items_ok = true
		for item_id in required_items:
			if (data_service.call("get_item", item_id) as Dictionary).is_empty():
				items_ok = false
				break
		var cfg: Dictionary = data_service.call("get_viewmodel_config")
		viewmodel_cfg_ok = not cfg.is_empty() and cfg.has("actions")

		var dust_ids := [
			"dust_blue", "dust_green", "dust_red", "dust_orange",
			"dust_yellow", "dust_white", "dust_black", "dust_silver"
		]
		var baseline_keys := {
			"dust_blue": ["stamina_regen"],
			"dust_green": ["health_regen"],
			"dust_red": ["damage_bonus"],
			"dust_orange": ["mining_speed"],
			"dust_yellow": ["move_speed"],
			"dust_white": ["shield_regen"],
			"dust_black": ["aggro_radius_multiplier"],
			"dust_silver": ["credit_gain_multiplier"]
		}
		var rarity_min_exotic := {
			"common": 0,
			"uncommon": 1,
			"rare": 1,
			"epic": 2,
			"legendary": 3
		}
		var moons_by_id: Dictionary = {}
		for moon_def in data_service.call("get_moons"):
			if typeof(moon_def) != TYPE_DICTIONARY:
				continue
			moons_by_id[str(moon_def.get("id", ""))] = moon_def

		var shape_claims: Dictionary = {}
		var glow_values: Array[float] = []
		dust_profiles_ok = true
		dust_color_match_ok = true
		dust_shape_unique_ok = true
		dust_rarity_exotic_ok = true
		for dust_id in dust_ids:
			var item_def: Dictionary = data_service.call("get_item", dust_id)
			var profile: Dictionary = data_service.call("get_dust_profile", dust_id)
			if item_def.is_empty() or profile.is_empty():
				dust_profiles_ok = false
				continue

			var shape_id: String = str(profile.get("shape", ""))
			if shape_id.is_empty():
				dust_profiles_ok = false
			elif shape_claims.has(shape_id):
				dust_shape_unique_ok = false
			else:
				shape_claims[shape_id] = dust_id

			var glow_strength: float = float(profile.get("glow_strength", -1.0))
			if glow_strength < 0.0 or glow_strength > 1.0:
				dust_profiles_ok = false
			glow_values.append(glow_strength)

			var moon_id: String = str(profile.get("moon_id", ""))
			var moon_def: Dictionary = moons_by_id.get(moon_id, {})
			if moon_def.is_empty():
				dust_profiles_ok = false
				dust_color_match_ok = false
			else:
				var moon_color_hex: String = str(moon_def.get("color", ""))
				if not Color.html_is_valid(moon_color_hex):
					dust_profiles_ok = false
					dust_color_match_ok = false
				else:
					var moon_color: Color = Color.html(moon_color_hex)
					var dust_color: Color = data_service.call("get_dust_color", dust_id)
					if not _color_approx(dust_color, moon_color):
						dust_color_match_ok = false

				var expected_dust_suffix: String = str(moon_def.get("dust_type", "")).to_lower()
				if dust_id.trim_prefix("dust_") != expected_dust_suffix:
					dust_profiles_ok = false

			var rarity: String = str(profile.get("rarity", "common")).to_lower()
			var min_exotic: int = int(rarity_min_exotic.get(rarity, 999))
			var modifier: Dictionary = item_def.get("modifier", {})
			var baseline: Array = baseline_keys.get(dust_id, [])
			var exotic_count: int = 0
			for modifier_key in modifier.keys():
				if not baseline.has(str(modifier_key)):
					exotic_count += 1
			if exotic_count < min_exotic:
				dust_rarity_exotic_ok = false

		if glow_values.size() == dust_ids.size():
			var min_glow: float = glow_values[0]
			var max_glow: float = glow_values[0]
			for glow_strength in glow_values:
				min_glow = min(min_glow, glow_strength)
				max_glow = max(max_glow, glow_strength)
			dust_glow_spectrum_ok = abs(min_glow - 0.0) <= 0.0001 and abs(max_glow - 1.0) <= 0.0001

		var dust_shape_lib: Script = load("res://scripts/resources/dust_shape_library.gd")
		var shape_ids: Array = ["orb", "cube", "tetra", "prism", "capsule", "ring", "octa", "spindle"]
		dust_shape_library_ok = dust_shape_lib != null
		if dust_shape_library_ok:
			for shape_id in shape_ids:
				var mesh: Mesh = dust_shape_lib.call("build_mesh", shape_id, 1.0)
				var shape: Shape3D = dust_shape_lib.call("build_collision_shape", shape_id, 0.45)
				if mesh == null or mesh.get_surface_count() <= 0 or shape == null:
					dust_shape_library_ok = false
					break

	if game_services != null:
		var ruins_terminal: Node = main.get_node_or_null("World/GreegionRuins/Terminal")
		ruins_terminal_present = ruins_terminal != null and ruins_terminal.has_method("interact") and ruins_terminal.has_method("get_interaction_status")
		if ruins_terminal_present:
			game_services.call("set_world_flag", "ruins_terminal_primed", false)
			var terminal_status: Dictionary = ruins_terminal.get_interaction_status()
			ruins_terminal_starts_locked = str(terminal_status.get("state", "")) == "locked"

			if inventory_service != null and lore_service != null:
				inventory_service.add_item("moonblade_prototype", 1)
				inventory_service.add_item("dream_seed", 1)
				lore_service.set_unlocked_ids([
					"enoks_kingdom_ridge",
					"makunas_shore",
					"greegion_ruins"
				])
				var interact_result: Dictionary = ruins_terminal.interact(player)
				var primed_status: Dictionary = ruins_terminal.get_interaction_status()
				var world_flag_primed: bool = bool(game_services.call("get_world_flag", "ruins_terminal_primed", false))
				ruins_terminal_can_be_primed = bool(interact_result.get("ok", false)) and str(primed_status.get("state", "")) == "primed" and world_flag_primed

				if save_service != null and ruins_terminal_can_be_primed:
					var write_ok: bool = bool(save_service.save_game({"qa_probe": true}))
					var saved_state: Dictionary = save_service.get_loaded_state()
					var saved_world_state: Dictionary = saved_state.get("world_state", {})
					var saved_flag: bool = bool(saved_world_state.get("ruins_terminal_primed", false))
					game_services.call("set_world_flag", "ruins_terminal_primed", false)
					save_service.load_game()
					var reloaded_flag: bool = bool(game_services.call("get_world_flag", "ruins_terminal_primed", false))
					save_load_world_flag_roundtrip = write_ok and saved_flag and reloaded_flag
		if save_service != null and save_service.has_method("normalize_state_for_load"):
			var legacy_state: Dictionary = {
				"version": "0.1",
				"player_state": {"position": [2, 8, -3], "health": 90, "stamina": 70, "shield": 4},
				"inventory": {
					"dust_blue": 2,
					"energy_crystal": 1,
					"moonblade_prototype": 1,
					"dream_seed": 1
				},
				"credits": 33,
				"unlocked_lore": ["enoks_kingdom_ridge", "makunas_shore", "greegion_ruins", "makunas_shore"],
				"world_state": {"ruins_terminal_primed": true},
				"event_log": [{"type": "legacy"}]
			}
			var migrated: Dictionary = save_service.normalize_state_for_load(legacy_state)
			var migrated_world: Dictionary = migrated.get("world_state", {})
			save_legacy_migration_ok = (
				int(migrated.get("schema_version", 0)) >= 2 and
				int(migrated.get("credits", -1)) == 33 and
				bool(migrated_world.get("objective_collect_energy_complete", false)) and
				bool(migrated_world.get("objective_unlock_lore_complete", false)) and
				bool(migrated_world.get("objective_prime_ruins_terminal_complete", false))
			)

	_add_check("required_items_loaded", items_ok, {}, "critical")
	_add_check("viewmodel_config_loaded", viewmodel_cfg_ok, {}, "critical")
	_add_check("dust_profiles_loaded", dust_profiles_ok, {}, "critical")
	_add_check("dust_colors_match_moons", dust_color_match_ok, {}, "critical")
	_add_check("dust_shapes_are_unique", dust_shape_unique_ok, {}, "critical")
	_add_check("dust_glow_spectrum_full_range", dust_glow_spectrum_ok, {}, "critical")
	_add_check("dust_rarity_exotic_scaling", dust_rarity_exotic_ok, {}, "critical")
	_add_check("dust_shape_library_builds", dust_shape_library_ok, {}, "critical")
	_add_check("ruins_terminal_present", ruins_terminal_present, {}, "critical")
	_add_check("ruins_terminal_starts_locked", ruins_terminal_starts_locked, {}, "critical")
	_add_check("ruins_terminal_can_be_primed", ruins_terminal_can_be_primed, {}, "critical")
	_add_check("save_load_world_flag_roundtrip", save_load_world_flag_roundtrip, {}, "critical")
	_add_check("save_legacy_migration", save_legacy_migration_ok, {}, "critical")

	main.queue_free()
	await process_frame

func _add_check(id: String, ok: bool, details: Dictionary = {}, severity: String = "info") -> void:
	_checks.append({
		"id": id,
		"ok": ok,
		"severity": severity,
		"details": details
	})

func _summary() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	for check in _checks:
		if bool(check.get("ok", false)):
			passed += 1
		else:
			failed += 1
	return {
		"total": _checks.size(),
		"passed": passed,
		"failed": failed
	}

func _color_approx(a: Color, b: Color, epsilon: float = 0.015) -> bool:
	return (
		abs(a.r - b.r) <= epsilon and
		abs(a.g - b.g) <= epsilon and
		abs(a.b - b.b) <= epsilon
	)

func _write_reports(report: Dictionary) -> void:
	var reports_dir: String = ProjectSettings.globalize_path("res://docs/reports")
	DirAccess.make_dir_recursive_absolute(reports_dir)
	var stamp: String = Time.get_datetime_string_from_system(true).replace(":", "").replace("-", "").replace("T", "_")
	var base_name: String = "headless_qa_%s" % stamp
	var json_path: String = "%s/%s.json" % [reports_dir, base_name]
	var md_path: String = "%s/%s.md" % [reports_dir, base_name]
	var latest_json: String = "%s/qa_latest.json" % reports_dir
	var latest_md: String = "%s/qa_latest.md" % reports_dir

	var json_file := FileAccess.open(json_path, FileAccess.WRITE)
	json_file.store_string(JSON.stringify(report, "  "))
	json_file.close()

	var lines: Array[String] = []
	lines.append("# Celadora Headless QA Report")
	lines.append("")
	lines.append("- Started: %s" % report.get("started_at", ""))
	lines.append("- Ended: %s" % report.get("ended_at", ""))
	var summary: Dictionary = report.get("summary", {})
	lines.append("- Result: %s (%d/%d passed)" % ["PASS" if int(summary.get("failed", 0)) == 0 else "FAIL", int(summary.get("passed", 0)), int(summary.get("total", 0))])
	lines.append("")
	lines.append("## Checks")
	lines.append("")
	lines.append("| Check | Status | Severity | Details |")
	lines.append("|---|---|---|---|")
	for check in _checks:
		lines.append("| %s | %s | %s | %s |" % [
			str(check.get("id", "")),
			"PASS" if bool(check.get("ok", false)) else "FAIL",
			str(check.get("severity", "info")),
			JSON.stringify(check.get("details", {}))
		])

	var md_file := FileAccess.open(md_path, FileAccess.WRITE)
	md_file.store_string("\n".join(lines))
	md_file.close()

	DirAccess.copy_absolute(json_path, latest_json)
	DirAccess.copy_absolute(md_path, latest_md)
	print(md_path)
	print(json_path)
