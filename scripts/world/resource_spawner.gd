extends Node3D

@export var world_spawner_path: NodePath
@export var resource_scene: PackedScene
@export var dust_nodes: int = 65
@export var crystal_nodes: int = 24

const DUST_IDS = [
	"dust_blue",
	"dust_green",
	"dust_red",
	"dust_orange",
	"dust_yellow",
	"dust_white",
	"dust_black",
	"dust_silver"
]

var _rng = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 2026
	call_deferred("_spawn_all")

func _spawn_all() -> void:
	if resource_scene == null:
		push_error("ResourceSpawner missing resource scene.")
		return
	var world_spawner = get_node_or_null(world_spawner_path)
	if world_spawner == null:
		push_error("ResourceSpawner could not find WorldSpawner.")
		return

	for _i in range(dust_nodes):
		_spawn_resource(world_spawner, true)
	for _i in range(crystal_nodes):
		_spawn_resource(world_spawner, false)

func _spawn_resource(world_spawner: Node, is_dust: bool) -> void:
	var radius = world_spawner.get_world_radius() * 0.9
	var x = _rng.randf_range(-radius, radius)
	var z = _rng.randf_range(-radius, radius)
	var surface: Vector3 = world_spawner.get_surface_position(x, z)

	var resource = resource_scene.instantiate()
	add_child(resource)
	resource.global_position = surface + Vector3(0, 0.65, 0)
	if is_dust:
		resource.item_id = DUST_IDS[_rng.randi_range(0, DUST_IDS.size() - 1)]
		resource.durability = _rng.randf_range(1.8, 3.4)
		resource.yield_quantity = 1
		resource.credit_reward = 3
	else:
		resource.item_id = "energy_crystal"
		resource.durability = _rng.randf_range(2.8, 4.6)
		resource.yield_quantity = 1
		resource.credit_reward = 6
