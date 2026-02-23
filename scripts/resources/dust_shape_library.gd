extends RefCounted

class_name DustShapeLibrary

static func build_mesh(shape_id: String, scale: float = 1.0) -> Mesh:
	var s: float = max(scale, 0.05)
	match shape_id:
		"orb":
			var sphere := SphereMesh.new()
			sphere.radius = 0.33 * s
			sphere.height = 0.66 * s
			return sphere
		"cube":
			var box := BoxMesh.new()
			box.size = Vector3(0.52, 0.52, 0.52) * s
			return box
		"tetra":
			return _build_tetra_mesh(0.42 * s)
		"prism":
			var prism := PrismMesh.new()
			prism.left_to_right = 0.35
			prism.size = Vector3(0.6, 0.58, 0.48) * s
			return prism
		"capsule":
			var capsule := CapsuleMesh.new()
			capsule.radius = 0.22 * s
			capsule.height = 0.75 * s
			return capsule
		"ring":
			var torus := TorusMesh.new()
			torus.inner_radius = 0.12 * s
			torus.outer_radius = 0.34 * s
			torus.rings = 18
			torus.ring_segments = 14
			return torus
		"octa":
			return _build_octa_mesh(0.36 * s)
		"spindle":
			var spindle := CylinderMesh.new()
			spindle.top_radius = 0.1 * s
			spindle.bottom_radius = 0.26 * s
			spindle.height = 0.74 * s
			spindle.radial_segments = 12
			return spindle
		_:
			var fallback := SphereMesh.new()
			fallback.radius = 0.3 * s
			fallback.height = 0.6 * s
			return fallback

static func build_collision_shape(shape_id: String, size_hint: float = 0.45) -> Shape3D:
	var s: float = max(size_hint, 0.1)
	match shape_id:
		"cube":
			var box := BoxShape3D.new()
			box.size = Vector3(0.5, 0.5, 0.5) * s * 2.0
			return box
		"capsule":
			var capsule := CapsuleShape3D.new()
			capsule.radius = 0.22 * s * 2.0
			capsule.height = 0.7 * s * 2.0
			return capsule
		"ring":
			var cyl := CylinderShape3D.new()
			cyl.radius = 0.34 * s * 1.6
			cyl.height = 0.22 * s * 2.0
			return cyl
		"prism", "spindle", "tetra", "octa":
			var convex := SphereShape3D.new()
			convex.radius = 0.33 * s * 2.0
			return convex
		_:
			var sphere := SphereShape3D.new()
			sphere.radius = 0.33 * s * 2.0
			return sphere

static func _build_tetra_mesh(radius: float) -> ArrayMesh:
	var v0 := Vector3(0.0, radius, 0.0)
	var v1 := Vector3(-radius, -radius, radius)
	var v2 := Vector3(radius, -radius, radius)
	var v3 := Vector3(0.0, -radius, -radius)
	return _build_indexed_mesh(
		[v0, v1, v2, v3],
		[
			PackedInt32Array([0, 2, 1]),
			PackedInt32Array([0, 1, 3]),
			PackedInt32Array([0, 3, 2]),
			PackedInt32Array([1, 2, 3])
		]
	)

static func _build_octa_mesh(radius: float) -> ArrayMesh:
	var top := Vector3(0.0, radius, 0.0)
	var bottom := Vector3(0.0, -radius, 0.0)
	var left := Vector3(-radius, 0.0, 0.0)
	var right := Vector3(radius, 0.0, 0.0)
	var front := Vector3(0.0, 0.0, radius)
	var back := Vector3(0.0, 0.0, -radius)
	return _build_indexed_mesh(
		[top, bottom, left, right, front, back],
		[
			PackedInt32Array([0, 4, 3]),
			PackedInt32Array([0, 2, 4]),
			PackedInt32Array([0, 5, 2]),
			PackedInt32Array([0, 3, 5]),
			PackedInt32Array([1, 3, 4]),
			PackedInt32Array([1, 4, 2]),
			PackedInt32Array([1, 2, 5]),
			PackedInt32Array([1, 5, 3])
		]
	)

static func _build_indexed_mesh(vertices: Array, faces: Array) -> ArrayMesh:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	for face in faces:
		if face.size() < 3:
			continue
		var a: Vector3 = vertices[face[0]]
		var b: Vector3 = vertices[face[1]]
		var c: Vector3 = vertices[face[2]]
		var normal: Vector3 = (b - a).cross(c - a).normalized()
		surface_tool.set_normal(normal)
		surface_tool.add_vertex(a)
		surface_tool.set_normal(normal)
		surface_tool.add_vertex(b)
		surface_tool.set_normal(normal)
		surface_tool.add_vertex(c)

	return surface_tool.commit()
