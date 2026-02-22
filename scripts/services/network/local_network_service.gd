extends "res://scripts/services/network/network_service.gd"

var _connected: bool = false

func connect_player(profile: Dictionary) -> Dictionary:
	_connected = true
	return {"ok": true, "error": "", "data": {"profile": profile, "mode": "local"}}

func sync_player_state(payload: Dictionary) -> Dictionary:
	if not _connected:
		return {"ok": false, "error": "Not connected.", "data": {}}
	return {"ok": true, "error": "", "data": payload}

func fetch_market_listings() -> Dictionary:
	# Local mode intentionally returns no remote listings.
	return {"ok": true, "error": "", "data": []}

func submit_market_order(order: Dictionary) -> Dictionary:
	if not _connected:
		return {"ok": false, "error": "Not connected.", "data": {}}
	return {"ok": true, "error": "", "data": {"accepted": true, "order": order}}

func submit_combat_event(event_payload: Dictionary) -> Dictionary:
	if not _connected:
		return {"ok": false, "error": "Not connected.", "data": {}}
	return {"ok": true, "error": "", "data": event_payload}
