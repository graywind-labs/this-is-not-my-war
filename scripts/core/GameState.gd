extends Node

var current_day: int = 1
var current_hour: int = 6
var in_combat: bool = false


func set_time(day: int, hour: int) -> void:
	current_day = max(day, 1)
	current_hour = clampi(hour, 0, 23)
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.hour_started.emit(current_day, current_hour)


func set_combat_active(active: bool) -> void:
	in_combat = active
