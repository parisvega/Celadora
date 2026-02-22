extends Area3D

@export var location_id: String = ""

var _triggered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

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
