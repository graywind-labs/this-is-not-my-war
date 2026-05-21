extends Node

var _event_log: Array[Dictionary] = []


func initialize() -> void:
	_event_log.clear()


func _ready() -> void:
	initialize()


func add_event(event: Dictionary) -> void:
	if event.is_empty():
		return

	var normalized := event.duplicate(true)
	if not normalized.has("time"):
		normalized["time"] = _get_time_label()
	if not normalized.has("importance"):
		normalized["importance"] = 30
	if not normalized.has("visible_to_public_square"):
		normalized["visible_to_public_square"] = false

	_event_log.append(normalized)

	if bool(normalized.get("visible_to_public_square", false)):
		var event_bus := get_node_or_null("/root/EventBus")
		if event_bus != null:
			event_bus.public_event_added.emit(normalized.duplicate(true))


func get_event_log() -> Array[Dictionary]:
	return _event_log.duplicate(true)


func get_event_count() -> int:
	return _event_log.size()


func clear_event_log() -> void:
	_event_log.clear()


func _get_time_label() -> String:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return "Day1 06:00"
	return "Day%d %02d:00" % [int(game_state.current_day), int(game_state.current_hour)]
