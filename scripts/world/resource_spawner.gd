extends Node3D

@export var world_spawner_path: NodePath
@export var resource_scene: PackedScene
@export var dust_nodes: int = 65
@export var crystal_nodes: int = 24
@export var starter_dust_nodes: int = 4
@export var starter_crystal_nodes: int = 3
@export var starter_ring_radius: float = 8.0

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

const STARTER_DUST_IDS = [
	"dust_blue",
	"dust_red",
	"dust_green",
	"dust_orange"
]

const STARTER_OFFSETS = [
	Vector2(5.0, 1.0),
	Vector2(-4.0, -3.0),
	Vector2(2.0, -6.0),
	Vector2(-6.5, 4.5),
	Vector2(7.0, -2.0),
	Vector2(-2.5, 7.0)
]

var _rng = RandomNumberGenerator.new()
var _resource_counter: int = 0
var _resource_catalog: Array = []

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
	_resource_counter = 0
	_resource_catalog = []

	_spawn_starter_resources(world_spawner)

	for _i in range(dust_nodes):
		_spawn_resource(world_spawner, true)
	for _i in range(crystal_nodes):
		_spawn_resource(world_spawner, false)
	_sync_authority_catalog()

func _spawn_resource(world_spawner: Node, is_dust: bool) -> void:
	var radius = world_spawner.get_world_radius() * 0.9
	var x = _rng.randf_range(-radius, radius)
	var z = _rng.randf_range(-radius, radius)
	if is_dust:
		var dust_id: String = DUST_IDS[_rng.randi_range(0, DUST_IDS.size() - 1)]
		_spawn_resource_at(world_spawner, Vector2(x, z), dust_id, _rng.randf_range(1.8, 3.4), 1, 3)
	else:
		_spawn_resource_at(world_spawner, Vector2(x, z), "energy_crystal", _rng.randf_range(2.8, 4.6), 1, 6)

func _spawn_starter_resources(world_spawner: Node) -> void:
	var dust_count: int = clamp(starter_dust_nodes, 2, STARTER_OFFSETS.size())
	var crystal_count: int = clamp(starter_crystal_nodes, 1, STARTER_OFFSETS.size())

	for i in range(dust_count):
		var dust_id: String = STARTER_DUST_IDS[i % STARTER_DUST_IDS.size()]
		var pos: Vector2 = _starter_position(i)
		_spawn_resource_at(world_spawner, pos, dust_id, 1.6, 1, 3)

	for i in range(crystal_count):
		var offset_index: int = (i + dust_count) % STARTER_OFFSETS.size()
		var pos: Vector2 = _starter_position(offset_index)
		_spawn_resource_at(world_spawner, pos, "energy_crystal", 2.6, 1, 6)

func _starter_position(index: int) -> Vector2:
	var base: Vector2 = STARTER_OFFSETS[index % STARTER_OFFSETS.size()]
	if base.length() > starter_ring_radius and starter_ring_radius > 0.0:
		base = base.normalized() * starter_ring_radius
	return base

func _spawn_resource_at(
	world_spawner: Node,
	position_xz: Vector2,
	item_id: String,
	durability: float,
	yield_quantity: int,
	credit_reward: int
) -> void:
	var world_position: Vector3 = world_spawner.get_surface_position(position_xz.x, position_xz.y) + Vector3(0, 0.65, 0)
	var resource_id: String = _allocate_resource_id(item_id)
	var world_flag_id: String = "resource_mined:%s" % resource_id
	if GameServices.get_world_flag(world_flag_id, false):
		return
	var resource = resource_scene.instantiate()
	resource.item_id = item_id
	resource.resource_id = resource_id
	resource.durability = max(0.5, durability)
	resource.yield_quantity = max(1, yield_quantity)
	resource.credit_reward = max(0, credit_reward)
	add_child(resource)
	resource.global_position = world_position
	_resource_catalog.append({
		"resource_id": resource_id,
		"item_id": item_id,
		"quantity": max(1, yield_quantity),
		"credits": max(0, credit_reward),
		"position": [world_position.x, world_position.y, world_position.z]
	})

func _allocate_resource_id(item_id: String) -> String:
	_resource_counter += 1
	return "resource_%04d_%s" % [_resource_counter, item_id]

func _sync_authority_catalog() -> void:
	if _resource_catalog.is_empty():
		return
	if GameServices.authority_service == null:
		return
	if not GameServices.authority_service.has_method("is_authority_connected") or not GameServices.authority_service.is_authority_connected():
		return
	var result: Dictionary = GameServices.authority_service.sync_resource_catalog(_resource_catalog)
	if not result.get("ok", false):
		push_warning("[ResourceSpawner] Authority resource sync failed: %s" % str(result.get("reason", "unknown")))
