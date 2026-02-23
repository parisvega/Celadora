extends Area3D

const DustShapeLibrary = preload("res://scripts/resources/dust_shape_library.gd")

@export var item_id: String = "bot_scrap"
@export var quantity: int = 1
@export var credits: int = 0

@export var gravity_scale: float = 1.0
@export var air_drag: float = 0.12
@export var bounciness: float = 0.22
@export var enable_physics_motion: bool = true

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh_node: MeshInstance3D = $Mesh

var _collected: bool = false
var _velocity: Vector3 = Vector3.ZERO
var _settled: bool = false
var _world_spawner: Node = null
var _shape_id: String = "orb"
var _base_color: Color = Color(0.75, 0.93, 1.0)
var _glow_strength: float = 0.25

func _ready() -> void:
	add_to_group("pickup_item")
	body_entered.connect(_on_body_entered)
	_cache_world_spawner()
	_apply_dust_profile_defaults()
	_update_visual()

func _physics_process(delta: float) -> void:
	if _collected:
		return
	rotate_y(delta * (1.0 + (1.0 - clamp(gravity_scale, 0.1, 2.5)) * 0.4))

	if not enable_physics_motion:
		return
	_step_physics(delta)

func _on_body_entered(body: Node) -> void:
	if _collected:
		return
	if body.is_in_group("player"):
		collect()

func interact(_player: Node) -> Dictionary:
	collect()
	return {"ok": true}

func get_interaction_status() -> Dictionary:
	var item_name: String = item_id
	var item_def: Dictionary = GameServices.data_service.get_item(item_id)
	if not item_def.is_empty():
		item_name = str(item_def.get("name", item_id))
	return {
		"type": "pickup",
		"name": item_name,
		"quantity": max(quantity, 1),
		"credits": max(credits, 0),
		"gravity_scale": gravity_scale,
		"glow_strength": _glow_strength
	}

func collect() -> void:
	if _collected:
		return
	_collected = true
	if item_id != "":
		GameServices.inventory_service.add_item(item_id, max(quantity, 1))
	if credits > 0:
		GameServices.inventory_service.add_credits(credits)

	var item_name: String = item_id
	var item_def: Dictionary = GameServices.data_service.get_item(item_id)
	if not item_def.is_empty():
		item_name = str(item_def.get("name", item_id))
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.push_message("Picked up %s x%d" % [item_name, max(quantity, 1)])
	queue_free()

func set_initial_motion(initial_velocity: Vector3) -> void:
	_velocity = initial_velocity
	_settled = false

func apply_dust_profile(profile: Dictionary) -> void:
	gravity_scale = clamp(float(profile.get("gravity_scale", gravity_scale)), 0.1, 3.0)
	bounciness = clamp(float(profile.get("bounce", bounciness)), 0.0, 0.95)
	air_drag = clamp(float(profile.get("drag", air_drag)), 0.0, 0.9)
	_glow_strength = clamp(float(profile.get("glow_strength", _glow_strength)), 0.0, 1.0)
	_shape_id = str(profile.get("shape", _shape_id))
	_update_visual()

func _cache_world_spawner() -> void:
	_world_spawner = get_tree().get_first_node_in_group("world_spawner")

func _apply_dust_profile_defaults() -> void:
	var profile: Dictionary = GameServices.data_service.get_dust_profile(item_id)
	if not profile.is_empty():
		_base_color = GameServices.data_service.get_dust_color(item_id)
		apply_dust_profile(profile)
		return

	if item_id == "energy_crystal":
		_shape_id = "prism"
		gravity_scale = 0.88
		bounciness = 0.32
		air_drag = 0.1
		_glow_strength = 0.72
		_base_color = Color(0.28, 0.94, 0.94)
		return

	_shape_id = "orb"
	_base_color = Color(0.75, 0.93, 1.0)
	_glow_strength = 0.2

func _step_physics(delta: float) -> void:
	if _world_spawner == null:
		_cache_world_spawner()

	if not _settled:
		var world_gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
		_velocity.y -= world_gravity * gravity_scale * delta
		var drag_factor: float = clamp(1.0 - air_drag * delta, 0.0, 1.0)
		_velocity *= drag_factor
		global_position += _velocity * delta

		var floor_y: float = _sample_floor_height(global_position)
		var rest_height: float = 0.36
		if global_position.y <= floor_y + rest_height:
			global_position.y = floor_y + rest_height
			if absf(_velocity.y) > 0.2:
				_velocity.y = -_velocity.y * bounciness
				_velocity.x *= 0.88
				_velocity.z *= 0.88
			else:
				_velocity.y = 0.0
				_velocity.x = move_toward(_velocity.x, 0.0, delta * (2.2 + air_drag * 6.0))
				_velocity.z = move_toward(_velocity.z, 0.0, delta * (2.2 + air_drag * 6.0))
				if Vector2(_velocity.x, _velocity.z).length() <= 0.05:
					_settled = true

	_apply_local_repulsion(delta)

func _sample_floor_height(pos: Vector3) -> float:
	if _world_spawner != null and _world_spawner.has_method("get_surface_position"):
		return float(_world_spawner.get_surface_position(pos.x, pos.z).y)
	return 0.0

func _apply_local_repulsion(delta: float) -> void:
	var nearby: Array = get_tree().get_nodes_in_group("pickup_item")
	for other in nearby:
		if other == self:
			continue
		if not (other is Area3D):
			continue
		var delta_planar: Vector2 = Vector2(global_position.x - other.global_position.x, global_position.z - other.global_position.z)
		var distance: float = delta_planar.length()
		if distance <= 0.001 or distance > 0.48:
			continue
		var push_strength: float = (0.48 - distance) * 1.4
		var push_dir: Vector2 = delta_planar / distance
		_velocity.x += push_dir.x * push_strength * delta
		_velocity.z += push_dir.y * push_strength * delta
		_settled = false

func _update_visual() -> void:
	mesh_node.mesh = DustShapeLibrary.build_mesh(_shape_id, 0.8)
	mesh_node.rotation_degrees = _shape_rotation(_shape_id)
	collision_shape.shape = DustShapeLibrary.build_collision_shape(_shape_id, 0.38)

	var material := StandardMaterial3D.new()
	material.albedo_color = _base_color
	material.roughness = 0.25
	material.emission_enabled = _glow_strength > 0.0
	material.emission = _base_color * (0.06 + _glow_strength * 2.8)
	if _glow_strength >= 0.95:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_node.material_override = material
	_sync_glow_light()

func _shape_rotation(shape_id: String) -> Vector3:
	match shape_id:
		"tetra":
			return Vector3(22.0, 30.0, 10.0)
		"prism":
			return Vector3(0.0, 40.0, 0.0)
		"capsule":
			return Vector3(90.0, 0.0, 18.0)
		"ring":
			return Vector3(90.0, 0.0, 0.0)
		"spindle":
			return Vector3(0.0, 0.0, 90.0)
		_:
			return Vector3.ZERO

func _sync_glow_light() -> void:
	var glow_light: OmniLight3D = get_node_or_null("GlowLight") as OmniLight3D
	if _glow_strength < 0.6:
		if glow_light != null:
			glow_light.queue_free()
		return
	if glow_light == null:
		glow_light = OmniLight3D.new()
		glow_light.name = "GlowLight"
		add_child(glow_light)
	glow_light.light_color = _base_color
	glow_light.light_energy = lerpf(0.5, 3.8, _glow_strength)
	glow_light.omni_range = lerpf(1.3, 3.2, _glow_strength)
	glow_light.position = Vector3(0.0, 0.16, 0.0)
