extends Node3D

var _moons: Array = []
var _elapsed: float = 0.0

func _ready() -> void:
	_build_moons()

func _process(delta: float) -> void:
	_elapsed += delta
	for moon_entry in _moons:
		var pivot: Node3D = moon_entry["pivot"]
		var mesh_instance: MeshInstance3D = moon_entry["mesh"]
		var radius: float = moon_entry["radius"]
		var speed: float = moon_entry["speed"]
		var angle_offset: float = moon_entry["offset"]

		var angle = (_elapsed * speed) + angle_offset
		pivot.rotation.y = angle * 0.5
		mesh_instance.position = Vector3(cos(angle) * radius, 42.0 + sin(angle * 0.23) * 6.0, sin(angle) * radius)

func _build_moons() -> void:
	var moon_defs: Array = GameServices.data_service.get_moons()
	for moon_def in moon_defs:
		var pivot = Node3D.new()
		add_child(pivot)

		var mesh_instance = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = float(moon_def.get("scale", 1.5))
		sphere.height = sphere.radius * 2.0
		mesh_instance.mesh = sphere

		var material = StandardMaterial3D.new()
		material.albedo_color = Color(str(moon_def.get("color", "#ffffff")))
		material.emission_enabled = true
		material.emission = material.albedo_color * 0.35
		material.roughness = 0.25
		mesh_instance.material_override = material
		pivot.add_child(mesh_instance)

		_moons.append({
			"pivot": pivot,
			"mesh": mesh_instance,
			"radius": float(moon_def.get("orbit_radius", 80.0)),
			"speed": float(moon_def.get("orbit_speed", 0.04)),
			"offset": randf() * TAU
		})
