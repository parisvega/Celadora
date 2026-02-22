extends Node3D

signal action_impact(action_name: String)

@export var config_path: String = "res://data/viewmodel.json"

@onready var rig_pivot: Node3D = $RigPivot
@onready var arm_left_root: Node3D = $RigPivot/ArmLeft
@onready var arm_right_root: Node3D = $RigPivot/ArmRight
@onready var arm_left_mesh: MeshInstance3D = $RigPivot/ArmLeft/ArmLeftMesh
@onready var arm_right_mesh: MeshInstance3D = $RigPivot/ArmRight/ArmRightMesh
@onready var hand_left_mesh: MeshInstance3D = $RigPivot/ArmLeft/HandLeftMesh
@onready var hand_right_mesh: MeshInstance3D = $RigPivot/ArmRight/HandRightMesh
@onready var tool_pivot: Node3D = $RigPivot/ArmRight/ToolPivot
@onready var tool_mesh: MeshInstance3D = $RigPivot/ArmRight/ToolPivot/ToolMesh
@onready var tool_accent_mesh: MeshInstance3D = $RigPivot/ArmRight/ToolPivot/ToolAccentMesh

var _config: Dictionary = {}
var _look_input: Vector2 = Vector2.ZERO
var _look_sway: Vector2 = Vector2.ZERO
var _speed_ratio: float = 0.0
var _is_running: bool = false
var _is_grounded: bool = true
var _stamina_ratio: float = 1.0
var _time: float = 0.0
var _recoil_pitch: float = 0.0
var _recoil_yaw: float = 0.0
var _damage_kick: float = 0.0
var _active_action_name: String = ""
var _active_action_elapsed: float = 0.0
var _active_action_duration: float = 0.0
var _active_action_impact: float = 0.0
var _active_action_impact_emitted: bool = false
var _action_tween: Tween = null
var _active_tool: String = "miner"
var _active_dust_tint: Color = Color(0.62, 0.78, 1.0, 1.0)
var _tool_rest_rotation: Vector3 = Vector3.ZERO

var _skin_material: StandardMaterial3D
var _tool_base_material: StandardMaterial3D
var _tool_accent_material: StandardMaterial3D

const VIEWMODEL_LAYER_MASK: int = 2

func _ready() -> void:
	add_to_group("viewmodel")
	_load_config()
	_build_geometry()
	_apply_viewmodel_layers()
	_set_default_pose()
	set_tool(str(_config_get(["tools", "default"], "miner")))

func _process(delta: float) -> void:
	_time += delta
	_update_action_timing(delta)
	_update_motion(delta)
	_update_material_feedback(delta)

func set_motion_state(speed_ratio: float, is_running: bool, is_grounded: bool, stamina_ratio: float) -> void:
	_speed_ratio = clamp(speed_ratio, 0.0, 1.0)
	_is_running = is_running
	_is_grounded = is_grounded
	_stamina_ratio = clamp(stamina_ratio, 0.0, 1.0)

func apply_look_delta(relative: Vector2) -> void:
	var response: float = float(_config_get(["sway", "response"], 0.017))
	var max_yaw: float = float(_config_get(["sway", "max_yaw_deg"], 2.8))
	var max_pitch: float = float(_config_get(["sway", "max_pitch_deg"], 1.8))
	_look_input.x = clamp(_look_input.x + relative.x * response, -max_yaw, max_yaw)
	_look_input.y = clamp(_look_input.y + relative.y * response, -max_pitch, max_pitch)

func get_action_impact_time(action_name: String) -> float:
	var action_cfg: Dictionary = _get_action_config(action_name)
	return max(0.0, float(action_cfg.get("impact_time_sec", 0.1)))

func play_action(action_name: String) -> float:
	var action_cfg: Dictionary = _get_action_config(action_name)
	var duration: float = max(0.05, float(action_cfg.get("duration_sec", 0.28)))
	var impact: float = clamp(float(action_cfg.get("impact_time_sec", duration * 0.45)), 0.0, duration)
	var pitch_kick: float = float(action_cfg.get("pitch_kick_deg", -20.0))
	var yaw_kick: float = float(action_cfg.get("yaw_kick_deg", 8.0))
	var kick_rotation: Vector3 = _tool_rest_rotation + Vector3(pitch_kick, yaw_kick, 0.0)

	if _action_tween != null:
		_action_tween.kill()
	_action_tween = create_tween()
	_action_tween.set_trans(Tween.TRANS_QUAD)
	_action_tween.set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(tool_pivot, "rotation_degrees", kick_rotation, impact)
	_action_tween.parallel().tween_property(arm_right_root, "rotation_degrees", Vector3(pitch_kick * 0.42, yaw_kick * 0.35, 0.0), impact)
	_action_tween.chain().set_trans(Tween.TRANS_QUAD)
	_action_tween.set_ease(Tween.EASE_IN)
	_action_tween.tween_property(tool_pivot, "rotation_degrees", _tool_rest_rotation, max(duration - impact, 0.05))
	_action_tween.parallel().tween_property(arm_right_root, "rotation_degrees", Vector3.ZERO, max(duration - impact, 0.05))

	_active_action_name = action_name
	_active_action_elapsed = 0.0
	_active_action_duration = duration
	_active_action_impact = impact
	_active_action_impact_emitted = false

	_recoil_pitch += absf(pitch_kick) * 0.05
	_recoil_yaw += yaw_kick * 0.03
	return impact

func set_tool(tool_name: String) -> void:
	var states: Dictionary = _config_get(["tools", "states"], {})
	if not states.has(tool_name):
		tool_name = str(_config_get(["tools", "default"], "miner"))
		if not states.has(tool_name):
			tool_name = "miner"
	_active_tool = tool_name

	var cfg: Dictionary = states.get(tool_name, {})
	tool_pivot.position = _vec3_from_value(cfg.get("position", [0.0, 0.0, 0.0]), Vector3.ZERO)
	_tool_rest_rotation = _vec3_from_value(cfg.get("rotation_deg", [0.0, 0.0, 0.0]), Vector3.ZERO)
	tool_pivot.rotation_degrees = _tool_rest_rotation

	if tool_name == "none":
		tool_mesh.visible = false
		tool_accent_mesh.visible = false
		return

	tool_mesh.visible = true
	tool_accent_mesh.visible = true
	_apply_tool_geometry(tool_name)
	_apply_tool_materials()

func set_dust_tint(color_value: Color) -> void:
	_active_dust_tint = color_value
	_apply_tool_materials()

func notify_damage(amount: float = 0.0) -> void:
	var damage_kick_base: float = float(_config_get(["recoil", "damage_kick_deg"], 2.6))
	_damage_kick = clamp(_damage_kick + damage_kick_base + amount * 0.02, 0.0, 6.0)

func get_active_tool() -> String:
	return _active_tool

func _build_geometry() -> void:
	var arm_mesh: BoxMesh = BoxMesh.new()
	arm_mesh.size = Vector3(0.2, 0.18, 0.7)
	arm_left_mesh.mesh = arm_mesh
	arm_right_mesh.mesh = arm_mesh

	var hand_mesh: SphereMesh = SphereMesh.new()
	hand_mesh.radius = 0.12
	hand_mesh.height = 0.24
	hand_left_mesh.mesh = hand_mesh
	hand_right_mesh.mesh = hand_mesh

	arm_left_root.position = Vector3(-0.2, -0.11, -0.3)
	arm_right_root.position = Vector3(0.22, -0.13, -0.32)
	hand_left_mesh.position = Vector3(0.0, -0.02, -0.38)
	hand_right_mesh.position = Vector3(0.0, -0.02, -0.38)

	_skin_material = _build_material(Color(0.96, 0.84, 0.72, 1.0), true)
	_tool_base_material = _build_material(Color(0.45, 0.5, 0.55, 1.0), true)
	_tool_accent_material = _build_material(Color(0.56, 0.85, 1.0, 1.0), true)

	arm_left_mesh.material_override = _skin_material
	arm_right_mesh.material_override = _skin_material
	hand_left_mesh.material_override = _skin_material
	hand_right_mesh.material_override = _skin_material
	tool_mesh.material_override = _tool_base_material
	tool_accent_mesh.material_override = _tool_accent_material

func _apply_tool_geometry(tool_name: String) -> void:
	if tool_name == "moonblade":
		var blade: BoxMesh = BoxMesh.new()
		blade.size = Vector3(0.08, 0.02, 0.86)
		tool_mesh.mesh = blade

		var hilt: CylinderMesh = CylinderMesh.new()
		hilt.top_radius = 0.045
		hilt.bottom_radius = 0.045
		hilt.height = 0.19
		tool_accent_mesh.mesh = hilt
		tool_accent_mesh.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		tool_accent_mesh.position = Vector3(0.0, 0.0, 0.29)
		return

	var miner_body: BoxMesh = BoxMesh.new()
	miner_body.size = Vector3(0.18, 0.18, 0.60)
	tool_mesh.mesh = miner_body

	var miner_tip: CylinderMesh = CylinderMesh.new()
	miner_tip.top_radius = 0.055
	miner_tip.bottom_radius = 0.055
	miner_tip.height = 0.22
	tool_accent_mesh.mesh = miner_tip
	tool_accent_mesh.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	tool_accent_mesh.position = Vector3(0.0, 0.0, -0.34)

func _apply_viewmodel_layers() -> void:
	for mesh in [arm_left_mesh, arm_right_mesh, hand_left_mesh, hand_right_mesh, tool_mesh, tool_accent_mesh]:
		mesh.layers = VIEWMODEL_LAYER_MASK
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _set_default_pose() -> void:
	rig_pivot.position = _vec3_from_value(
		_config_get(["base_transform", "position"], [0.24, -0.16, -0.42]),
		Vector3(0.24, -0.16, -0.42)
	)
	rig_pivot.rotation_degrees = _vec3_from_value(
		_config_get(["base_transform", "rotation_deg"], [-2.0, 0.0, 0.0]),
		Vector3(-2.0, 0.0, 0.0)
	)

func _update_motion(delta: float) -> void:
	var return_speed: float = float(_config_get(["sway", "return_speed"], 10.0))
	_look_input = _look_input.lerp(Vector2.ZERO, clamp(delta * return_speed, 0.0, 1.0))
	_look_sway = _look_sway.lerp(_look_input, clamp(delta * 14.0, 0.0, 1.0))

	var bob_key: String = "run" if _is_running else "walk"
	var bob_cfg: Dictionary = _config_get(["bob", bob_key], {})
	var bob_amp_x: float = float(bob_cfg.get("amp_x", 0.012))
	var bob_amp_y: float = float(bob_cfg.get("amp_y", 0.009))
	var bob_freq: float = float(bob_cfg.get("freq", 8.0))
	var bob: Vector3 = Vector3.ZERO
	if _is_grounded and _speed_ratio > 0.05:
		bob.x = sin(_time * bob_freq) * bob_amp_x * _speed_ratio
		bob.y = absf(cos(_time * bob_freq * 1.2)) * bob_amp_y * _speed_ratio

	var fatigue_cfg: Dictionary = _config_get(["fatigue"], {})
	var fatigue_start_ratio: float = float(fatigue_cfg.get("start_ratio", 0.35))
	var fatigue_pct: float = 0.0
	if _stamina_ratio < fatigue_start_ratio:
		fatigue_pct = (fatigue_start_ratio - _stamina_ratio) / max(fatigue_start_ratio, 0.001)
	fatigue_pct = clamp(fatigue_pct, 0.0, 1.0)
	var fatigue_freq: float = float(fatigue_cfg.get("freq", 16.0))
	var fatigue_pitch: float = sin(_time * fatigue_freq) * float(fatigue_cfg.get("shake_pitch_deg", 0.9)) * fatigue_pct
	var fatigue_yaw: float = cos(_time * fatigue_freq * 0.93) * float(fatigue_cfg.get("shake_yaw_deg", 0.7)) * fatigue_pct

	var recoil_cfg: Dictionary = _config_get(["recoil"], {})
	var recoil_decay: float = float(recoil_cfg.get("decay_speed", 8.0))
	_recoil_pitch = lerpf(_recoil_pitch, 0.0, clamp(delta * recoil_decay, 0.0, 1.0))
	_recoil_yaw = lerpf(_recoil_yaw, 0.0, clamp(delta * recoil_decay, 0.0, 1.0))
	_damage_kick = max(_damage_kick - delta * 3.0, 0.0)

	var base_pos: Vector3 = _vec3_from_value(
		_config_get(["base_transform", "position"], [0.24, -0.24, -0.42]),
		Vector3(0.24, -0.24, -0.42)
	)
	var base_rot: Vector3 = _vec3_from_value(
		_config_get(["base_transform", "rotation_deg"], [-2.0, 0.0, 0.0]),
		Vector3(-2.0, 0.0, 0.0)
	)

	rig_pivot.position = base_pos + bob
	rig_pivot.rotation_degrees = base_rot + Vector3(
		_look_sway.y + fatigue_pitch + _recoil_pitch + _damage_kick * 0.65,
		_look_sway.x + fatigue_yaw + _recoil_yaw,
		0.0
	)

func _update_action_timing(delta: float) -> void:
	if _active_action_name == "":
		return
	_active_action_elapsed += delta
	if not _active_action_impact_emitted and _active_action_elapsed >= _active_action_impact:
		_active_action_impact_emitted = true
		action_impact.emit(_active_action_name)
	if _active_action_elapsed >= _active_action_duration:
		_active_action_name = ""

func _update_material_feedback(_delta: float) -> void:
	if _skin_material != null:
		var skin_color: Color = Color(0.96, 0.84, 0.72, 1.0)
		skin_color = skin_color.lerp(Color(1.0, 0.4, 0.4, 1.0), clamp(_damage_kick * 0.2, 0.0, 0.45))
		_skin_material.albedo_color = skin_color
		_skin_material.emission = skin_color * 0.22
	if _tool_base_material != null:
		_tool_base_material.emission = _tool_base_material.albedo_color * 0.22
	if _tool_accent_material != null:
		var pulse: float = 0.3 + 0.2 * (sin(_time * 4.0) * 0.5 + 0.5)
		_tool_accent_material.emission = _tool_accent_material.albedo_color * pulse

func _apply_tool_materials() -> void:
	if _tool_base_material == null or _tool_accent_material == null:
		return
	var states: Dictionary = _config_get(["tools", "states"], {})
	var cfg: Dictionary = states.get(_active_tool, {})
	var base_color: Color = _color_from_html(str(cfg.get("base_color", "#6d7d8a")), Color(0.45, 0.5, 0.55, 1.0))
	var accent_color: Color = _color_from_html(str(cfg.get("accent_color", "#8ed9ff")), Color(0.56, 0.85, 1.0, 1.0))
	var final_accent: Color = accent_color.lerp(_active_dust_tint, 0.45)

	_tool_base_material.albedo_color = base_color
	_tool_accent_material.albedo_color = final_accent
	_tool_base_material.emission = base_color * 0.18
	_tool_accent_material.emission = final_accent * 0.35

func _build_material(color_value: Color, emission_enabled: bool) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color_value
	material.metallic = 0.08
	material.roughness = 0.42
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.emission_enabled = emission_enabled
	if emission_enabled:
		material.emission = color_value * 0.22
	return material

func _load_config() -> void:
	var from_service: Dictionary = {}
	if GameServices != null and GameServices.data_service != null and GameServices.data_service.has_method("get_viewmodel_config"):
		from_service = GameServices.data_service.get_viewmodel_config()
	if not from_service.is_empty():
		_config = from_service.duplicate(true)
		return

	if not FileAccess.file_exists(config_path):
		_config = _default_config()
		return

	var raw_text: String = FileAccess.get_file_as_string(config_path)
	var parsed: Variant = JSON.parse_string(raw_text)
	if typeof(parsed) == TYPE_DICTIONARY:
		_config = parsed
	else:
		_config = _default_config()

func _default_config() -> Dictionary:
	return {
		"base_transform": {"position": [0.24, -0.16, -0.42], "rotation_deg": [-2.0, 0.0, 0.0]},
		"sway": {"max_pitch_deg": 1.8, "max_yaw_deg": 2.8, "response": 0.017, "return_speed": 10.0},
		"bob": {
			"walk": {"amp_x": 0.012, "amp_y": 0.009, "freq": 8.0},
			"run": {"amp_x": 0.020, "amp_y": 0.014, "freq": 11.0}
		},
		"recoil": {"damage_kick_deg": 2.6, "decay_speed": 8.0},
		"fatigue": {"start_ratio": 0.35, "shake_pitch_deg": 0.9, "shake_yaw_deg": 0.7, "freq": 16.0},
		"actions": {
			"mine": {"duration_sec": 0.28, "impact_time_sec": 0.11, "pitch_kick_deg": -36.0, "yaw_kick_deg": 14.0},
			"attack": {"duration_sec": 0.26, "impact_time_sec": 0.10, "pitch_kick_deg": -52.0, "yaw_kick_deg": 20.0}
		},
		"tools": {"default": "miner", "states": {}}
	}

func _get_action_config(action_name: String) -> Dictionary:
	var actions: Dictionary = _config_get(["actions"], {})
	return actions.get(action_name, {})

func _config_get(path: Array, default_value: Variant) -> Variant:
	var cursor: Variant = _config
	for part in path:
		if typeof(cursor) != TYPE_DICTIONARY:
			return default_value
		if not cursor.has(part):
			return default_value
		cursor = cursor[part]
	return cursor

func _vec3_from_value(value: Variant, fallback: Vector3) -> Vector3:
	if typeof(value) == TYPE_VECTOR3:
		return value
	if typeof(value) != TYPE_ARRAY:
		return fallback
	var arr: Array = value
	if arr.size() != 3:
		return fallback
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))

func _color_from_html(color_text: String, fallback: Color) -> Color:
	if Color.html_is_valid(color_text):
		return Color.html(color_text)
	return fallback
