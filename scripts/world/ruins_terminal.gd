extends Area3D

signal terminal_primed

@export var locked_message: String = "Terminal Lock: Access denied."
@export var primed_message: String = "Terminal synced. Ruins protocol primed (boss encounter arrives in a future update)."
@export var already_primed_message: String = "Terminal already primed. Deeper ruins remain sealed in v0.1."
@export var required_item_id: String = "moonblade_prototype"
@export var require_dream_seed: bool = true
@export var required_lore_entries: int = 3
@export var world_flag_id: String = "ruins_terminal_primed"
@export var terminal_mesh_path: NodePath = NodePath("MeshInstance3D")
@export var door_mesh_path: NodePath = NodePath("../Door/MeshInstance3D")

@onready var _terminal_mesh: MeshInstance3D = get_node_or_null(terminal_mesh_path) as MeshInstance3D
@onready var _door_mesh: MeshInstance3D = get_node_or_null(door_mesh_path) as MeshInstance3D

var _is_primed: bool = false

func _ready() -> void:
	if GameServices != null:
		_is_primed = GameServices.get_world_flag(world_flag_id, false)
		if not GameServices.world_state_changed.is_connected(_on_world_state_changed):
			GameServices.world_state_changed.connect(_on_world_state_changed)
		if not GameServices.world_state_reloaded.is_connected(_on_world_state_reloaded):
			GameServices.world_state_reloaded.connect(_on_world_state_reloaded)
	_ensure_runtime_materials()
	_apply_visual_state()

func get_interaction_status() -> Dictionary:
	var missing: Array[String] = _missing_requirements()
	if _is_primed:
		missing.clear()
	return {
		"type": "terminal",
		"name": "Greegion Terminal",
		"state": "primed" if _is_primed else "locked",
		"requirements_missing": missing.size(),
		"missing_requirements": missing.duplicate()
	}

func interact(_player: Node) -> Dictionary:
	var hud = get_tree().get_first_node_in_group("hud")

	if _is_primed:
		if hud:
			hud.push_message(already_primed_message)
		return {"ok": true, "state": "primed", "message": already_primed_message}

	var missing: Array[String] = _missing_requirements()
	if not missing.is_empty():
		var missing_text: String = _join_parts(missing, ", ")
		var message: String = "%s Missing: %s" % [locked_message, missing_text]
		if hud:
			hud.push_message(message)
		return {
			"ok": false,
			"state": "locked",
			"missing_requirements": missing.duplicate(),
			"message": message
		}

	_is_primed = true
	GameServices.set_world_flag(world_flag_id, true)
	_apply_visual_state()
	GameServices.log_event("ruins.terminal_primed", {
		"flag_id": world_flag_id,
		"required_item_id": required_item_id
	})
	if GameServices.inventory_service != null:
		GameServices.inventory_service.add_credits(25)
	if hud:
		hud.push_message(primed_message)
	terminal_primed.emit()
	return {"ok": true, "state": "primed", "message": primed_message}

func _missing_requirements() -> Array[String]:
	var missing: Array[String] = []
	if GameServices.inventory_service == null or GameServices.lore_journal_service == null:
		missing.append("Core systems offline")
		return missing

	var required_item_def: Dictionary = GameServices.get_item_def(required_item_id)
	var required_item_name: String = str(required_item_def.get("name", required_item_id))
	if GameServices.inventory_service.get_quantity(required_item_id) < 1:
		missing.append(required_item_name)

	if require_dream_seed and GameServices.inventory_service.get_quantity("dream_seed") < 1:
		var dream_seed_def: Dictionary = GameServices.get_item_def("dream_seed")
		missing.append(str(dream_seed_def.get("name", "Dream Seed")))

	var unlocked_count: int = GameServices.lore_journal_service.get_unlocked_ids().size()
	if unlocked_count < required_lore_entries:
		missing.append("Lore markers %d/%d" % [unlocked_count, required_lore_entries])

	return missing

func _on_world_state_changed(flag_id: String, value: Variant) -> void:
	if flag_id != world_flag_id:
		return
	_is_primed = bool(value)
	_apply_visual_state()

func _on_world_state_reloaded(state: Dictionary) -> void:
	_is_primed = bool(state.get(world_flag_id, false))
	_apply_visual_state()

func _ensure_runtime_materials() -> void:
	if _terminal_mesh != null:
		_terminal_mesh.material_override = _clone_or_new_material(_terminal_mesh.material_override)
	if _door_mesh != null:
		_door_mesh.material_override = _clone_or_new_material(_door_mesh.material_override)

func _apply_visual_state() -> void:
	var terminal_color: Color = Color(0.84, 0.22, 0.22, 1.0)
	var door_color: Color = Color(0.35, 0.1, 0.12, 1.0)
	var emission_scale: float = 0.55
	if _is_primed:
		terminal_color = Color(0.25, 0.95, 0.84, 1.0)
		door_color = Color(0.34, 0.62, 0.86, 1.0)
		emission_scale = 1.35
	_apply_material(_terminal_mesh, terminal_color, emission_scale)
	_apply_material(_door_mesh, door_color, emission_scale * 0.8)

func _clone_or_new_material(source: Material) -> StandardMaterial3D:
	if source is StandardMaterial3D:
		return (source as StandardMaterial3D).duplicate(true)
	var material := StandardMaterial3D.new()
	material.roughness = 0.18
	return material

func _apply_material(mesh_node: MeshInstance3D, color: Color, emission_scale: float) -> void:
	if mesh_node == null:
		return
	var material: StandardMaterial3D = mesh_node.material_override as StandardMaterial3D
	if material == null:
		material = StandardMaterial3D.new()
		mesh_node.material_override = material
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color * emission_scale
	material.roughness = 0.16

func _join_parts(parts: Array[String], separator: String) -> String:
	if parts.is_empty():
		return ""
	var joined: String = parts[0]
	for i in range(1, parts.size()):
		joined += separator + parts[i]
	return joined
