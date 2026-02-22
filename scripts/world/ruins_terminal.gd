extends Area3D

@export var locked_message: String = "Terminal Lock: Access denied. Greegion control key required."

func interact(_player: Node) -> Dictionary:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.push_message(locked_message)
	return {"ok": false, "message": locked_message}
