extends Node

@export var seconds_per_game_minute: float = 1.0
@export var speed_steps: Array[float] = [1.0, 2.0, 4.0]
@export var llm_wait_scale: float = 1.0 / 60.0

var is_paused: bool = false
var time_scale: float = 1.0
var _seconds_into_day: float = 0.0
var _last_emitted_day_second: int = -1
var _slowdown_requests: Dictionary = {}
var _game_state: Node = null
var _event_bus: Node = null


func initialize() -> void:
	_game_state = get_node_or_null("/root/GameState")
	_event_bus = get_node_or_null("/root/EventBus")
	if _game_state != null:
		_seconds_into_day = _get_seconds_from_state()
		_last_emitted_day_second = int(_seconds_into_day)


func _ready() -> void:
	initialize()


func _process(delta: float) -> void:
	if is_paused or _game_state == null:
		return

	var game_seconds_delta := get_game_delta_seconds(delta)
	if game_seconds_delta <= 0.0:
		return

	_seconds_into_day += game_seconds_delta

	var next_day := int(_game_state.current_day)
	while _seconds_into_day >= 86400.0:
		_seconds_into_day -= 86400.0
		next_day += 1

	if _event_bus != null:
		_event_bus.logical_time_tick.emit(game_seconds_delta, get_numeric_delta_multiplier())
	_emit_time_if_needed(next_day)


func set_paused(paused: bool) -> void:
	if is_paused == paused:
		return

	is_paused = paused
	_emit_time_scale_changed("pause_changed")
	if _event_bus != null:
		_event_bus.gameplay_pause_changed.emit(is_paused)


func toggle_paused() -> bool:
	set_paused(not is_paused)
	return is_paused


func set_time_scale(scale: float) -> void:
	time_scale = maxf(scale, 0.0)
	_emit_time_scale_changed("player_speed_changed")


func set_current_time(day: int, hour: int, minute: int = 0, second: int = 0) -> void:
	if _game_state == null:
		return

	_seconds_into_day = float(clampi(hour, 0, 23) * 3600 + clampi(minute, 0, 59) * 60 + clampi(second, 0, 59))
	_last_emitted_day_second = int(_seconds_into_day)
	_game_state.set_time(day, hour, minute, second)


func request_time_slowdown(request_id: String, scale: float = -1.0, reason: String = "llm_wait") -> void:
	if request_id.is_empty():
		return

	var slowdown_scale := llm_wait_scale if scale < 0.0 else scale
	_slowdown_requests[request_id] = {
		"scale": clampf(slowdown_scale, 0.0, 1.0),
		"reason": reason
	}
	_emit_time_scale_changed(reason)


func release_time_slowdown(request_id: String) -> void:
	if not _slowdown_requests.has(request_id):
		return

	var reason := str(_slowdown_requests[request_id].get("reason", "llm_wait"))
	_slowdown_requests.erase(request_id)
	_emit_time_scale_changed("%s_finished" % reason)


func clear_time_slowdowns() -> void:
	if _slowdown_requests.is_empty():
		return

	_slowdown_requests.clear()
	_emit_time_scale_changed("slowdowns_cleared")


func has_time_slowdown() -> bool:
	return not _slowdown_requests.is_empty()


func get_effective_time_scale() -> float:
	var effective_scale := time_scale
	for request in _slowdown_requests.values():
		effective_scale = minf(effective_scale, float(request.get("scale", effective_scale)))
	return maxf(effective_scale, 0.0)


func get_numeric_delta_multiplier() -> float:
	if is_paused:
		return 0.0
	return get_effective_time_scale()


func is_gameplay_paused() -> bool:
	return is_paused


func get_game_delta_seconds(real_delta_seconds: float) -> float:
	var seconds_per_minute := maxf(seconds_per_game_minute, 0.001)
	return real_delta_seconds * (60.0 / seconds_per_minute) * get_numeric_delta_multiplier()


func cycle_speed() -> void:
	var current_index := speed_steps.find(time_scale)
	if current_index < 0:
		set_time_scale(speed_steps[0] if not speed_steps.is_empty() else 1.0)
		return

	var next_index := current_index + 1
	if next_index >= speed_steps.size():
		set_time_scale(speed_steps[0] if not speed_steps.is_empty() else 1.0)
	else:
		set_time_scale(speed_steps[next_index])


func get_speed_label() -> String:
	return "x%.0f" % time_scale


func get_pause_label() -> String:
	if is_paused:
		return "继续"
	return "暂停"


func get_effective_speed_label() -> String:
	var effective_scale := get_effective_time_scale()
	if effective_scale < 1.0:
		return "x%.2f" % effective_scale
	return "x%.0f" % effective_scale


func get_progress_to_next_hour() -> float:
	return clampf(float(int(_seconds_into_day) % 3600) / 3600.0, 0.0, 1.0)


func debug_advance_hour() -> void:
	_advance_hour()


func _advance_hour() -> void:
	if _game_state == null:
		return

	var next_day := int(_game_state.current_day)
	var next_hour := int(_game_state.current_hour) + 1
	if next_hour >= 24:
		next_hour = 0
		next_day += 1

	_seconds_into_day = float(next_hour * 3600)
	_last_emitted_day_second = -1
	_game_state.set_time(next_day, next_hour, 0, 0)


func _emit_time_if_needed(day: int) -> void:
	var day_second := int(_seconds_into_day)
	if day == int(_game_state.current_day) and day_second == _last_emitted_day_second:
		return

	_last_emitted_day_second = day_second
	var hour := int(day_second / 3600)
	var minute := int((day_second % 3600) / 60)
	var second := day_second % 60
	_game_state.set_time(day, hour, minute, second)


func _emit_time_scale_changed(reason: String) -> void:
	if _event_bus == null:
		return

	_event_bus.time_scale_changed.emit(
		time_scale,
		get_effective_time_scale(),
		get_numeric_delta_multiplier(),
		reason
	)


func _get_seconds_from_state() -> int:
	return (
		int(_game_state.current_hour) * 3600
		+ int(_game_state.current_minute) * 60
		+ int(_game_state.current_second)
	)
