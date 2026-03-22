extends "res://scripts/services/network/http_network_service.gd"

const RPC_CONNECT: String = "celadora_connect"
const RPC_SYNC_STATE: String = "celadora_sync_player_state"
const RPC_FETCH_MARKET: String = "celadora_fetch_market_listings"
const RPC_SUBMIT_MARKET: String = "celadora_submit_market_order"
const RPC_SUBMIT_REWARD: String = "celadora_submit_reward_claim"
const RPC_SUBMIT_CRAFT: String = "celadora_submit_craft_request"
const RPC_SUBMIT_COMBAT: String = "celadora_submit_combat_event"
const RPC_SYNC_RESOURCES: String = "celadora_sync_resource_catalog"
const RPC_SUBMIT_RESOURCE_MINE: String = "celadora_submit_resource_mine"
const RPC_SUBMIT_ENEMY_DEFEAT: String = "celadora_submit_enemy_defeat"

var _server_key: String = "defaultkey"
var _device_id: String = ""
var _username: String = "Local Pioneer"
var _auth_token: String = ""

func setup(
	base_url: String,
	server_key: String = "defaultkey",
	device_id: String = "",
	username: String = "Local Pioneer"
) -> void:
	_server_key = server_key.strip_edges()
	_device_id = _sanitize_device_id(device_id if not device_id.strip_edges().is_empty() else OS.get_unique_id())
	_username = username.strip_edges() if not username.strip_edges().is_empty() else "Local Pioneer"
	super.setup(base_url)

func connect_player(profile: Dictionary) -> Dictionary:
	var auth_response: Dictionary = _request_json(
		HTTPClient.METHOD_POST,
		"/v2/account/authenticate/device?create=true&username=%s" % _username.uri_encode(),
		{"id": _device_id},
		PackedStringArray(["Authorization: Basic %s" % _build_basic_auth_token()])
	)
	if not auth_response.get("ok", false):
		return auth_response

	_auth_token = str(auth_response.get("token", auth_response.get("data", {}).get("token", "")))
	if _auth_token.is_empty():
		return {"ok": false, "error": "Nakama authentication did not return a token.", "data": {}}

	return _request_nakama_rpc(RPC_CONNECT, {
		"profile": profile.duplicate(true),
		"device_id": _device_id,
		"username": _username
	})

func sync_player_state(payload: Dictionary) -> Dictionary:
	return _request_nakama_rpc(RPC_SYNC_STATE, payload)

func fetch_market_listings() -> Dictionary:
	return _request_nakama_rpc(RPC_FETCH_MARKET, {})

func submit_market_order(order: Dictionary) -> Dictionary:
	return _request_nakama_rpc(RPC_SUBMIT_MARKET, order)

func submit_combat_event(event_payload: Dictionary) -> Dictionary:
	return _request_nakama_rpc(RPC_SUBMIT_COMBAT, event_payload)

func submit_reward_claim(claim: Dictionary) -> Dictionary:
	return _request_nakama_rpc(RPC_SUBMIT_REWARD, claim)

func submit_craft_request(request: Dictionary) -> Dictionary:
	return _request_nakama_rpc(RPC_SUBMIT_CRAFT, request)

func sync_resource_catalog(payload: Dictionary) -> Dictionary:
	return _request_nakama_rpc(RPC_SYNC_RESOURCES, payload)

func submit_resource_mine(request: Dictionary) -> Dictionary:
	return _request_nakama_rpc(RPC_SUBMIT_RESOURCE_MINE, request)

func submit_enemy_defeat(request: Dictionary) -> Dictionary:
	return _request_nakama_rpc(RPC_SUBMIT_ENEMY_DEFEAT, request)

func _request_nakama_rpc(rpc_id: String, payload: Dictionary) -> Dictionary:
	if _auth_token.is_empty():
		return {"ok": false, "error": "Nakama client is not authenticated.", "data": {}}
	return _request_json(
		HTTPClient.METHOD_POST,
		"/v2/rpc/%s" % rpc_id.uri_encode(),
		payload,
		PackedStringArray(["Authorization: Bearer %s" % _auth_token])
	)

func _build_basic_auth_token() -> String:
	var raw: PackedByteArray = ("%s:" % _server_key).to_utf8_buffer()
	return Marshalls.raw_to_base64(raw)

func _sanitize_device_id(raw_value: String) -> String:
	var source: String = raw_value.strip_edges()
	if source.is_empty():
		source = "celadora-local-device"
	var out := ""
	for i in range(source.length()):
		var ch: String = source.substr(i, 1)
		var code: int = ch.unicode_at(0)
		var is_alpha_num: bool = (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
		if is_alpha_num or ch == "-" or ch == "_" or ch == ".":
			out += ch
		else:
			out += "-"
	if out.length() < 10:
		out += "-celadora"
	if out.length() > 128:
		out = out.substr(0, 128)
	return out
