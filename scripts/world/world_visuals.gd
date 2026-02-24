extends Node3D

@export var world_spawner_path: NodePath = NodePath("../WorldSpawner")
@export var day_night_cycle_path: NodePath = NodePath("../DayNightCycle")
@export var player_path: NodePath = NodePath("../../Player")
@export var water_level: float = 1.25
@export var water_padding: float = 12.0

const WATER_SHADER_PATH := "res://assets/shaders/celadora_water.gdshader"
const SKY_SHADER_PATH := "res://assets/shaders/celadora_skydome.gdshader"

var _world_spawner: Node = null
var _day_night_cycle: Node = null
var _player: Node3D = null
var _water_mesh: MeshInstance3D = null
var _water_material: ShaderMaterial = null
var _sky_dome: MeshInstance3D = null
var _sky_material: ShaderMaterial = null

func _ready() -> void:
	_world_spawner = get_node_or_null(world_spawner_path)
	_day_night_cycle = get_node_or_null(day_night_cycle_path)
	_player = get_node_or_null(player_path) as Node3D
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
	_build_sky_dome()
	_build_water_plane()
	_update_visual_params()

func _process(_delta: float) -> void:
	_update_visual_params()
	_follow_player_for_sky()

func _build_sky_dome() -> void:
	_sky_dome = MeshInstance3D.new()
	_sky_dome.name = "SkyDome"
	var dome := SphereMesh.new()
	dome.radius = 360.0
	dome.height = 720.0
	dome.radial_segments = 48
	dome.rings = 24
	_sky_dome.mesh = dome
	_sky_dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_sky_material = ShaderMaterial.new()
	_sky_material.shader = load(SKY_SHADER_PATH) as Shader
	_sky_dome.material_override = _sky_material
	add_child(_sky_dome)

func _build_water_plane() -> void:
	_water_mesh = MeshInstance3D.new()
	_water_mesh.name = "WaterPlane"
	var plane := PlaneMesh.new()
	plane.subdivide_depth = 56
	plane.subdivide_width = 56
	plane.size = _water_size()
	_water_mesh.mesh = plane
	_water_mesh.position = Vector3(0.0, water_level, 0.0)
	_water_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_water_material = ShaderMaterial.new()
	_water_material.shader = load(WATER_SHADER_PATH) as Shader
	_water_mesh.material_override = _water_material
	add_child(_water_mesh)

func _water_size() -> Vector2:
	var radius: float = 52.0
	if _world_spawner != null and _world_spawner.has_method("get_world_radius"):
		radius = max(radius, float(_world_spawner.get_world_radius()) + water_padding)
	return Vector2(radius * 2.0, radius * 2.0)

func _update_visual_params() -> void:
	var time_of_day: float = 13.0
	if _day_night_cycle != null:
		time_of_day = float(_day_night_cycle.get("time_of_day"))
	var daylight: float = clamp(sin((time_of_day / 24.0) * TAU) * 0.5 + 0.5, 0.0, 1.0)
	var night_factor: float = 1.0 - daylight

	if _water_material != null:
		_water_material.set_shader_parameter("time_of_day", time_of_day)
		_water_material.set_shader_parameter("moon_tint", Color(0.24, 0.58, 0.8, 1.0).lerp(Color(0.43, 0.84, 1.0, 1.0), night_factor))

	if _sky_material != null:
		_sky_material.set_shader_parameter("night_factor", night_factor)
		_sky_material.set_shader_parameter("moon_glow", Color(0.22, 0.6, 0.9, 1.0))

func _follow_player_for_sky() -> void:
	if _sky_dome == null:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player != null:
		_sky_dome.global_position = _player.global_position
