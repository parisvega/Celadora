extends "res://scripts/services/network/network_service.gd"

var _base_url: String = ""
var _host: String = ""
var _port: int = 80
var _use_tls: bool = false
var _base_path: String = ""

func setup(base_url: String) -> void:
	_base_url = base_url.strip_edges()
	_parse_base_url()

func connect_player(profile: Dictionary) -> Dictionary:
	return _request_json(HTTPClient.METHOD_POST, "/connect", {"profile": profile})

func sync_player_state(payload: Dictionary) -> Dictionary:
	return _request_json(HTTPClient.METHOD_POST, "/sync/player_state", payload)

func fetch_market_listings() -> Dictionary:
	return _request_json(HTTPClient.METHOD_GET, "/market/listings")

func submit_market_order(order: Dictionary) -> Dictionary:
	return _request_json(HTTPClient.METHOD_POST, "/market/order", order)

func submit_combat_event(event_payload: Dictionary) -> Dictionary:
	return _request_json(HTTPClient.METHOD_POST, "/combat/event", event_payload)

func submit_reward_claim(claim: Dictionary) -> Dictionary:
	return _request_json(HTTPClient.METHOD_POST, "/reward/claim", claim)

func submit_craft_request(request: Dictionary) -> Dictionary:
	return _request_json(HTTPClient.METHOD_POST, "/craft/execute", request)

func sync_resource_catalog(payload: Dictionary) -> Dictionary:
	return _request_json(HTTPClient.METHOD_POST, "/world/resources/sync", payload)

func submit_resource_mine(request: Dictionary) -> Dictionary:
	return _request_json(HTTPClient.METHOD_POST, "/world/resources/mine", request)

func _parse_base_url() -> void:
	_host = ""
	_port = 80
	_use_tls = false
	_base_path = ""
	if _base_url.is_empty():
		return

	var working: String = _base_url
	if working.begins_with("https://"):
		_use_tls = true
		_port = 443
		working = working.trim_prefix("https://")
	elif working.begins_with("http://"):
		working = working.trim_prefix("http://")

	var slash_index: int = working.find("/")
	if slash_index >= 0:
		_base_path = working.substr(slash_index, working.length() - slash_index).rstrip("/")
		working = working.substr(0, slash_index)

	var host_parts: PackedStringArray = working.split(":")
	_host = host_parts[0]
	if host_parts.size() > 1:
		_port = int(host_parts[1])

func _request_json(
	method: HTTPClient.Method,
	path: String,
	payload: Dictionary = {},
	extra_headers: PackedStringArray = PackedStringArray()
) -> Dictionary:
	if _host.is_empty():
		return {"ok": false, "error": "Authority URL is not configured.", "data": {}}

	var client := HTTPClient.new()
	var connect_error: int = OK
	if _use_tls:
		connect_error = client.connect_to_host(_host, _port, TLSOptions.client())
	else:
		connect_error = client.connect_to_host(_host, _port)
	if connect_error != OK:
		return {"ok": false, "error": "Authority connection failed (%d)." % connect_error, "data": {}}

	var waited_ms: int = 0
	while client.get_status() == HTTPClient.STATUS_RESOLVING or client.get_status() == HTTPClient.STATUS_CONNECTING:
		client.poll()
		OS.delay_msec(10)
		waited_ms += 10
		if waited_ms > 4000:
			return {"ok": false, "error": "Authority connection timed out.", "data": {}}

	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		return {"ok": false, "error": "Authority connection did not reach connected state.", "data": {}}

	var headers: PackedStringArray = ["Accept: application/json"]
	for header in extra_headers:
		headers.append(header)
	var body_text: String = ""
	if method != HTTPClient.METHOD_GET:
		headers.append("Content-Type: application/json")
		body_text = JSON.stringify(payload)
	var request_error: int = client.request(method, _resolved_path(path), headers, body_text)
	if request_error != OK:
		return {"ok": false, "error": "Authority request failed to start (%d)." % request_error, "data": {}}

	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		OS.delay_msec(10)

	var chunks: PackedByteArray = PackedByteArray()
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk: PackedByteArray = client.read_response_body_chunk()
		if chunk.size() == 0:
			OS.delay_msec(10)
			continue
		chunks.append_array(chunk)

	if client.has_response():
		var response_code: int = client.get_response_code()
		var raw_text: String = chunks.get_string_from_utf8()
		var parsed: Variant = JSON.parse_string(raw_text)
		if typeof(parsed) == TYPE_DICTIONARY:
			var envelope: Dictionary = parsed
			if not envelope.has("ok"):
				envelope["ok"] = response_code >= 200 and response_code < 300
			if not envelope.has("error"):
				envelope["error"] = "" if bool(envelope.get("ok", false)) else "Authority request failed."
			if not envelope.has("data"):
				envelope["data"] = {}
			return envelope
		if response_code >= 200 and response_code < 300:
			return {"ok": true, "error": "", "data": {"raw": raw_text}}
		return {"ok": false, "error": "Authority request failed with status %d." % response_code, "data": {"raw": raw_text}}

	return {"ok": false, "error": "Authority response was unavailable.", "data": {}}

func _resolved_path(path: String) -> String:
	if _base_path.is_empty():
		return path
	return "%s%s" % [_base_path, path]
