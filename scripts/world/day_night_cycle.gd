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

func _apply_lighting() -> void:
	var day_progress = time_of_day / 24.0
	var sun_angle = day_progress * TAU
	sun.rotation_degrees = Vector3(rad_to_deg(sun_angle) - 90.0, -45.0, 0.0)
	var daylight = clamp((sin(sun_angle) + 1.0) * 0.5, 0.05, 1.0)
	sun.light_energy = 0.15 + daylight * 1.3

	if world_environment.environment != null:
		var env = world_environment.environment
		env.ambient_light_color = Color(0.07, 0.1, 0.18).lerp(Color(0.55, 0.6, 0.68), daylight)
		env.ambient_light_energy = 0.35 + daylight * 0.65
