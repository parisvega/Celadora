extends Node

func connect_player(_profile: Dictionary) -> Dictionary:
	return _not_implemented("connect_player")

func sync_player_state(_payload: Dictionary) -> Dictionary:
	return _not_implemented("sync_player_state")

func fetch_market_listings() -> Dictionary:
	return _not_implemented("fetch_market_listings")

func submit_market_order(_order: Dictionary) -> Dictionary:
	return _not_implemented("submit_market_order")

func submit_combat_event(_event_payload: Dictionary) -> Dictionary:
	return _not_implemented("submit_combat_event")

func _not_implemented(method_name: String) -> Dictionary:
	return {"ok": false, "error": "%s is not implemented." % method_name, "data": {}}
