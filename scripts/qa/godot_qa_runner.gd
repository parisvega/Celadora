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

	var moon_system: Node = main.get_node_or_null("World/MoonSystem")
	var moon_children: int = moon_system.get_child_count() if moon_system != null else 0
	_add_check("moon_system_spawns_8", moon_children == 8, {
		"moon_children": moon_children
	}, "critical")

	var data_service: Node = get_root().get_node_or_null("GameServices").get("data_service")
	var items_ok: bool = false
	var viewmodel_cfg_ok: bool = false
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

	_add_check("required_items_loaded", items_ok, {}, "critical")
	_add_check("viewmodel_config_loaded", viewmodel_cfg_ok, {}, "critical")

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
