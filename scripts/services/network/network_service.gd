extends Node

var _event_sequence: int = 0

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

func wrap_client_event(event_type: String, payload: Dictionary, context: Dictionary = {}) -> Dictionary:
	_event_sequence += 1
	return {
		"id": "evt_%d_%d" % [Time.get_ticks_msec(), _event_sequence],
		"type": event_type,
		"timestamp_unix_sec": Time.get_unix_time_from_system(),
		"payload": payload.duplicate(true),
		"context": context.duplicate(true),
		"schema_version": "v0.1"
	}

func _not_implemented(method_name: String) -> Dictionary:
	return {"ok": false, "error": "%s is not implemented." % method_name, "data": {}}
