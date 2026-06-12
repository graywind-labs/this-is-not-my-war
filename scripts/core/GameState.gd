extends Node

var current_day: int = 1
var current_hour: int = 6
var current_minute: int = 0
var current_second: int = 0
var in_combat: bool = false
var game_over: bool = false
var game_result: String = ""
var failure_reason: String = ""


func set_time(day: int, hour: int, minute: int = 0, second: int = 0) -> void:
	var previous_day := current_day
	var previous_hour := current_hour
	var previous_minute := current_minute
	var previous_second := current_second
	current_day = max(day, 1)
	current_hour = clampi(hour, 0, 23)
	current_minute = clampi(minute, 0, 59)
	current_second = clampi(second, 0, 59)
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		if current_day != previous_day:
			event_bus.day_started.emit(current_day)
		if current_day != previous_day or current_hour != previous_hour:
			event_bus.hour_started.emit(current_day, current_hour)
		if (
			current_day != previous_day
			or current_hour != previous_hour
			or current_minute != previous_minute
			or current_second != previous_second
		):
			event_bus.time_changed.emit(current_day, current_hour, current_minute, current_second)


func set_combat_active(active: bool) -> void:
	in_combat = active


func set_game_over(result: String, reason: String) -> void:
	game_over = true
	game_result = result
	failure_reason = reason
	in_combat = false
