extends RefCounted

func is_enabled() -> bool:
	return false

func get_quote(_request: Dictionary) -> Dictionary:
	return _disabled("get_quote")

func prepare_transfer(_request: Dictionary) -> Dictionary:
	return _disabled("prepare_transfer")

func finalize_transfer(_request: Dictionary) -> Dictionary:
	return _disabled("finalize_transfer")

func _disabled(method_name: String) -> Dictionary:
	return {
		"ok": false,
		"error": "TokenBridge disabled in v0.1 (%s)." % method_name,
		"data": {}
	}
