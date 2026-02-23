extends StaticBody3D

const DustShapeLibrary = preload("res://scripts/resources/dust_shape_library.gd")

@export var item_id: String = "dust_blue"
@export var yield_quantity: int = 1
@export var durability: float = 2.5
@export var credit_reward: int = 3

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh_node: MeshInstance3D = $Mesh

var _current_durability: float = 0.0
var _glow_strength: float = 0.0
var _base_color: Color = Color(0.8, 0.8, 0.8)
var _shape_id: String = "orb"

func _ready() -> void:
	_current_durability = durability
	_apply_visual()

func mine(power: float = 1.0) -> Dictionary:
	_current_durability -= max(power, 0.2)
	_flash_feedback()
	if _current_durability <= 0.0:
		var result = {
			"mined": true,
			"item_id": item_id,
			"quantity": max(1, yield_quantity),
			"credits": max(0, credit_reward)
		}
		queue_free()
		return result
	return {"mined": false}

func get_interaction_status() -> Dictionary:
	var item_def: Dictionary = GameServices.get_item_def(item_id)
	var display_name: String = str(item_def.get("name", item_id))
	return {
		"type": "resource",
		"name": display_name,
		"item_id": item_id,
		"durability": max(_current_durability, 0.0),
		"durability_max": max(durability, 0.001),
		"progress_pct": clamp((_current_durability / max(durability, 0.001)) * 100.0, 0.0, 100.0)
	}

func _apply_visual() -> void:
	var profile: Dictionary = GameServices.data_service.get_dust_profile(item_id)
	_shape_id = str(profile.get("shape", "orb")) if not profile.is_empty() else "orb"
	_glow_strength = clamp(float(profile.get("glow_strength", 0.0)), 0.0, 1.0)
	_base_color = GameServices.data_service.get_dust_color(item_id)

	if item_id == "energy_crystal":
		_shape_id = "prism"
		_glow_strength = 0.72

	mesh_node.mesh = DustShapeLibrary.build_mesh(_shape_id, 1.05)
	mesh_node.rotation_degrees = _shape_rotation(_shape_id)
	collision_shape.shape = DustShapeLibrary.build_collision_shape(_shape_id, 0.48)

	var material := StandardMaterial3D.new()
	material.roughness = 0.32
	material.albedo_color = _base_color
	material.emission_enabled = _glow_strength > 0.0
	material.emission = _base_color * (0.05 + _glow_strength * 2.6)
	if _glow_strength >= 0.95:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_node.material_override = material
	_sync_glow_light()

func _flash_feedback() -> void:
	if mesh_node.material_override == null:
		return
	var material := mesh_node.material_override as StandardMaterial3D
	if material == null:
		return
	material.emission = _base_color * (0.45 + _glow_strength * 3.0)
	await get_tree().create_timer(0.08).timeout
	if is_instance_valid(mesh_node):
		material.emission = _base_color * (0.05 + _glow_strength * 2.6)

func _shape_rotation(shape_id: String) -> Vector3:
	match shape_id:
		"tetra":
			return Vector3(18.0, 22.0, 9.0)
		"prism":
			return Vector3(0.0, 30.0, 0.0)
		"capsule":
			return Vector3(90.0, 0.0, 22.0)
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
	glow_light.light_energy = lerpf(0.6, 4.2, _glow_strength)
	glow_light.omni_range = lerpf(1.6, 4.2, _glow_strength)
	glow_light.position = Vector3(0.0, 0.2, 0.0)
