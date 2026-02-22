extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var world_spawner: Node3D = $World/WorldSpawner

var _autosave_timer: float = 0.0
const AUTOSAVE_INTERVAL = 30.0

func _ready() -> void:
	GameServices.bootstrap()
	if hud.has_method("set_player"):
		hud.set_player(player)

	var save_data: Dictionary = GameServices.save_service.get_loaded_state()
	var web_force_fresh_spawn: bool = OS.has_feature("web")
	if not web_force_fresh_spawn and save_data.has("player_state"):
		player.load_from_save(save_data["player_state"])
	else:
		player.global_position = Vector3(0.0, 8.0, 0.0)
		player.set_spawn_position(player.global_position)
	_ensure_safe_spawn()

	var welcome_hud = get_tree().get_first_node_in_group("hud")
	if welcome_hud:
		welcome_hud.push_message("Welcome to Celadora v0.1")

func _process(delta: float) -> void:
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		GameServices.save_now(player.to_save_data())

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		GameServices.save_now(player.to_save_data())

func _ensure_safe_spawn() -> void:
	if world_spawner == null or not world_spawner.has_method("get_surface_position"):
		return

	var pos: Vector3 = player.global_position
	if world_spawner.has_method("get_world_radius"):
		var radius: float = float(world_spawner.get_world_radius())
		if radius > 0.0:
			pos.x = clamp(pos.x, -radius * 0.95, radius * 0.95)
			pos.z = clamp(pos.z, -radius * 0.95, radius * 0.95)

	if is_nan(pos.x) or is_nan(pos.y) or is_nan(pos.z):
		pos = Vector3(0.0, 8.0, 0.0)

	var surface: Vector3 = world_spawner.get_surface_position(pos.x, pos.z)
	var min_safe_y: float = surface.y + 2.2
	var max_safe_y: float = surface.y + 30.0
	pos.y = clamp(pos.y, min_safe_y, max_safe_y)

	player.global_position = pos
	player.set_spawn_position(pos)
