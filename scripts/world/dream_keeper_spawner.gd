extends Node3D

@export var day_night_cycle_path: NodePath
@export var dream_keeper_scene: PackedScene
@export var pickup_scene: PackedScene

var _rng = RandomNumberGenerator.new()
var _spawn_timer: float = 8.0
var _active_keeper: Node3D = null
var _active_life: float = 0.0

func _ready() -> void:
	_rng.seed = 8026

func _process(delta: float) -> void:
	if _active_keeper != null:
		_active_life -= delta
		_active_keeper.position.y += sin(Time.get_ticks_msec() * 0.01) * 0.002
		_active_keeper.rotate_y(delta * 0.8)
		if _active_life <= 0.0:
			_drop_seed_and_vanish()
		return

	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	_spawn_timer = _rng.randf_range(12.0, 24.0)

	var cycle = get_node_or_null(day_night_cycle_path)
	if cycle == null or not cycle.is_night():
		return
	if _rng.randf() > 0.35:
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

	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.push_message("Dream Seed dropped.")
