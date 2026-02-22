extends StaticBody3D

@export var item_id: String = "dust_blue"
@export var yield_quantity: int = 1
@export var durability: float = 2.5
@export var credit_reward: int = 3

@onready var mesh_node: MeshInstance3D = $Mesh

var _current_durability: float = 0.0

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
	var sphere = SphereMesh.new()
	sphere.radius = 0.45
	sphere.height = 0.9
	mesh_node.mesh = sphere

	var material = StandardMaterial3D.new()
	material.roughness = 0.35
	material.emission_enabled = true
	material.emission = _color_for_item(item_id) * 0.2
	material.albedo_color = _color_for_item(item_id)
	mesh_node.material_override = material

func _flash_feedback() -> void:
	if mesh_node.material_override == null:
		return
	var material = mesh_node.material_override as StandardMaterial3D
	if material == null:
		return
	material.emission = _color_for_item(item_id) * 0.5
	await get_tree().create_timer(0.08).timeout
	if is_instance_valid(mesh_node):
		material.emission = _color_for_item(item_id) * 0.2

func _color_for_item(id: String) -> Color:
	if id.contains("blue"):
		return Color(0.38, 0.62, 1.0)
	if id.contains("green"):
		return Color(0.36, 0.84, 0.56)
	if id.contains("red"):
		return Color(0.9, 0.35, 0.35)
	if id.contains("orange"):
		return Color(0.93, 0.61, 0.31)
	if id.contains("yellow"):
		return Color(0.92, 0.82, 0.35)
	if id.contains("white"):
		return Color(0.95, 0.95, 0.98)
	if id.contains("black"):
		return Color(0.2, 0.2, 0.24)
	if id.contains("silver"):
		return Color(0.73, 0.77, 0.85)
	if id == "energy_crystal":
		return Color(0.28, 0.94, 0.94)
	return Color(0.8, 0.8, 0.8)
