extends Node

const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const BUILDING_SYSTEM_PATH := "/root/Main/Systems/BuildingSystem"
const RESOURCE_SYSTEM_PATH := "/root/Main/Systems/ResourceSystem"
const ACTION_SYSTEM_PATH := "/root/Main/Systems/ActionSystem"
const DEFAULT_LOCATION_ID := "plaza"
const DEFAULT_VISIBILITY := "private"
const PUBLIC_VISIBILITY := "plaza_public"
const LOCAL_PUBLIC_VISIBILITY := "local_public"
const PLAYER_ACTOR_ID := "guard_officer"
const PLAYER_DISPLAY_NAME := "守备官"
const ENTERABLE_LOCATION_IDS: Array[String] = [
	"plaza", "dormitory", "dining_hall", "tavern", "garden", "blacksmith",
	"training_ground", "stable", "chapel", "clinic", "workshop"
]
const PLAZA_KEY_ENTITY_IDS: Array[String] = ["main_hall", "wall", "front_gate", "warehouse"]
const PLAZA_STATE_SUBJECT_ID := "system"

const EVENT_TYPES: Array[String] = [
	"wake_up", "plan_created", "reflection_started", "sleep_started", "sleep_ended",
	"location_entered", "location_exited",
	"work_started", "work_completed", "work_failed", "repair_assist_started", "eat_started", "eat_completed",
	"dialogue_started", "dialogue_turn", "dialogue_ended",
	"money_given", "equipment_given", "equipment_changed", "order_assigned", "npc_attacked_by_player",
	"skill_improved", "npc_recruited", "npc_left_recruited_state",
	"combat_started", "combat_ended", "attack_made", "damage_taken", "low_hp_triggered",
	"unconscious_started", "healing_started", "healing_completed", "revived", "escape_started", "escaped",
	"building_damaged", "building_repaired", "building_upgraded", "resource_changed",
	"plaza_notice_changed", "plaza_status_changed"
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
var _location_info_nodes: Dictionary = {}
var _event_counter := 0


func initialize() -> void:
	_events_by_id.clear()
	_global_event_ids.clear()
	_npc_daily_event_ids.clear()
	_npc_daily_witness_ids.clear()
	_plaza_public_query_event_ids.clear()
	_initialize_location_info_nodes()
	_event_counter = 0


func _ready() -> void:
	initialize()
	_sync_initial_people_present()


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
	if visibility == LOCAL_PUBLIC_VISIBILITY:
		var location_id := str(normalized.get("location_id", DEFAULT_LOCATION_ID))
		_emit_location_info_changed(location_id)
		_broadcast_public_event(normalized, location_id)

	if visibility == PUBLIC_VISIBILITY:
		_plaza_public_query_event_ids.append(event_id)
		_emit_public_event_added(normalized)
		_emit_location_info_changed(DEFAULT_LOCATION_ID)
		_broadcast_public_event(normalized, DEFAULT_LOCATION_ID)

		var event_location_id := str(normalized.get("location_id", DEFAULT_LOCATION_ID))
		if event_location_id != DEFAULT_LOCATION_ID and is_enterable_location(event_location_id):
			_emit_location_info_changed(event_location_id)
			_broadcast_public_event(normalized, event_location_id)

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


func move_npc_between_locations(npc_id: String, from_location_id: String, to_location_id: String) -> Dictionary:
	if npc_id.is_empty():
		return {}

	var normalized_to_location := _normalize_location_id(to_location_id)
	var normalized_from_location := _normalize_location_id(from_location_id)
	if not is_enterable_location(normalized_to_location):
		normalized_to_location = DEFAULT_LOCATION_ID

	if is_enterable_location(normalized_from_location):
		_remove_person_from_location(normalized_from_location, npc_id)

	# Guard against stale membership if the caller had an outdated from_location_id.
	for location_id in _location_info_nodes.keys():
		if str(location_id) != normalized_to_location:
			_remove_person_from_location(str(location_id), npc_id, false)

	_add_person_to_location(normalized_to_location, npc_id)
	var snapshot := get_location_snapshot(normalized_to_location)
	_emit_location_info_changed(normalized_to_location)
	return snapshot


func get_location_snapshot(location_id: String) -> Dictionary:
	var normalized_location_id := _normalize_location_id(location_id)
	if not is_enterable_location(normalized_location_id):
		normalized_location_id = DEFAULT_LOCATION_ID
	if not _location_info_nodes.has(normalized_location_id):
		_ensure_location_info_node(normalized_location_id)

	var node: Dictionary = _location_info_nodes.get(normalized_location_id, {})
	var snapshot := {
		"id": normalized_location_id,
		"name": _get_location_name(normalized_location_id),
		"is_enterable": true,
		"people_present": _normalize_string_array(node.get("people_present", [])),
		"people_count": _normalize_string_array(node.get("people_present", [])).size(),
		"current_notice": str(node.get("current_notice", "")),
		"current_orders": str(node.get("current_orders", ""))
	}

	if normalized_location_id == DEFAULT_LOCATION_ID:
		snapshot["building"] = {}
		snapshot["key_entities"] = _get_plaza_key_entity_snapshots()
		snapshot["has_building_hp"] = false
		snapshot["current_npc_count"] = int(snapshot.get("people_count", 0))
		snapshot["current_enemy_count"] = _get_current_enemy_count()
	else:
		snapshot["building"] = _get_building_state_snapshot(normalized_location_id)
		snapshot["key_entities"] = {}
		snapshot["has_building_hp"] = true
	var building_snapshot: Dictionary = snapshot.get("building", {})
	snapshot["workstations"] = building_snapshot.get("workstations", [])
	snapshot["workstation_count"] = snapshot.get("workstations", []).size()
	snapshot["occupied_workstation_count"] = _count_occupied_workstations(snapshot.get("workstations", []))
	return snapshot.duplicate(true)


func get_location_people_present(location_id: String) -> Array[String]:
	var snapshot := get_location_snapshot(location_id)
	return _normalize_string_array(snapshot.get("people_present", []))


func is_enterable_location(location_id: String) -> bool:
	return ENTERABLE_LOCATION_IDS.has(_normalize_location_id(location_id))


func set_plaza_notice(text: String, actor_id: String = PLAZA_STATE_SUBJECT_ID) -> void:
	_ensure_location_info_node(DEFAULT_LOCATION_ID)
	var node: Dictionary = _location_info_nodes[DEFAULT_LOCATION_ID]
	node["current_notice"] = text
	_location_info_nodes[DEFAULT_LOCATION_ID] = node
	_emit_location_info_changed(DEFAULT_LOCATION_ID)
	_broadcast_plaza_state_changed("notice_changed", {"notice": text}, actor_id, "plaza_notice_changed")


func broadcast_plaza_public_event(event: Dictionary) -> Dictionary:
	var public_event := event.duplicate(true)
	public_event["visibility"] = PUBLIC_VISIBILITY
	public_event["location_id"] = DEFAULT_LOCATION_ID
	return add_event(public_event)


func broadcast_plaza_state_change(reason: String, payload: Dictionary = {}, actor_id: String = PLAZA_STATE_SUBJECT_ID) -> Dictionary:
	return _broadcast_plaza_state_changed(reason, payload, actor_id)


func notify_key_entity_state_changed(building_id: String, reason: String = "key_entity_changed") -> Dictionary:
	if not PLAZA_KEY_ENTITY_IDS.has(building_id):
		return {}
	var key_entities := _get_plaza_key_entity_snapshots()
	return _broadcast_plaza_state_changed(reason, {
		"building_id": building_id,
		"building_snapshot": key_entities.get(building_id, {}),
		"key_entities": key_entities
	})


func debug_get_location_snapshot(location_id: String) -> Dictionary:
	return get_location_snapshot(location_id)


func debug_get_location_people_present(location_id: String) -> Array[String]:
	return get_location_people_present(location_id)


func debug_move_npc_between_locations(npc_id: String, from_location_id: String, to_location_id: String) -> Dictionary:
	return move_npc_between_locations(npc_id, from_location_id, to_location_id)


func debug_set_plaza_notice(text: String) -> void:
	set_plaza_notice(text)


func debug_broadcast_plaza_public_event(event_type: String, subject_npc_id: String, payload: Dictionary = {}) -> Dictionary:
	return broadcast_plaza_public_event({
		"type": event_type,
		"subject_npc_id": subject_npc_id,
		"actor_ids": [subject_npc_id],
		"target_ids": [DEFAULT_LOCATION_ID],
		"importance": 60,
		"payload": payload
	})


func record_player_interaction(
	npc_id: String,
	event_type: String,
	payload: Dictionary = {},
	visibility: String = LOCAL_PUBLIC_VISIBILITY
) -> Dictionary:
	if npc_id.is_empty():
		return {}
	if not EVENT_TYPES.has(event_type):
		push_warning("Player interaction uses unreserved event type: %s" % event_type)

	var location_id := _get_npc_current_info_location(npc_id)
	var interaction_payload := payload.duplicate(true)
	interaction_payload["player_actor_id"] = PLAYER_ACTOR_ID
	interaction_payload["actor_display_name"] = PLAYER_DISPLAY_NAME
	if not interaction_payload.has("target_npc_id"):
		interaction_payload["target_npc_id"] = npc_id

	return add_event({
		"type": event_type,
		"subject_npc_id": npc_id,
		"actor_ids": [PLAYER_ACTOR_ID],
		"target_ids": [npc_id, location_id],
		"location_id": location_id,
		"visibility": visibility,
		"importance": int(payload.get("importance", 45)),
		"payload": interaction_payload
	})


func get_npc_short_term_memory(npc_id: String) -> Dictionary:
	return {
		"npc_id": npc_id,
		"event_log": get_npc_daily_events(npc_id),
		"witness_log": get_npc_witness_events(npc_id),
		"event_count": get_npc_daily_events(npc_id).size(),
		"witness_count": get_npc_witness_events(npc_id).size()
	}


func get_npc_short_term_memory_ids(npc_id: String) -> Dictionary:
	return {
		"npc_id": npc_id,
		"event_log": get_npc_daily_event_ids(npc_id),
		"witness_log": get_npc_daily_witness_ids(npc_id)
	}


func debug_record_player_money_given(npc_id: String, amount: int, visibility: String = LOCAL_PUBLIC_VISIBILITY) -> Dictionary:
	return record_player_interaction(npc_id, "money_given", {
		"amount": maxi(0, amount),
		"resource_id": "gold"
	}, visibility)


func debug_record_player_attack_npc(npc_id: String, damage: int, visibility: String = PUBLIC_VISIBILITY) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var hp_before := 0
	if npc_system != null:
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		hp_before = int(state.get("hp", 0))
	return record_player_interaction(npc_id, "npc_attacked_by_player", {
		"damage": maxi(0, damage),
		"hp_before": hp_before,
		"hp_after": maxi(0, hp_before - maxi(0, damage))
	}, visibility)


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


func get_npc_daily_witness_ids(npc_id: String) -> Array:
	return _npc_daily_witness_ids.get(npc_id, []).duplicate()


func get_plaza_public_events() -> Array[Dictionary]:
	return _events_from_ids(_plaza_public_query_event_ids)


func get_supported_event_types() -> Array[String]:
	return EVENT_TYPES.duplicate()


func get_required_payload_fields(event_type: String) -> Array:
	return REQUIRED_PAYLOAD_FIELDS.get(event_type, []).duplicate()


func clear_event_log() -> void:
	_events_by_id.clear()
	_global_event_ids.clear()
	_npc_daily_event_ids.clear()
	_npc_daily_witness_ids.clear()
	_plaza_public_query_event_ids.clear()
	_event_counter = 0


func debug_get_all_events() -> Array[Dictionary]:
	return get_all_events()


func debug_get_npc_events(npc_id: String) -> Array[Dictionary]:
	return get_npc_daily_events(npc_id)


func debug_get_npc_witness_events(npc_id: String) -> Array[Dictionary]:
	return get_npc_witness_events(npc_id)


func debug_get_npc_short_term_memory(npc_id: String) -> Dictionary:
	return get_npc_short_term_memory(npc_id)


func debug_get_plaza_public_events() -> Array[Dictionary]:
	return get_plaza_public_events()


func _initialize_location_info_nodes() -> void:
	_location_info_nodes.clear()
	for location_id in ENTERABLE_LOCATION_IDS:
		_ensure_location_info_node(location_id)


func _ensure_location_info_node(location_id: String) -> void:
	var normalized_location_id := _normalize_location_id(location_id)
	if _location_info_nodes.has(normalized_location_id):
		return
	_location_info_nodes[normalized_location_id] = {
		"id": normalized_location_id,
		"name": _get_location_name(normalized_location_id),
		"people_present": [],
		"current_notice": "",
		"current_orders": ""
	}


func _sync_initial_people_present() -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_ids"):
		return

	for npc_id in npc_system.get_npc_ids():
		var npc_state: Dictionary = npc_system.get_npc_state(str(npc_id))
		var location_id := _normalize_location_id(str(npc_state.get("current_location", DEFAULT_LOCATION_ID)))
		if not is_enterable_location(location_id):
			location_id = DEFAULT_LOCATION_ID
		_add_person_to_location(location_id, str(npc_id))


func _normalize_location_id(location_id: String) -> String:
	if location_id.is_empty():
		return DEFAULT_LOCATION_ID
	return location_id


func _add_person_to_location(location_id: String, npc_id: String) -> void:
	_ensure_location_info_node(location_id)
	var node: Dictionary = _location_info_nodes[location_id]
	var people := _normalize_string_array(node.get("people_present", []))
	if not people.has(npc_id):
		people.append(npc_id)
	node["people_present"] = people
	_location_info_nodes[location_id] = node


func _remove_person_from_location(location_id: String, npc_id: String, emit_changed: bool = true) -> void:
	if not _location_info_nodes.has(location_id):
		return
	var node: Dictionary = _location_info_nodes[location_id]
	var people := _normalize_string_array(node.get("people_present", []))
	if people.has(npc_id):
		people.erase(npc_id)
		node["people_present"] = people
		_location_info_nodes[location_id] = node
		if emit_changed:
			_emit_location_info_changed(location_id)


func _broadcast_public_event(event: Dictionary, location_id: String) -> void:
	if not _events_by_id.has(str(event.get("event_id", ""))):
		return
	var target_location_id := _normalize_location_id(location_id)
	if not is_enterable_location(target_location_id):
		target_location_id = DEFAULT_LOCATION_ID

	var recipient_ids := get_location_people_present(target_location_id)
	var subject_npc_id := str(event.get("subject_npc_id", ""))
	for npc_id in recipient_ids:
		if npc_id == subject_npc_id:
			continue
		add_witness_event(npc_id, str(event.get("event_id", "")))


func _broadcast_plaza_state_changed(
	reason: String,
	extra_payload: Dictionary = {},
	actor_id: String = PLAZA_STATE_SUBJECT_ID,
	event_type: String = "plaza_status_changed"
) -> Dictionary:
	var snapshot := get_location_snapshot(DEFAULT_LOCATION_ID)
	var payload := extra_payload.duplicate(true)
	payload["reason"] = reason
	payload["plaza_snapshot"] = snapshot
	payload["people_count"] = int(snapshot.get("people_count", 0))
	payload["enemy_count"] = int(snapshot.get("current_enemy_count", 0))
	payload["key_entities"] = snapshot.get("key_entities", {})
	payload["current_notice"] = str(snapshot.get("current_notice", ""))
	return add_event({
		"type": event_type,
		"subject_npc_id": actor_id,
		"actor_ids": [actor_id],
		"target_ids": [DEFAULT_LOCATION_ID],
		"location_id": DEFAULT_LOCATION_ID,
		"visibility": PUBLIC_VISIBILITY,
		"importance": 40,
		"payload": payload
	})


func _get_building_state_snapshot(building_id: String) -> Dictionary:
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null:
		return {}
	var building: Dictionary = building_system.get_building(building_id)
	if building.is_empty():
		return {}
	var workstations: Array = building.get("workstations", [])
	return {
		"id": building_id,
		"name": str(building.get("name", building_id)),
		"level": int(building.get("level", 1)),
		"hp": int(building.get("hp", 0)),
		"max_hp": int(building.get("max_hp", 0)),
		"available": int(building.get("hp", 0)) > 0,
		"tags": building.get("tags", []),
		"workstations": workstations.duplicate(true),
		"workstation_count": workstations.size(),
		"occupied_workstation_count": _count_occupied_workstations(workstations)
	}


func _get_plaza_key_entity_snapshots() -> Dictionary:
	var snapshots := {}
	for building_id in PLAZA_KEY_ENTITY_IDS:
		snapshots[building_id] = _get_building_state_snapshot(building_id)
	return snapshots


func _get_current_enemy_count() -> int:
	var enemies_root := get_node_or_null("/root/Main/WorldRoot/Station/Enemies")
	if enemies_root == null:
		return 0
	return enemies_root.get_child_count()


func _count_occupied_workstations(workstations: Array) -> int:
	var count := 0
	for raw_workstation in workstations:
		if not raw_workstation is Dictionary:
			continue
		var workstation: Dictionary = raw_workstation
		var occupied_by := str(workstation.get("occupied_by", ""))
		if not occupied_by.is_empty() and occupied_by != "<null>":
			count += 1
	return count


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

	if visibility == PUBLIC_VISIBILITY and not is_enterable_location(location_id):
		if not payload.has("source_location_id"):
			payload["source_location_id"] = location_id
		location_id = DEFAULT_LOCATION_ID

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
	if event_type == "plaza_notice_changed":
		return "Plaza notice changed: %s" % str(payload.get("notice", ""))
	if event_type == "plaza_status_changed":
		return "Plaza public state changed: %s" % str(payload.get("reason", "state_changed"))
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
		"repair_assist_started":
			return "%s开始协助修复%s。" % [actor, location]
		"eat_started":
			return "%s开始在%s吃饭。" % [actor, location]
		"eat_completed":
			return "%s吃了%s，恢复了%d点饱食度。" % [
				actor,
				_get_resource_name(str(payload.get("resource_id", ""))),
				int(payload.get("satiety_restore", 0))
			]
		"money_given":
			return "%s给了%s%d枚第纳尔。" % [PLAYER_DISPLAY_NAME, actor, int(payload.get("amount", 0))]
		"equipment_given":
			return "%s把%s交给了%s。" % [PLAYER_DISPLAY_NAME, str(payload.get("equipment_name", "装备")), actor]
		"equipment_changed":
			return "%s为%s更换了%s。" % [PLAYER_DISPLAY_NAME, actor, str(payload.get("equipment_name", "装备"))]
		"order_assigned":
			return "%s给%s指派了%s。" % [PLAYER_DISPLAY_NAME, actor, str(payload.get("order_name", "任务"))]
		"npc_attacked_by_player":
			return "%s攻击了%s，造成%d点伤害。" % [PLAYER_DISPLAY_NAME, actor, int(payload.get("damage", 0))]
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


func _get_npc_current_info_location(npc_id: String) -> String:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return DEFAULT_LOCATION_ID
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var location_id := _normalize_location_id(str(state.get("current_location", DEFAULT_LOCATION_ID)))
	if not is_enterable_location(location_id):
		return DEFAULT_LOCATION_ID
	return location_id


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
