extends Area3D

@export var location_id: String = ""

@onready var beacon_mesh: MeshInstance3D = $BeaconMesh
@onready var top_orb: MeshInstance3D = $TopOrb

var _triggered: bool = false
var _pulse_time: float = 0.0
var _last_visual_refresh_at: float = -10.0
var _is_unlocked_cached: bool = false
var _is_route_target_cached: bool = false

func _ready() -> void:
	add_to_group("location_marker")
	body_entered.connect(_on_body_entered)
	_ensure_runtime_materials()
	_apply_state_visual(true)

func _process(delta: float) -> void:
	_pulse_time += delta
	var route_boost: float = 1.26 if _is_route_target_cached and not _is_unlocked_cached else 1.0
	var shaft_pulse: float = 1.0 + sin(_pulse_time * 2.0) * 0.08
	beacon_mesh.scale = Vector3(route_boost, shaft_pulse * route_boost, route_boost)
	top_orb.scale = Vector3.ONE * ((1.0 + sin(_pulse_time * 3.1) * 0.12) * route_boost)
	top_orb.position.y = 5.1 + sin(_pulse_time * 1.7) * 0.14

	if _pulse_time - _last_visual_refresh_at > 0.35:
		_last_visual_refresh_at = _pulse_time
		_apply_state_visual(false)

func _on_body_entered(body: Node) -> void:
	if _triggered:
		return
	if not body.is_in_group("player"):
		return
	_triggered = true
	if GameServices.lore_journal_service.unlock_entry(location_id):
		var location = GameServices.data_service.get_location(location_id)
		var title = str(location.get("name", location_id))
		var hud = get_tree().get_first_node_in_group("hud")
		if hud:
			hud.push_message("Lore unlocked: %s" % title)
	_apply_state_visual(true)

func _ensure_runtime_materials() -> void:
	if beacon_mesh.material_override == null:
		beacon_mesh.material_override = StandardMaterial3D.new()
	else:
		beacon_mesh.material_override = beacon_mesh.material_override.duplicate(true)
	if top_orb.material_override == null:
		top_orb.material_override = StandardMaterial3D.new()
	else:
		top_orb.material_override = top_orb.material_override.duplicate(true)

func _apply_state_visual(force: bool) -> void:
	var unlocked: bool = false
	if GameServices.lore_journal_service != null:
		unlocked = GameServices.lore_journal_service.is_unlocked(location_id)
	var route_target: bool = _is_route_target()
	if not force and unlocked == _is_unlocked_cached and route_target == _is_route_target_cached:
		return
	_is_unlocked_cached = unlocked
	_is_route_target_cached = route_target

	var shaft_material: StandardMaterial3D = beacon_mesh.material_override as StandardMaterial3D
	var orb_material: StandardMaterial3D = top_orb.material_override as StandardMaterial3D
	if shaft_material == null or orb_material == null:
		return

	var shaft_color: Color = Color(0.53, 0.86, 1.0, 0.48)
	var orb_color: Color = Color(0.6, 0.9, 1.0, 0.85)
	if unlocked:
		shaft_color = Color(0.52, 0.94, 0.58, 0.5)
		orb_color = Color(0.67, 1.0, 0.72, 0.9)
	elif route_target:
		shaft_color = Color(1.0, 0.82, 0.32, 0.58)
		orb_color = Color(1.0, 0.9, 0.45, 0.96)

	shaft_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shaft_material.albedo_color = shaft_color
	shaft_material.emission_enabled = true
	shaft_material.emission = shaft_color * (1.75 if route_target else 1.35)
	shaft_material.roughness = 0.2
	shaft_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	orb_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	orb_material.albedo_color = orb_color
	orb_material.emission_enabled = true
	orb_material.emission = orb_color * (1.95 if route_target else 1.45)
	orb_material.roughness = 0.05
	orb_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

func _is_route_target() -> bool:
	if location_id.is_empty():
		return false
	if GameServices.lore_journal_service == null:
		return false
	if GameServices.lore_journal_service.is_unlocked(location_id):
		return false
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return false

	var best_distance: float = INF
	var best_location_id: String = ""
	for marker in get_tree().get_nodes_in_group("location_marker"):
		if not (marker is Node3D):
			continue
		var marker_id: String = str(marker.get("location_id"))
		if marker_id.is_empty():
			continue
		if GameServices.lore_journal_service.is_unlocked(marker_id):
			continue
		var marker_3d: Node3D = marker as Node3D
		var distance: float = player.global_position.distance_to(marker_3d.global_position)
		if distance < best_distance:
			best_distance = distance
			best_location_id = marker_id

	return best_location_id == location_id
