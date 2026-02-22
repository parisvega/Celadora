extends Node3D

@export var world_radius_tiles: int = 24
@export var tile_size: float = 2.0
@export var height_scale: float = 4.0
@export var seed: int = 1337

var _height_noise: FastNoiseLite
var _biome_noise: FastNoiseLite
var _height_map: Dictionary = {}
var _biome_map: Dictionary = {}

func _ready() -> void:
	add_to_group("world_spawner")
	_generate_world()

func _generate_world() -> void:
	_spawn_fallback_landmark()
	_height_map.clear()
	_biome_map.clear()

	_height_noise = FastNoiseLite.new()
	_height_noise.seed = seed
	_height_noise.frequency = 0.05
	_height_noise.fractal_octaves = 4
	_height_noise.fractal_gain = 0.55

	_biome_noise = FastNoiseLite.new()
	_biome_noise.seed = seed + 41
	_biome_noise.frequency = 0.03
	_biome_noise.fractal_octaves = 3

	for x in range(-world_radius_tiles, world_radius_tiles + 1):
		for z in range(-world_radius_tiles, world_radius_tiles + 1):
			var world_x = float(x) * tile_size
			var world_z = float(z) * tile_size
			var height = _sample_height(x, z)
			var biome = _sample_biome(x, z, height)
			_spawn_tile(world_x, world_z, height, biome)
			_height_map[_key(x, z)] = height
			_biome_map[_key(x, z)] = biome

func _sample_height(x: int, z: int) -> float:
	var n = _height_noise.get_noise_2d(float(x), float(z))
	var h = (n + 1.0) * 0.5
	return 1.0 + h * height_scale

func _sample_biome(x: int, z: int, height: float) -> String:
	var b = _biome_noise.get_noise_2d(float(x), float(z))
	if height < 2.1 or b < -0.25:
		return "shore"
	if b > 0.35 or height > 3.6:
		return "highlands"
	return "jungle"

func _spawn_tile(world_x: float, world_z: float, height: float, biome: String) -> void:
	var body = StaticBody3D.new()
	body.name = "Tile"
	add_child(body)

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = _create_tile_mesh()
	mesh_instance.material_override = _create_biome_material(biome)
	body.add_child(mesh_instance)

	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(tile_size, 1.0, tile_size)
	collision.shape = shape
	body.add_child(collision)

	body.position = Vector3(world_x, height - 0.5, world_z)

	if biome == "jungle":
		_spawn_foliage(world_x, height, world_z)

func _spawn_foliage(world_x: float, height: float, world_z: float) -> void:
	var chance = randf()
	if chance > 0.06:
		return
	var stem = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.15
	cylinder.bottom_radius = 0.2
	cylinder.height = randf_range(1.0, 2.6)
	stem.mesh = cylinder

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.1, 0.45, 0.2)
	material.roughness = 0.9
	stem.material_override = material
	stem.position = Vector3(world_x + randf_range(-0.4, 0.4), height + (cylinder.height * 0.5), world_z + randf_range(-0.4, 0.4))
	add_child(stem)

func get_surface_position(world_x: float, world_z: float) -> Vector3:
	var tile_x = int(round(world_x / tile_size))
	var tile_z = int(round(world_z / tile_size))
	var key = _key(tile_x, tile_z)
	if _height_map.has(key):
		return Vector3(world_x, float(_height_map[key]), world_z)
	return Vector3(world_x, _sample_height(tile_x, tile_z), world_z)

func get_world_radius() -> float:
	return float(world_radius_tiles) * tile_size

func get_biome_name_at_position(world_x: float, world_z: float) -> String:
	var tile_x: int = int(round(world_x / tile_size))
	var tile_z: int = int(round(world_z / tile_size))
	var key: String = _key(tile_x, tile_z)
	if _biome_map.has(key):
		return _biome_display_name(str(_biome_map[key]))
	var sampled_biome: String = _sample_biome(tile_x, tile_z, _sample_height(tile_x, tile_z))
	return _biome_display_name(sampled_biome)

func _key(x: int, z: int) -> String:
	return "%d:%d" % [x, z]

func _create_tile_mesh() -> Mesh:
	var box = BoxMesh.new()
	box.size = Vector3(tile_size, 1.0, tile_size)
	return box

func _create_biome_material(biome: String) -> Material:
	var material = StandardMaterial3D.new()
	match biome:
		"shore":
			material.albedo_color = Color(0.72, 0.67, 0.47)
		"highlands":
			material.albedo_color = Color(0.42, 0.45, 0.5)
		_:
			material.albedo_color = Color(0.2, 0.45, 0.24)
	material.roughness = 1.0
	return material

func _biome_display_name(biome_id: String) -> String:
	match biome_id:
		"shore":
			return "Shore"
		"highlands":
			return "Highlands"
		_:
			return "Jungle"

func _spawn_fallback_landmark() -> void:
	# Keep a guaranteed visible surface in Web builds even if procedural generation lags.
	var ground_body = StaticBody3D.new()
	add_child(ground_body)
	ground_body.position = Vector3(0.0, 0.0, 0.0)

	var ground_mesh = MeshInstance3D.new()
	var ground_box = BoxMesh.new()
	ground_box.size = Vector3(36.0, 1.0, 36.0)
	ground_mesh.mesh = ground_box
	var ground_material = StandardMaterial3D.new()
	ground_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ground_material.albedo_color = Color(0.16, 0.32, 0.22)
	ground_mesh.material_override = ground_material
	ground_body.add_child(ground_mesh)

	var ground_collision = CollisionShape3D.new()
	var ground_shape = BoxShape3D.new()
	ground_shape.size = Vector3(36.0, 1.0, 36.0)
	ground_collision.shape = ground_shape
	ground_body.add_child(ground_collision)

	var beacon = MeshInstance3D.new()
	var beacon_mesh = BoxMesh.new()
	beacon_mesh.size = Vector3(1.2, 8.0, 1.2)
	beacon.mesh = beacon_mesh
	beacon.position = Vector3(0.0, 4.5, -10.0)
	var beacon_material = StandardMaterial3D.new()
	beacon_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beacon_material.albedo_color = Color(1.0, 0.25, 0.55)
	beacon.material_override = beacon_material
	add_child(beacon)
