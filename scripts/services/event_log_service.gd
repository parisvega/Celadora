extends Node

signal event_recorded(event_payload: Dictionary)
signal events_loaded(total: int)

const DEFAULT_MAX_EVENTS: int = 500

var _events: Array = []
var _sequence: int = 0

func record(event_type: String, payload: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	_sequence += 1
	var event_payload: Dictionary = {
		"id": "evt_%d_%d" % [Time.get_ticks_msec(), _sequence],
		"type": event_type,
		"timestamp_unix_sec": Time.get_unix_time_from_system(),
		"payload": payload.duplicate(true),
		"context": context.duplicate(true)
	}
	_events.append(event_payload)
	while _events.size() > DEFAULT_MAX_EVENTS:
		_events.remove_at(0)
	event_recorded.emit(event_payload)
	return event_payload

func clear() -> void:
	_events.clear()
	_sequence = 0

func get_recent(limit: int = 20) -> Array:
	if limit <= 0:
		return []
	var start: int = max(0, _events.size() - limit)
	var out: Array = []
	for i in range(start, _events.size()):
		out.append(_events[i].duplicate(true))
	return out

func get_last_event() -> Dictionary:
	if _events.is_empty():
		return {}
	return _events[_events.size() - 1].duplicate(true)

func get_count() -> int:
	return _events.size()

func serialize_state() -> Array:
	var serialized: Array = []
	for event_payload in _events:
		if typeof(event_payload) == TYPE_DICTIONARY:
			serialized.append(event_payload.duplicate(true))
	return serialized

func load_state(saved_events: Array) -> void:
	clear()
	for event_payload in saved_events:
		if typeof(event_payload) != TYPE_DICTIONARY:
			continue
		_events.append(event_payload.duplicate(true))
	_sequence = _events.size()
	while _events.size() > DEFAULT_MAX_EVENTS:
		_events.remove_at(0)
	events_loaded.emit(_events.size())
