extends Area3D

@export var location_id: String = ""

@onready var beacon_mesh: MeshInstance3D = $BeaconMesh
@onready var top_orb: MeshInstance3D = $TopOrb

var _triggered: bool = false
var _pulse_time: float = 0.0
var _last_visual_refresh_at: float = -10.0
var _is_unlocked_cached: bool = false

func _ready() -> void:
	add_to_group("location_marker")
	body_entered.connect(_on_body_entered)
	_ensure_runtime_materials()
	_apply_state_visual(true)

func _process(delta: float) -> void:
	_pulse_time += delta
	var shaft_pulse: float = 1.0 + sin(_pulse_time * 2.0) * 0.08
	beacon_mesh.scale = Vector3(1.0, shaft_pulse, 1.0)
	top_orb.scale = Vector3.ONE * (1.0 + sin(_pulse_time * 3.1) * 0.12)
	top_orb.position.y = 5.1 + sin(_pulse_time * 1.7) * 0.14

	if _pulse_time - _last_visual_refresh_at > 0.5:
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
	if not force and unlocked == _is_unlocked_cached:
		return
	_is_unlocked_cached = unlocked

	var shaft_material: StandardMaterial3D = beacon_mesh.material_override as StandardMaterial3D
	var orb_material: StandardMaterial3D = top_orb.material_override as StandardMaterial3D
	if shaft_material == null or orb_material == null:
		return

	var shaft_color: Color = Color(0.53, 0.86, 1.0, 0.48)
	var orb_color: Color = Color(0.6, 0.9, 1.0, 0.85)
	if unlocked:
		shaft_color = Color(0.52, 0.94, 0.58, 0.5)
		orb_color = Color(0.67, 1.0, 0.72, 0.9)

	shaft_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shaft_material.albedo_color = shaft_color
	shaft_material.emission_enabled = true
	shaft_material.emission = shaft_color * 1.35
	shaft_material.roughness = 0.2
	shaft_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	orb_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	orb_material.albedo_color = orb_color
	orb_material.emission_enabled = true
	orb_material.emission = orb_color * 1.45
	orb_material.roughness = 0.05
	orb_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
