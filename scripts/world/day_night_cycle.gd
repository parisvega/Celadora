extends Node3D

signal night_state_changed(is_night: bool)

@export var day_length_seconds: float = 300.0
@export var start_time_of_day: float = 13.0

@onready var sun: DirectionalLight3D = $Sun
@onready var world_environment: WorldEnvironment = $WorldEnvironment

var time_of_day: float = 0.0
var _last_night_state: bool = false

func _ready() -> void:
	add_to_group("day_night")
	time_of_day = start_time_of_day
	_apply_lighting()
	_last_night_state = is_night()

func _process(delta: float) -> void:
	time_of_day = fmod(time_of_day + (24.0 / day_length_seconds) * delta, 24.0)
	_apply_lighting()
	var current_night = is_night()
	if current_night != _last_night_state:
		_last_night_state = current_night
		night_state_changed.emit(current_night)

func is_night() -> bool:
	return time_of_day < 6.0 or time_of_day >= 18.0

func skip_to_next_phase() -> void:
	if is_night():
		time_of_day = 9.0
	else:
		time_of_day = 21.0
	_apply_lighting()
	var current_night: bool = is_night()
	if current_night != _last_night_state:
		_last_night_state = current_night
		night_state_changed.emit(current_night)

func _apply_lighting() -> void:
	var day_progress = time_of_day / 24.0
	var sun_angle = day_progress * TAU
	sun.rotation_degrees = Vector3(rad_to_deg(sun_angle) - 90.0, -45.0, 0.0)
	var daylight = clamp((sin(sun_angle) + 1.0) * 0.5, 0.05, 1.0)
	sun.light_energy = 0.15 + daylight * 1.3
	sun.light_color = Color(1.0, 0.54, 0.36).lerp(Color(1.0, 0.97, 0.9), daylight)

	if world_environment.environment != null:
		var env = world_environment.environment
		env.background_color = Color(0.01, 0.03, 0.08).lerp(Color(0.47, 0.63, 0.82), daylight)
		env.ambient_light_color = Color(0.07, 0.1, 0.18).lerp(Color(0.58, 0.64, 0.72), daylight)
		env.ambient_light_energy = 0.35 + daylight * 0.65
		_set_if_property(env, "fog_density", lerp(0.0065, 0.0031, daylight))
		_set_if_property(env, "fog_light_color", Color(0.04, 0.09, 0.18).lerp(Color(0.66, 0.74, 0.82), daylight))
		_set_if_property(env, "fog_aerial_perspective", lerp(0.62, 0.38, daylight))

func _set_if_property(target: Object, property_name: String, value: Variant) -> void:
	for property_meta in target.get_property_list():
		if str(property_meta.get("name", "")) == property_name:
			target.set(property_name, value)
			return
