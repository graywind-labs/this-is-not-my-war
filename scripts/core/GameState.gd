extends Node

var current_day: int = 1
var current_hour: int = 6
var current_minute: int = 0
var current_second: int = 0
var in_combat: bool = false
var game_over: bool = false
var game_result: String = ""
var game_over_reason: String = ""
var failure_reason: String = ""
var game_over_day: int = 0
var game_over_hour: int = 0
var game_over_minute: int = 0
var game_over_second: int = 0
var settlement_snapshot: Dictionary = {}


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


func set_game_over(result: String, reason: String, snapshot: Dictionary = {}) -> void:
	if game_over and game_result == result and game_over_reason == reason:
		if not snapshot.is_empty():
			settlement_snapshot = _normalize_settlement_snapshot(result, reason, snapshot)
		return
	game_over = true
	game_result = result
	game_over_reason = reason
	failure_reason = reason if result == "failure" else ""
	game_over_day = current_day
	game_over_hour = current_hour
	game_over_minute = current_minute
	game_over_second = current_second
	settlement_snapshot = _normalize_settlement_snapshot(result, reason, snapshot)
	in_combat = false
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("game_over_changed"):
		event_bus.game_over_changed.emit(game_result, game_over_reason)


func _normalize_settlement_snapshot(result: String, reason: String, snapshot: Dictionary) -> Dictionary:
	var normalized := snapshot.duplicate(true)
	normalized["result"] = result
	normalized["reason"] = reason
	normalized["day"] = current_day
	normalized["time"] = "%02d:%02d:%02d" % [current_hour, current_minute, current_second]
	normalized["npcs"] = _build_npc_settlement_snapshot(result)
	return normalized


func _build_npc_settlement_snapshot(result: String) -> Dictionary:
	var npc_system := get_node_or_null("/root/Main/Systems/NPCSystem")
	var items: Array[Dictionary] = []
	var active: Array[Dictionary] = []
	var unconscious: Array[Dictionary] = []
	var escaped: Array[Dictionary] = []
	if npc_system == null or not npc_system.has_method("get_npc_ids") or not npc_system.has_method("get_npc"):
		return {
			"items": items,
			"active_npcs": active,
			"unconscious_npcs": unconscious,
			"escaped_npcs": escaped
		}

	for raw_npc_id in npc_system.get_npc_ids():
		var npc_id := str(raw_npc_id)
		var npc: Dictionary = npc_system.get_npc(npc_id)
		var state: Dictionary = npc.get("states", {}) if (npc.get("states", {}) is Dictionary) else {}
		if npc_system.has_method("get_npc_state"):
			state = npc_system.get_npc_state(npc_id)
		var long_memory: Dictionary = {}
		if npc_system.has_method("get_npc_long_memory"):
			long_memory = npc_system.get_npc_long_memory(npc_id)

		var final_status := _get_npc_final_status(state)
		var entry := {
			"id": npc_id,
			"name": str(npc.get("name", npc_id)),
			"recruited": bool(npc.get("recruited", false)),
			"hp": int(state.get("hp", 0)),
			"max_hp": int(state.get("max_hp", 0)),
			"unconscious": bool(state.get("unconscious", false)),
			"escaped": bool(state.get("escaped", false)),
			"behavior_mode": str(state.get("behavior_mode", "work")),
			"current_action": str(state.get("current_action", "")),
			"current_location": str(state.get("current_location", "")),
			"current_location_name": _get_npc_final_location_name(state),
			"final_status": final_status,
			"final_status_label": final_status,
			"final_opinion": _build_npc_final_opinion(npc_id, npc, state, long_memory),
			"fate_summary": _build_npc_fate_summary(result, npc, state, final_status),
			"memory_basis": _build_npc_memory_basis(npc_id, long_memory)
		}
		items.append(entry)
		if final_status == "逃离":
			escaped.append(entry.duplicate(true))
		elif final_status == "昏迷":
			unconscious.append(entry.duplicate(true))
		else:
			active.append(entry.duplicate(true))

	return {
		"items": items,
		"active_npcs": active,
		"unconscious_npcs": unconscious,
		"escaped_npcs": escaped
	}


func _get_npc_final_status(state: Dictionary) -> String:
	if bool(state.get("escaped", false)):
		return "逃离"
	if bool(state.get("unconscious", false)):
		return "昏迷"
	return "可行动"


func _get_npc_final_location_name(state: Dictionary) -> String:
	if bool(state.get("escaped", false)):
		return "驿站外"
	var location_name := str(state.get("current_location_name", "")).strip_edges()
	if not location_name.is_empty():
		return location_name
	var location_id := str(state.get("current_location", "")).strip_edges()
	match location_id:
		"plaza":
			return "广场"
		"outside_station":
			return "驿站外"
		"":
			return "未知"
		_:
			return location_id


func _build_npc_final_opinion(npc_id: String, npc: Dictionary, state: Dictionary, long_memory: Dictionary) -> String:
	if bool(state.get("escaped", false)):
		return "Mock：把守备官和这座驿站记成一场逼近自己的压力，短时间内不会主动回来。"
	if bool(state.get("unconscious", false)):
		return "Mock：对守备官的看法停在疲惫和混乱里，但仍知道自己没有被写成牺牲品。"
	if _npc_has_guard_event(npc_id, ["damage_taken", "escape_speed_changed"]):
		return "Mock：对守备官心存戒备，记得命令背后也可能有疼痛。"
	if _npc_has_guard_event(npc_id, ["money_given", "equipment_given", "equipment_changed"]):
		return "Mock：记得守备官给过实际帮助，信任里仍带着战后的保留。"
	if bool(npc.get("recruited", false)):
		return "Mock：承认守备官把自己推上防线，也记得这份临时责任的重量。"
	var basis := _build_npc_memory_basis(npc_id, long_memory)
	if not basis.is_empty():
		return "Mock：把守备官视为驿站命运的核心人物，仍在消化这些见闻。"
	return "Mock：对守备官保持距离，更多把他看作这场混乱的源头和秩序。"


func _build_npc_fate_summary(result: String, npc: Dictionary, state: Dictionary, final_status: String) -> String:
	if final_status == "逃离":
		return "Mock：离开驿站，去后门外寻找下一处能躲开战争的地方。"
	if final_status == "昏迷":
		return "Mock：留在驿站疗养，复苏后还要面对这几天留下的账。"
	if result == "victory" and bool(npc.get("recruited", false)):
		return "Mock：继续留在防线名单里，带着临时战斗经验守住下一夜。"
	if result == "victory":
		return "Mock：回到本职工作，但已经不再把战争当成远处的事。"
	return "Mock：跟着残余人员收拾残局，是否留下仍是未知数。"


func _build_npc_memory_basis(npc_id: String, long_memory: Dictionary) -> String:
	var diary: Array = long_memory.get("diary", []) if (long_memory.get("diary", []) is Array) else []
	if not diary.is_empty():
		var latest: Dictionary = diary[diary.size() - 1] if diary[diary.size() - 1] is Dictionary else {}
		var entry := str(latest.get("entry", "")).strip_edges()
		if entry.length() > 48:
			entry = entry.substr(0, 48) + "..."
		if not entry.is_empty():
			return "最近日记：%s" % entry

	var memory_system := get_node_or_null("/root/Main/Systems/MemorySystem")
	if memory_system == null or not memory_system.has_method("get_npc_daily_events"):
		return ""
	var events: Array = memory_system.get_npc_daily_events(npc_id)
	if events.is_empty():
		return ""
	var latest_event: Dictionary = events[events.size() - 1] if events[events.size() - 1] is Dictionary else {}
	return str(latest_event.get("summary", "")).strip_edges()


func _npc_has_guard_event(npc_id: String, event_types: Array[String]) -> bool:
	var memory_system := get_node_or_null("/root/Main/Systems/MemorySystem")
	if memory_system == null or not memory_system.has_method("get_npc_daily_events"):
		return false
	var event_type_lookup := {}
	for event_type in event_types:
		event_type_lookup[event_type] = true
	for raw_event in memory_system.get_npc_daily_events(npc_id):
		var event: Dictionary = raw_event if raw_event is Dictionary else {}
		if not event_type_lookup.has(str(event.get("type", ""))):
			continue
		var actor_ids: Array = event.get("actor_ids", []) if (event.get("actor_ids", []) is Array) else []
		if actor_ids.has("guard_officer"):
			return true
		var summary := str(event.get("summary", ""))
		if summary.contains("守备官"):
			return true
	return false
