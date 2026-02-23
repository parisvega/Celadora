extends CharacterBody3D

signal stats_updated
signal interaction_hint_changed(text: String)
signal interaction_target_changed(status: Dictionary)
signal damaged(amount: float)

@export var walk_speed: float = 5.2
@export var run_speed: float = 8.0
@export var jump_velocity: float = 5.4
@export var look_sensitivity: float = 0.0025
@export var base_damage: float = 10.0
@export var mining_cooldown: float = 0.25
@export var attack_cooldown: float = 0.4

@onready var camera: Camera3D = $Camera
@onready var interaction_ray: RayCast3D = $Camera/InteractionRay
@onready var viewmodel: Node = $Camera/ViewModelRig

const PickupItemScene = preload("res://scenes/world/PickupItem.tscn")

var max_health: float = 100.0
var max_stamina: float = 100.0
var max_shield: float = 100.0

var health: float = 100.0
var stamina: float = 100.0
var shield: float = 0.0

var _mouse_captured: bool = true
var _mine_cd_left: float = 0.0
var _attack_cd_left: float = 0.0
var _spawn_position: Vector3
var _last_interaction_hint: String = ""
var _last_interaction_signature: String = ""

var _pending_action_kind: String = ""
var _pending_action_target_id: int = 0
var _pending_action_payload: Dictionary = {}
var _pending_action_timer: float = 0.0

const DUST_ITEM_IDS = [
	"dust_blue",
	"dust_green",
	"dust_red",
	"dust_orange",
	"dust_yellow",
	"dust_white",
	"dust_black",
	"dust_silver"
]

func _ready() -> void:
	_setup_input_map()
	add_to_group("player")
	_spawn_position = global_position
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if GameServices.inventory_service:
		GameServices.inventory_service.inventory_changed.connect(_on_inventory_changed)
	if viewmodel != null and viewmodel.has_signal("action_impact"):
		viewmodel.action_impact.connect(_on_viewmodel_action_impact)
	_refresh_viewmodel_state()
	_emit_stats()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _mouse_captured:
		rotate_y(-event.relative.x * look_sensitivity)
		camera.rotate_x(-event.relative.y * look_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))
		if viewmodel != null and viewmodel.has_method("apply_look_delta"):
			viewmodel.apply_look_delta(event.relative)
	elif event.is_action_pressed("toggle_mouse"):
		_toggle_mouse_capture()

func _physics_process(delta: float) -> void:
	if _mine_cd_left > 0.0:
		_mine_cd_left -= delta
	if _attack_cd_left > 0.0:
		_attack_cd_left -= delta
	if _pending_action_kind != "":
		_pending_action_timer -= delta
		if _pending_action_timer <= 0.0:
			_resolve_pending_action()

	if Input.is_action_just_pressed("save_game"):
		GameServices.save_now(to_save_data())
		GameServices.log_event("player.manual_save", {"position": [global_position.x, global_position.y, global_position.z]})
		var hud = get_tree().get_first_node_in_group("hud")
		if hud:
			hud.push_message("Game saved.")
	if Input.is_action_just_pressed("reset_progress"):
		var reset_result: Dictionary = GameServices.reset_local_progress()
		GameServices.log_event("player.progress_reset", {"ok": reset_result.get("ok", false)})
		_respawn()
		var hud_reset = get_tree().get_first_node_in_group("hud")
		if hud_reset:
			hud_reset.push_message(str(reset_result.get("reason", "Reset complete.")))
	if Input.is_action_just_pressed("skip_time"):
		_skip_time_phase()

	if Input.is_action_just_pressed("interact"):
		_handle_interact()
	if Input.is_action_just_pressed("primary_action"):
		_handle_primary_action()

	var gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	var gravity_resistance: float = clamp(GameServices.inventory_service.get_modifier_value("gravity_resistance", 0.0), 0.0, 0.75)
	var effective_gravity: float = gravity * (1.0 - gravity_resistance)
	if not is_on_floor():
		velocity.y -= effective_gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		var jump_boost: float = max(0.0, GameServices.inventory_service.get_modifier_value("jump_boost", 0.0))
		velocity.y = jump_velocity * (1.0 + jump_boost)

	var movement_input = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	)
	movement_input = movement_input.normalized()

	var basis = global_transform.basis
	var direction = (basis.x * movement_input.x + -basis.z * movement_input.y).normalized()
	var speed_bonus = 1.0 + GameServices.inventory_service.get_modifier_value("move_speed", 0.0)
	var is_running = Input.is_action_pressed("run") and stamina > 0.0
	var speed = walk_speed * speed_bonus
	if is_running:
		speed = run_speed * speed_bonus
		stamina = max(stamina - 18.0 * delta, 0.0)

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	_apply_regeneration(delta)
	_update_interaction_hint()
	_update_viewmodel_motion(is_running, speed_bonus)
	move_and_slide()
	_emit_stats()

func _apply_regeneration(delta: float) -> void:
	var health_regen = 1.8 + (GameServices.inventory_service.get_modifier_value("health_regen", 0.0) * 10.0)
	var stamina_regen = 15.0 + (GameServices.inventory_service.get_modifier_value("stamina_regen", 0.0) * 20.0)
	var shield_regen = GameServices.inventory_service.get_modifier_value("shield_regen", 0.0) * 10.0

	health = min(max_health, health + health_regen * delta)
	stamina = min(max_stamina, stamina + stamina_regen * delta)
	shield = min(max_shield, shield + shield_regen * delta)

func _handle_primary_action() -> void:
	if interaction_ray == null:
		return
	interaction_ray.force_raycast_update()
	if not interaction_ray.is_colliding():
		return

	var collider = interaction_ray.get_collider()
	if collider == null:
		return

	if collider.has_method("mine"):
		_begin_mine_action(collider)
		return
	if collider.has_method("take_damage"):
		_begin_attack_action(collider)
		return
	if collider.has_method("collect"):
		collider.collect()

func _handle_interact() -> void:
	interaction_ray.force_raycast_update()
	if not interaction_ray.is_colliding():
		return
	var collider = interaction_ray.get_collider()
	if collider and collider.has_method("interact"):
		collider.interact(self)
		GameServices.log_event("player.interact", {
			"target": _target_name(collider)
		})

func _begin_mine_action(node: Object) -> void:
	if _mine_cd_left > 0.0 or _pending_action_kind != "":
		return
	var mining_bonus: float = GameServices.inventory_service.get_modifier_value("mining_speed", 0.0)
	_mine_cd_left = max(0.08, mining_cooldown * (1.0 - mining_bonus))
	var mine_power: float = 1.0 + (mining_bonus * 1.2)
	var impact_time: float = _play_viewmodel_action("mine")
	_queue_pending_action("mine", node, {
		"mine_power": mine_power,
		"queued_from": [global_position.x, global_position.y, global_position.z]
	}, impact_time)

func _begin_attack_action(enemy: Object) -> void:
	if _attack_cd_left > 0.0 or _pending_action_kind != "":
		return
	_attack_cd_left = attack_cooldown
	var damage: float = base_damage * (1.0 + GameServices.inventory_service.get_modifier_value("damage_bonus", 0.0))
	var critical_chance: float = clamp(GameServices.inventory_service.get_modifier_value("critical_chance", 0.0), 0.0, 0.75)
	var is_critical: bool = randf() < critical_chance
	if is_critical:
		damage *= 1.65
	var impact_time: float = _play_viewmodel_action("attack")
	_queue_pending_action("attack", enemy, {
		"damage": damage,
		"is_critical": is_critical,
		"queued_from": [global_position.x, global_position.y, global_position.z]
	}, impact_time)

func _queue_pending_action(action_kind: String, target: Object, payload: Dictionary, delay_sec: float) -> void:
	if target == null:
		return
	_pending_action_kind = action_kind
	_pending_action_target_id = target.get_instance_id()
	_pending_action_payload = payload.duplicate(true)
	_pending_action_timer = max(delay_sec, 0.0)
	if _pending_action_timer <= 0.0:
		_resolve_pending_action()

func _resolve_pending_action() -> void:
	if _pending_action_kind == "":
		return

	var action_kind: String = _pending_action_kind
	var target_id: int = _pending_action_target_id
	var payload: Dictionary = _pending_action_payload.duplicate(true)

	_pending_action_kind = ""
	_pending_action_target_id = 0
	_pending_action_payload = {}
	_pending_action_timer = 0.0

	var target: Object = instance_from_id(target_id)
	if target == null:
		return

	match action_kind:
		"mine":
			_resolve_mine_action(target, payload)
		"attack":
			_resolve_attack_action(target, payload)

func _resolve_mine_action(target: Object, payload: Dictionary) -> void:
	if not target.has_method("mine"):
		return
	if not _target_within_reach(target, 5.6):
		return

	var mine_power: float = float(payload.get("mine_power", 1.0))
	var result: Dictionary = target.mine(mine_power)
	if not result.get("mined", false):
		return

	var item_id = str(result.get("item_id", ""))
	var quantity = int(result.get("quantity", 1))
	var credits_reward = int(result.get("credits", 0))
	if item_id != "":
		var item_def: Dictionary = GameServices.get_item_def(item_id)
		var tags: Array = item_def.get("tags", [])
		if tags.has("dust"):
			_spawn_mined_dust_pickup(item_id, quantity, _drop_position_from_target(target))
		else:
			GameServices.inventory_service.add_item(item_id, quantity)
	if credits_reward > 0:
		GameServices.inventory_service.add_credits(credits_reward)

	GameServices.log_event("mining.node_mined", {
		"item_id": item_id,
		"quantity": quantity,
		"credits": credits_reward,
		"position": [global_position.x, global_position.y, global_position.z]
	})

func _resolve_attack_action(target: Object, payload: Dictionary) -> void:
	if not target.has_method("take_damage"):
		return
	if not _target_within_reach(target, 4.8):
		return

	var damage: float = float(payload.get("damage", base_damage))
	var is_critical: bool = bool(payload.get("is_critical", false))
	target.take_damage(damage)
	var event_payload: Dictionary = {
		"damage": damage,
		"is_critical": is_critical,
		"target": target.name,
		"player_position": [global_position.x, global_position.y, global_position.z]
	}
	var event_envelope: Dictionary = GameServices.network_service.wrap_client_event(
		"combat.player_attack",
		event_payload
	)
	GameServices.network_service.submit_combat_event(event_envelope)
	GameServices.log_event("combat.player_attack", event_payload)
	if is_critical:
		var hud = get_tree().get_first_node_in_group("hud")
		if hud:
			hud.push_message("Critical strike %.0f" % damage)

func receive_damage(amount: float) -> void:
	if amount > 0.0:
		damaged.emit(amount)
		GameServices.log_event("combat.player_damaged", {"amount": amount, "shield": shield, "health": health})
		if viewmodel != null and viewmodel.has_method("notify_damage"):
			viewmodel.notify_damage(amount)
	var remaining = amount
	if shield > 0.0:
		var absorbed = min(shield, remaining)
		shield -= absorbed
		remaining -= absorbed
	if remaining > 0.0:
		health -= remaining
	if health <= 0.0:
		_respawn()
	_emit_stats()

func _respawn() -> void:
	health = max_health
	stamina = max_stamina * 0.7
	shield = 0.0
	global_position = _spawn_position
	_pending_action_kind = ""
	_pending_action_target_id = 0
	_pending_action_payload = {}
	_pending_action_timer = 0.0
	GameServices.log_event("player.respawned", {"position": [global_position.x, global_position.y, global_position.z]})
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.push_message("You were downed and reconstructed at spawn.")
	_set_interaction_hint("", {})

func set_spawn_position(pos: Vector3) -> void:
	_spawn_position = pos

func to_save_data() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y, global_position.z],
		"health": health,
		"stamina": stamina,
		"shield": shield
	}

func load_from_save(payload: Dictionary) -> void:
	if payload.has("position"):
		var p: Array = payload["position"]
		if p.size() == 3:
			global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
			_spawn_position = global_position
	health = clamp(float(payload.get("health", max_health)), 1.0, max_health)
	stamina = clamp(float(payload.get("stamina", max_stamina)), 0.0, max_stamina)
	shield = clamp(float(payload.get("shield", shield)), 0.0, max_shield)
	_refresh_viewmodel_state()
	_emit_stats()

func _on_inventory_changed() -> void:
	_refresh_viewmodel_state()
	_emit_stats()

func _emit_stats() -> void:
	stats_updated.emit()

func _toggle_mouse_capture() -> void:
	_mouse_captured = not _mouse_captured
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _mouse_captured else Input.MOUSE_MODE_VISIBLE

func _setup_input_map() -> void:
	_bind_action("move_forward", KEY_W)
	_bind_action("move_back", KEY_S)
	_bind_action("move_left", KEY_A)
	_bind_action("move_right", KEY_D)
	_bind_action("jump", KEY_SPACE)
	_bind_action("run", KEY_SHIFT)
	_bind_action("interact", KEY_E)
	_bind_action("toggle_inventory", KEY_I)
	_bind_action("toggle_objectives", KEY_O)
	_bind_action("toggle_crafting", KEY_C)
	_bind_action("toggle_journal", KEY_J)
	_bind_action("toggle_market", KEY_M)
	_bind_action("save_game", KEY_F5)
	_bind_action("reset_progress", KEY_F9)
	_bind_action("skip_time", KEY_F8)
	_bind_action("toggle_debug", KEY_F3)
	_bind_action("toggle_mouse", KEY_ESCAPE)

	if not InputMap.has_action("primary_action"):
		InputMap.add_action("primary_action")
	if not _mouse_button_assigned("primary_action", MOUSE_BUTTON_LEFT):
		var event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("primary_action", event)

func _bind_action(action: StringName, key_code: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if _key_assigned(action, key_code):
		return
	var event = InputEventKey.new()
	event.physical_keycode = key_code
	event.keycode = key_code
	InputMap.action_add_event(action, event)

func _key_assigned(action: StringName, key_code: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == key_code:
			return true
	return false

func _mouse_button_assigned(action: StringName, button: MouseButton) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventMouseButton and event.button_index == button:
			return true
	return false

func _update_interaction_hint() -> void:
	if interaction_ray == null:
		_set_interaction_hint("", {})
		return
	interaction_ray.force_raycast_update()
	if not interaction_ray.is_colliding():
		_set_interaction_hint("", {})
		return

	var collider = interaction_ray.get_collider()
	if collider == null:
		_set_interaction_hint("", {})
		return

	if collider.has_method("mine"):
		_set_interaction_hint("Left Click Mine %s" % _target_name(collider), _build_status_from_collider(collider, "Mine"))
		return
	if collider.has_method("take_damage"):
		_set_interaction_hint("Left Click Attack %s" % _target_name(collider), _build_status_from_collider(collider, "Attack"))
		return
	if collider.has_method("interact"):
		_set_interaction_hint("E Interact %s" % _target_name(collider), _build_status_from_collider(collider, "Interact"))
		return
	if collider.has_method("collect"):
		_set_interaction_hint("E Collect %s" % _target_name(collider), _build_status_from_collider(collider, "Collect"))
		return

	_set_interaction_hint("", {})

func _target_name(collider: Object) -> String:
	if collider.has_method("get"):
		var item_id = str(collider.get("item_id"))
		if item_id != "":
			var item_def: Dictionary = GameServices.get_item_def(item_id)
			if not item_def.is_empty():
				return str(item_def.get("name", item_id))
			return item_id
		var enemy_id = str(collider.get("enemy_id"))
		if enemy_id != "":
			var enemy_def: Dictionary = GameServices.get_enemy_def(enemy_id)
			if not enemy_def.is_empty():
				return str(enemy_def.get("name", enemy_id))
			return enemy_id
	return str(collider.get("name"))

func _build_status_from_collider(collider: Object, action: String) -> Dictionary:
	var status: Dictionary = {"action": action}
	if collider.has_method("get_interaction_status"):
		var raw: Variant = collider.get_interaction_status()
		if typeof(raw) == TYPE_DICTIONARY:
			status = raw.duplicate(true)
			status["action"] = action
	if not status.has("name"):
		status["name"] = _target_name(collider)
	return status

func _set_interaction_hint(text: String, status: Dictionary = {}) -> void:
	if _last_interaction_hint == text:
		var signature_same: bool = _last_interaction_signature == JSON.stringify(status, "", false)
		if signature_same:
			return
	_last_interaction_hint = text
	_last_interaction_signature = JSON.stringify(status, "", false)
	interaction_hint_changed.emit(text)
	interaction_target_changed.emit(status)

func _skip_time_phase() -> void:
	var cycle = get_tree().get_first_node_in_group("day_night")
	if cycle == null or not cycle.has_method("skip_to_next_phase"):
		return
	cycle.skip_to_next_phase()
	var new_time: float = float(cycle.get("time_of_day"))
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.push_message("Time advanced to %.1fh" % new_time)
	GameServices.log_event("world.time_skipped", {"time_of_day": new_time})

func _play_viewmodel_action(action_name: String) -> float:
	if viewmodel != null and viewmodel.has_method("play_action"):
		return float(viewmodel.play_action(action_name))
	if viewmodel != null and viewmodel.has_method("get_action_impact_time"):
		return float(viewmodel.get_action_impact_time(action_name))
	return 0.0

func _on_viewmodel_action_impact(action_name: String) -> void:
	if _pending_action_kind != action_name:
		return
	_resolve_pending_action()

func _update_viewmodel_motion(is_running: bool, speed_bonus: float) -> void:
	if viewmodel == null or not viewmodel.has_method("set_motion_state"):
		return
	var max_speed: float = max(run_speed * speed_bonus, 0.1)
	var planar_speed: float = Vector2(velocity.x, velocity.z).length()
	var speed_ratio: float = clamp(planar_speed / max_speed, 0.0, 1.0)
	viewmodel.set_motion_state(speed_ratio, is_running, is_on_floor(), stamina / max(max_stamina, 0.001))

func _refresh_viewmodel_state() -> void:
	if viewmodel == null:
		return
	var desired_tool: String = "moonblade" if GameServices.inventory_service.get_quantity("moonblade_prototype") > 0 else "miner"
	if viewmodel.has_method("set_tool"):
		viewmodel.set_tool(desired_tool)
	if viewmodel.has_method("set_dust_tint"):
		viewmodel.set_dust_tint(_get_dominant_dust_color())

func _get_dominant_dust_color() -> Color:
	var best_color: Color = Color(0.62, 0.78, 1.0)
	var best_qty: int = -1
	for dust_item_id in DUST_ITEM_IDS:
		var qty: int = GameServices.inventory_service.get_quantity(dust_item_id)
		if qty > best_qty:
			best_qty = qty
			best_color = GameServices.data_service.get_dust_color(dust_item_id)
	return best_color

func _target_within_reach(target: Object, max_distance: float) -> bool:
	if target is Node3D:
		var target_node: Node3D = target as Node3D
		return global_position.distance_to(target_node.global_position) <= max_distance
	return true

func _drop_position_from_target(target: Object) -> Vector3:
	if target is Node3D:
		var target_node: Node3D = target as Node3D
		return target_node.global_position + Vector3(0.0, 0.5, 0.0)
	return global_position + (-camera.global_transform.basis.z * 1.0) + Vector3(0.0, 1.1, 0.0)

func _spawn_mined_dust_pickup(item_id: String, quantity: int, position_hint: Vector3) -> void:
	if PickupItemScene == null:
		GameServices.inventory_service.add_item(item_id, quantity)
		return
	var pickup = PickupItemScene.instantiate()
	var parent_node: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	parent_node.add_child(pickup)
	pickup.global_position = position_hint
	pickup.item_id = item_id
	pickup.quantity = max(quantity, 1)
	pickup.credits = 0

	var dust_profile: Dictionary = GameServices.data_service.get_dust_profile(item_id)
	if pickup.has_method("apply_dust_profile") and not dust_profile.is_empty():
		pickup.apply_dust_profile(dust_profile)

	var gravity_scale: float = clamp(float(dust_profile.get("gravity_scale", 1.0)), 0.1, 3.0)
	var gravity_pct: float = clamp((gravity_scale - 0.1) / 2.9, 0.0, 1.0)
	var forward: Vector3 = -camera.global_transform.basis.z.normalized()
	var side: Vector3 = camera.global_transform.basis.x.normalized() * randf_range(-0.45, 0.45)
	var launch_speed: float = lerpf(1.8, 0.92, gravity_pct)
	var lift_speed: float = lerpf(1.9, 0.95, gravity_pct)
	var launch_velocity: Vector3 = forward * launch_speed + side + Vector3.UP * lift_speed
	if pickup.has_method("set_initial_motion"):
		pickup.set_initial_motion(launch_velocity)
