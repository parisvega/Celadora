extends Area3D

@export var item_id: String = "bot_scrap"
@export var quantity: int = 1
@export var credits: int = 0

@onready var mesh_node: MeshInstance3D = $Mesh

var _collected: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_update_visual()

func _process(delta: float) -> void:
	rotate_y(delta * 1.2)

func _on_body_entered(body: Node) -> void:
	if _collected:
		return
	if body.is_in_group("player"):
		collect()

func interact(_player: Node) -> Dictionary:
	collect()
	return {"ok": true}

func collect() -> void:
	if _collected:
		return
	_collected = true
	if item_id != "":
		GameServices.inventory_service.add_item(item_id, max(quantity, 1))
	if credits > 0:
		GameServices.inventory_service.add_credits(credits)

	var item_name = item_id
	var item_def = GameServices.data_service.get_item(item_id)
	if not item_def.is_empty():
		item_name = item_def.get("name", item_id)
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.push_message("Picked up %s x%d" % [item_name, max(quantity, 1)])
	queue_free()

func _update_visual() -> void:
	var sphere = SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	mesh_node.mesh = sphere

	var material = StandardMaterial3D.new()
	material.emission_enabled = true
	material.albedo_color = Color(0.75, 0.93, 1.0)
	material.emission = Color(0.38, 0.72, 0.9)
	mesh_node.material_override = material
