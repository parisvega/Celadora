extends CharacterBody3D

@export var enemy_id: String = "greegion_miner_bot"
@export var pickup_scene: PackedScene

var _stats: Dictionary = {}
var _hp: float = 30.0
var _spawn_position: Vector3
var _patrol_target: Vector3
var _attack_cooldown_left: float = 0.0

func _ready() -> void:
	_spawn_position = global_position
	_load_stats()
	_pick_patrol_target()

func _physics_process(delta: float) -> void:
	if _attack_cooldown_left > 0.0:
		_attack_cooldown_left -= delta

	var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
	if not is_on_floor():
		velocity.y -= gravity * delta

	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		_patrol(delta)
		move_and_slide()
		return

	var player_pos: Vector3 = player.global_position
	var to_player = player_pos - global_position
	var distance = to_player.length()
	var aggro_multiplier = 1.0 + GameServices.inventory_service.get_modifier_value("aggro_radius_multiplier", 0.0)
	var aggro_range = max(float(_stats.get("aggro_range", 12.0)) * aggro_multiplier, 4.0)

	if distance <= 1.9:
		_attack(player)
		velocity.x = 0.0
		velocity.z = 0.0
	elif distance <= aggro_range:
		_chase_player(to_player.normalized())
	else:
		_patrol(delta)

	move_and_slide()

func take_damage(amount: float) -> void:
	_hp -= amount
	if _hp <= 0.0:
		_die()

func _load_stats() -> void:
	_stats = GameServices.get_enemy_def(enemy_id)
	if _stats.is_empty():
		_stats = {
			"max_hp": 40,
			"move_speed": 3.2,
			"attack_damage": 6,
			"attack_cooldown": 1.2,
			"aggro_range": 12.0,
			"patrol_radius": 8.0,
			"drops": [{"item_id": "bot_scrap", "quantity": 1}],
			"credit_reward": 10
		}
	_hp = float(_stats.get("max_hp", 40.0))

func _chase_player(direction: Vector3) -> void:
	var speed = float(_stats.get("move_speed", 3.2))
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	look_at(global_position + Vector3(direction.x, 0, direction.z), Vector3.UP)

func _patrol(_delta: float) -> void:
	var planar = _patrol_target - global_position
	planar.y = 0.0
	if planar.length() < 1.0:
		_pick_patrol_target()
		planar = _patrol_target - global_position
	var speed = float(_stats.get("move_speed", 3.2)) * 0.65
	var dir = planar.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if dir.length() > 0.0:
		look_at(global_position + Vector3(dir.x, 0, dir.z), Vector3.UP)

func _pick_patrol_target() -> void:
	var radius = float(_stats.get("patrol_radius", 8.0))
	_patrol_target = _spawn_position + Vector3(randf_range(-radius, radius), 0.0, randf_range(-radius, radius))

func _attack(player: Node) -> void:
	if _attack_cooldown_left > 0.0:
		return
	_attack_cooldown_left = float(_stats.get("attack_cooldown", 1.2))
	if player.has_method("receive_damage"):
		player.receive_damage(float(_stats.get("attack_damage", 6.0)))

func _die() -> void:
	if pickup_scene != null:
		for drop in _stats.get("drops", []):
			var pickup = pickup_scene.instantiate()
			get_parent().add_child(pickup)
			pickup.item_id = str(drop.get("item_id", "bot_scrap"))
			pickup.quantity = int(drop.get("quantity", 1))
			pickup.credits = int(_stats.get("credit_reward", 0))
			pickup.global_position = global_position + Vector3(randf_range(-0.6, 0.6), 0.7, randf_range(-0.6, 0.6))
	queue_free()
