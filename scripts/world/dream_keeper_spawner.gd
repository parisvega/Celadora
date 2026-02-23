extends Node3D

@export var day_night_cycle_path: NodePath
@export var dream_keeper_scene: PackedScene
@export var pickup_scene: PackedScene
@export var min_night_spawn_interval_sec: float = 10.0
@export var max_night_spawn_interval_sec: float = 18.0
@export var guaranteed_first_spawn_sec: float = 14.0
@export var night_spawn_chance: float = 0.7
@export var guarantee_if_missing_seed: bool = true

var _rng = RandomNumberGenerator.new()
var _spawn_timer: float = 8.0
var _active_keeper: Node3D = null
var _active_life: float = 0.0
var _night_elapsed: float = 0.0
var _spawned_this_night: bool = false
var _cycle: Node = null

func _ready() -> void:
	add_to_group("dream_keeper_spawner")
	_rng.seed = 8026
	_cycle = get_node_or_null(day_night_cycle_path)
	if _cycle != null and _cycle.has_signal("night_state_changed"):
		_cycle.connect("night_state_changed", Callable(self, "_on_night_state_changed"))
		if _cycle.has_method("is_night"):
			_on_night_state_changed(bool(_cycle.is_night()))
		else:
			_on_night_state_changed(false)
	else:
		_reset_spawn_timer()

func _process(delta: float) -> void:
	if _active_keeper != null:
		_active_life -= delta
		_active_keeper.position.y += sin(Time.get_ticks_msec() * 0.01) * 0.002
		_active_keeper.rotate_y(delta * 0.8)
		if _active_life <= 0.0:
			_drop_seed_and_vanish()
		return

	if not _is_night():
		return

	_night_elapsed += delta
	_spawn_timer -= delta

	if _should_force_spawn():
		_spawn_keeper()
		return

	if _spawn_timer > 0.0:
		return

	_reset_spawn_timer()
	var spawn_roll: float = _rng.randf()
	var chance: float = night_spawn_chance
	if _spawned_this_night:
		chance = min(0.4, night_spawn_chance * 0.6)
	if spawn_roll > chance:
		return
	_spawn_keeper()

func _spawn_keeper() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null or dream_keeper_scene == null:
		return
	_active_keeper = dream_keeper_scene.instantiate()
	get_parent().add_child(_active_keeper)
	_active_keeper.global_position = player.global_position + Vector3(
		_rng.randf_range(-9.0, 9.0),
		_rng.randf_range(2.0, 4.0),
		_rng.randf_range(-9.0, 9.0)
	)
	_active_life = _rng.randf_range(6.0, 11.0)
	_spawned_this_night = true
	GameServices.log_event("dream_keeper.spawned", {
		"position": [_active_keeper.global_position.x, _active_keeper.global_position.y, _active_keeper.global_position.z],
		"night_elapsed": _night_elapsed
	})

	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.push_message("A Dream Keeper passes through the night...")

func _drop_seed_and_vanish() -> void:
	if _active_keeper == null:
		return
	var drop_position = _active_keeper.global_position
	_active_keeper.queue_free()
	_active_keeper = null

	if pickup_scene != null:
		var pickup = pickup_scene.instantiate()
		get_parent().add_child(pickup)
		pickup.item_id = "dream_seed"
		pickup.quantity = 1
		pickup.credits = 0
		pickup.global_position = drop_position
	GameServices.log_event("dream_keeper.seed_dropped", {
		"position": [drop_position.x, drop_position.y, drop_position.z]
	})

	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.push_message("Dream Seed dropped.")

func get_status() -> Dictionary:
	var is_night: bool = _is_night()
	var eta: float = -1.0
	if is_night and _active_keeper == null:
		eta = max(_spawn_timer, 0.0)
		if not _spawned_this_night and guaranteed_first_spawn_sec > _night_elapsed:
			var forced_eta: float = guaranteed_first_spawn_sec - _night_elapsed
			if eta <= 0.0:
				eta = forced_eta
			else:
				eta = min(eta, forced_eta)
	return {
		"is_night": is_night,
		"active": _active_keeper != null,
		"spawned_this_night": _spawned_this_night,
		"eta_sec": eta,
		"night_elapsed": _night_elapsed
	}

func _on_night_state_changed(is_night: bool) -> void:
	if is_night:
		_night_elapsed = 0.0
		_spawned_this_night = false
		_reset_spawn_timer()
	else:
		_night_elapsed = 0.0
		_spawned_this_night = false
		_reset_spawn_timer()

func _should_force_spawn() -> bool:
	if _spawned_this_night:
		return false
	if _night_elapsed < guaranteed_first_spawn_sec:
		return false
	if not guarantee_if_missing_seed:
		return true
	if GameServices.inventory_service == null:
		return true
	return GameServices.inventory_service.get_quantity("dream_seed") <= 0

func _reset_spawn_timer() -> void:
	_spawn_timer = _rng.randf_range(
		min(min_night_spawn_interval_sec, max_night_spawn_interval_sec),
		max(min_night_spawn_interval_sec, max_night_spawn_interval_sec)
	)

func _is_night() -> bool:
	if _cycle == null:
		_cycle = get_node_or_null(day_night_cycle_path)
	if _cycle == null:
		return false
	if _cycle.has_method("is_night"):
		return bool(_cycle.is_night())
	return false
