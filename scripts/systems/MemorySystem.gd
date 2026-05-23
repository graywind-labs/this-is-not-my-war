extends Node

const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const BUILDING_SYSTEM_PATH := "/root/Main/Systems/BuildingSystem"
const RESOURCE_SYSTEM_PATH := "/root/Main/Systems/ResourceSystem"
const ACTION_SYSTEM_PATH := "/root/Main/Systems/ActionSystem"
const DEFAULT_LOCATION_ID := "plaza"
const DEFAULT_VISIBILITY := "private"
const PUBLIC_VISIBILITY := "plaza_public"
const LOCAL_PUBLIC_VISIBILITY := "local_public"

const EVENT_TYPES: Array[String] = [
	"wake_up", "plan_created", "reflection_started", "sleep_started", "sleep_ended",
	"location_entered", "location_exited",
	"work_started", "work_completed", "work_failed", "eat_started", "eat_completed",
	"dialogue_started", "dialogue_turn", "dialogue_ended",
	"money_given", "equipment_given", "equipment_changed", "order_assigned", "npc_attacked_by_player",
	"skill_improved", "npc_recruited", "npc_left_recruited_state",
	"combat_started", "combat_ended", "attack_made", "damage_taken", "low_hp_triggered",
	"unconscious_started", "healing_started", "healing_completed", "revived", "escape_started", "escaped",
	"building_damaged", "building_repaired", "building_upgraded", "resource_changed"
]

const REQUIRED_PAYLOAD_FIELDS := {
	"location_entered": ["to_location_id", "from_location_id", "location_snapshot"],
	"work_started": ["action_id", "workstation_id"],
	"work_completed": ["action_id", "input_resources", "output_resources"],
	"work_failed": ["action_id", "reason"],
	"eat_completed": ["action_id", "resource_id", "amount", "satiety_restore"]
}

var _events_by_id: Dictionary = {}
var _global_event_ids: Array[String] = []
var _npc_daily_event_ids: Dictionary = {}
var _npc_daily_witness_ids: Dictionary = {}
var _plaza_public_query_event_ids: Array[String] = []
var _event_counter := 0


func initialize() -> void:
	_events_by_id.clear()
	_global_event_ids.clear()
	_npc_daily_event_ids.clear()
	_npc_daily_witness_ids.clear()
	_plaza_public_query_event_ids.clear()
	_event_counter = 0


func _ready() -> void:
	initialize()


func add_event(event: Dictionary) -> Dictionary:
	if event.is_empty():
		return {}

	var normalized := _normalize_event(event)
	if normalized.is_empty():
		return {}

	var event_id := str(normalized["event_id"])
	_events_by_id[event_id] = normalized
	_global_event_ids.append(event_id)

	var subject_npc_id := str(normalized.get("subject_npc_id", ""))
	if not _npc_daily_event_ids.has(subject_npc_id):
		_npc_daily_event_ids[subject_npc_id] = []
	_npc_daily_event_ids[subject_npc_id].append(event_id)

	var visibility := str(normalized.get("visibility", DEFAULT_VISIBILITY))
	if visibility == LOCAL_PUBLIC_VISIBILITY or visibility == PUBLIC_VISIBILITY:
		var location_id := str(normalized.get("location_id", DEFAULT_LOCATION_ID))
		_emit_location_info_changed(location_id)

	if visibility == PUBLIC_VISIBILITY:
		_plaza_public_query_event_ids.append(event_id)
		_emit_public_event_added(normalized)

	_emit_event_recorded(normalized)
	_emit_npc_memory_changed(subject_npc_id)
	return normalized.duplicate(true)


func add_witness_event(npc_id: String, event_id: String) -> bool:
	if npc_id.is_empty() or not _events_by_id.has(event_id):
		return false
	if not _npc_daily_witness_ids.has(npc_id):
		_npc_daily_witness_ids[npc_id] = []
	if not _npc_daily_witness_ids[npc_id].has(event_id):
		_npc_daily_witness_ids[npc_id].append(event_id)
		_emit_npc_memory_changed(npc_id)
	return true


func get_event(event_id: String) -> Dictionary:
	if not _events_by_id.has(event_id):
		return {}
	return _events_by_id[event_id].duplicate(true)


func get_event_log() -> Array[Dictionary]:
	return get_all_events()


func get_all_events() -> Array[Dictionary]:
	return _events_from_ids(_global_event_ids)


func get_event_count() -> int:
	return _global_event_ids.size()


func get_npc_daily_events(npc_id: String) -> Array[Dictionary]:
	return _events_from_ids(_npc_daily_event_ids.get(npc_id, []))


func get_npc_daily_event_ids(npc_id: String) -> Array:
	return _npc_daily_event_ids.get(npc_id, []).duplicate()


func get_npc_witness_events(npc_id: String) -> Array[Dictionary]:
	return _events_from_ids(_npc_daily_witness_ids.get(npc_id, []))


func get_plaza_public_events() -> Array[Dictionary]:
	return _events_from_ids(_plaza_public_query_event_ids)


func get_supported_event_types() -> Array[String]:
	return EVENT_TYPES.duplicate()


func get_required_payload_fields(event_type: String) -> Array:
	return REQUIRED_PAYLOAD_FIELDS.get(event_type, []).duplicate()


func clear_event_log() -> void:
	initialize()


func debug_get_all_events() -> Array[Dictionary]:
	return get_all_events()


func debug_get_npc_events(npc_id: String) -> Array[Dictionary]:
	return get_npc_daily_events(npc_id)


func debug_get_plaza_public_events() -> Array[Dictionary]:
	return get_plaza_public_events()


func _normalize_event(event: Dictionary) -> Dictionary:
	var event_type := str(event.get("type", ""))
	if event_type.is_empty():
		push_warning("MemorySystem skipped event with empty type.")
		return {}
	if not EVENT_TYPES.has(event_type):
		push_warning("MemorySystem accepted unreserved event type: %s" % event_type)

	var subject_npc_id := str(event.get("subject_npc_id", ""))
	if subject_npc_id.is_empty():
		var actor_ids := _normalize_string_array(event.get("actor_ids", event.get("actors", [])))
		if not actor_ids.is_empty():
			subject_npc_id = str(actor_ids[0])
	if subject_npc_id.is_empty():
		push_warning("MemorySystem skipped event without subject_npc_id: %s" % event_type)
		return {}

	var day := int(event.get("day", _get_current_day()))
	var time_text := str(event.get("time", _get_time_label()))
	var location_id := str(event.get("location_id", event.get("location", DEFAULT_LOCATION_ID)))
	if location_id.is_empty():
		location_id = DEFAULT_LOCATION_ID

	var visibility := str(event.get("visibility", DEFAULT_VISIBILITY))
	if bool(event.get("visible_to_public_square", false)):
		visibility = PUBLIC_VISIBILITY
	if not [DEFAULT_VISIBILITY, LOCAL_PUBLIC_VISIBILITY, PUBLIC_VISIBILITY].has(visibility):
		push_warning("MemorySystem changed invalid visibility '%s' to private." % visibility)
		visibility = DEFAULT_VISIBILITY

	var payload: Dictionary = event.get("payload", {})
	if payload.is_empty():
		payload = _legacy_payload_from_event(event)

	var actor_ids := _normalize_string_array(event.get("actor_ids", event.get("actors", [subject_npc_id])))
	if actor_ids.is_empty():
		actor_ids = [subject_npc_id]

	var target_ids := _normalize_string_array(event.get("target_ids", []))
	if target_ids.is_empty():
		target_ids = _build_default_target_ids(event_type, location_id, payload)

	var normalized := {
		"event_id": str(event.get("event_id", _make_event_id(day, time_text, subject_npc_id, event_type))),
		"day": day,
		"time": time_text,
		"type": event_type,
		"subject_npc_id": subject_npc_id,
		"actor_ids": actor_ids,
		"target_ids": target_ids,
		"location_id": location_id,
		"visibility": visibility,
		"importance": int(event.get("importance", 30)),
		"payload": payload
	}
	_validate_required_payload(normalized)
	normalized["summary"] = str(event.get("summary", ""))
	if str(normalized["summary"]).is_empty():
		normalized["summary"] = _format_summary(normalized)
	return normalized


func _legacy_payload_from_event(event: Dictionary) -> Dictionary:
	var payload := {}
	for key in event.keys():
		if not [
			"event_id", "day", "time", "type", "subject_npc_id", "actor_ids", "actors",
			"target_ids", "location_id", "location", "visibility", "importance", "summary",
			"visible_to_public_square", "payload"
		].has(str(key)):
			payload[str(key)] = event[key]
	if event.has("content"):
		payload["content"] = event["content"]
	return payload


func _validate_required_payload(event: Dictionary) -> void:
	var event_type := str(event.get("type", ""))
	var payload: Dictionary = event.get("payload", {})
	for field in REQUIRED_PAYLOAD_FIELDS.get(event_type, []):
		if not payload.has(str(field)):
			push_warning("Event %s missing payload field '%s'." % [event_type, str(field)])


func _format_summary(event: Dictionary) -> String:
	var event_type := str(event.get("type", ""))
	var payload: Dictionary = event.get("payload", {})
	var actor := _get_npc_display_name(str(event.get("subject_npc_id", "")))
	var location := _get_location_name(str(event.get("location_id", DEFAULT_LOCATION_ID)))

	match event_type:
		"location_entered":
			return "%s进入了%s。" % [actor, _get_location_name(str(payload.get("to_location_id", event.get("location_id", DEFAULT_LOCATION_ID))))]
		"location_exited":
			return "%s离开了%s。" % [actor, _get_location_name(str(payload.get("from_location_id", event.get("location_id", DEFAULT_LOCATION_ID))))]
		"work_started":
			return "%s开始在%s进行%s。" % [actor, location, _get_action_name(str(payload.get("action_id", "")))]
		"work_completed":
			return "%s完成了%s，消耗%s，产出%s。" % [
				actor,
				_get_action_name(str(payload.get("action_id", ""))),
				_format_resource_delta(payload.get("input_resources", {})),
				_format_resource_delta(payload.get("output_resources", {}))
			]
		"work_failed":
			return "%s未能完成%s：%s。" % [
				actor,
				_get_action_name(str(payload.get("action_id", ""))),
				str(payload.get("reason", "原因不明"))
			]
		"eat_started":
			return "%s开始在%s吃饭。" % [actor, location]
		"eat_completed":
			return "%s吃了%s，恢复了%d点饱食度。" % [
				actor,
				_get_resource_name(str(payload.get("resource_id", ""))),
				int(payload.get("satiety_restore", 0))
			]
		"sleep_started":
			return "%s开始在%s休息。" % [actor, location]
		"sleep_ended":
			return "%s在%s休息后恢复了些精神。" % [actor, location]
		_:
			return "%s发生了%s事件。" % [actor, event_type]


func _format_resource_delta(raw_delta: Variant) -> String:
	if not raw_delta is Dictionary or (raw_delta as Dictionary).is_empty():
		return "无"
	var parts: Array[String] = []
	var delta: Dictionary = raw_delta
	for resource_id in delta.keys():
		var amount := int(delta[resource_id])
		if amount == 0:
			continue
		parts.append("%s%d" % [_get_resource_name(str(resource_id)), amount])
	if parts.is_empty():
		return "无"
	return "、".join(parts)


func _build_default_target_ids(event_type: String, location_id: String, payload: Dictionary) -> Array[String]:
	var target_ids: Array[String] = []
	if not location_id.is_empty():
		target_ids.append(location_id)
	if payload.has("action_id"):
		target_ids.append(str(payload["action_id"]))
	if payload.has("resource_id"):
		target_ids.append(str(payload["resource_id"]))
	if event_type.begins_with("building_") and payload.has("building_id"):
		target_ids.append(str(payload["building_id"]))
	return target_ids


func _events_from_ids(event_ids: Array) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for raw_event_id in event_ids:
		var event_id := str(raw_event_id)
		if _events_by_id.has(event_id):
			events.append(_events_by_id[event_id].duplicate(true))
	return events


func _normalize_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			var text := str(item)
			if not text.is_empty() and not result.has(text):
				result.append(text)
	elif value != null:
		var text := str(value)
		if not text.is_empty():
			result.append(text)
	return result


func _make_event_id(day: int, time_text: String, subject_npc_id: String, event_type: String) -> String:
	_event_counter += 1
	var compact_time := time_text.replace(":", "")
	return "evt_day%02d_%s_%s_%s_%04d" % [day, compact_time, subject_npc_id, event_type, _event_counter]


func _get_current_day() -> int:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return 1
	return int(game_state.current_day)


func _get_time_label() -> String:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return "06:00:00"
	return "%02d:%02d:%02d" % [
		int(game_state.current_hour),
		int(game_state.current_minute),
		int(game_state.current_second)
	]


func _get_npc_display_name(npc_id: String) -> String:
	if npc_id.is_empty():
		return "未知对象"
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return npc_id
	var npc: Dictionary = npc_system.get_npc(npc_id)
	return str(npc.get("name", npc_id))


func _get_location_name(location_id: String) -> String:
	if location_id == DEFAULT_LOCATION_ID:
		return "广场"
	if location_id.is_empty():
		return "未知地点"
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null:
		return location_id
	var building: Dictionary = building_system.get_building(location_id)
	return str(building.get("name", location_id))


func _get_action_name(action_id: String) -> String:
	if action_id.is_empty():
		return "行动"
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null:
		return action_id
	var action: Dictionary = action_system.get_action(action_id)
	return str(action.get("name", action_id))


func _get_resource_name(resource_id: String) -> String:
	if resource_id.is_empty():
		return "未知资源"
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	if resource_system == null:
		return resource_id
	if resource_system.has_method("get_resource_name"):
		return str(resource_system.get_resource_name(resource_id))
	return resource_id


func _emit_event_recorded(event: Dictionary) -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("event_recorded"):
		event_bus.event_recorded.emit(event.duplicate(true))


func _emit_npc_memory_changed(npc_id: String) -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("npc_memory_changed"):
		event_bus.npc_memory_changed.emit(npc_id)


func _emit_location_info_changed(location_id: String) -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("location_info_changed"):
		event_bus.location_info_changed.emit(location_id)


func _emit_public_event_added(event: Dictionary) -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.public_event_added.emit(event.duplicate(true))
