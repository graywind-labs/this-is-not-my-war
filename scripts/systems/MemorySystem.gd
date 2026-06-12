extends Node

const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const BUILDING_SYSTEM_PATH := "/root/Main/Systems/BuildingSystem"
const RESOURCE_SYSTEM_PATH := "/root/Main/Systems/ResourceSystem"
const ACTION_SYSTEM_PATH := "/root/Main/Systems/ActionSystem"
const DEFAULT_LOCATION_ID := "plaza"
const DEFAULT_VISIBILITY := "private"
const LOCAL_PUBLIC_VISIBILITY := "local_public"
const PLAYER_ACTOR_ID := "guard_officer"
const PLAYER_DISPLAY_NAME := "守备官"
const ENTERABLE_LOCATION_IDS: Array[String] = [
	"plaza", "dormitory", "dining_hall", "tavern", "garden", "blacksmith",
	"training_ground", "stable", "chapel", "clinic", "workshop"
]
const PLAZA_STATE_SUBJECT_ID := "system"

const EVENT_TYPES: Array[String] = [
	"wake_up", "plan_created", "plan_revised", "reflection_started", "sleep_started", "sleep_ended",
	"location_entered", "location_exited",
	"work_started", "work_completed", "work_failed", "repair_assist_started", "upgrade_assist_started", "eat_started", "eat_completed",
	"dialogue_turn", "proactive_talk_started", "proactive_talk_message",
	"money_given", "equipment_given", "equipment_changed", "order_assigned", "npc_attacked_by_player",
	"skill_improved", "attribute_improved", "npc_recruited", "npc_left_recruited_state",
	"npc_mode_changed", "combat_started", "combat_ended", "combat_alarm_rang", "combat_rally_started", "combat_rally_encountered_enemy", "attack_made", "damage_taken", "low_hp_triggered",
	"avoidance_started", "avoidance_ended", "unconscious_started", "healing_started", "healing_completed", "revived", "escape_started", "escaped",
	"building_damaged", "building_repaired", "building_upgraded", "resource_changed",
	"plaza_notice_changed", "plaza_status_changed", "location_status_changed"
]

const REQUIRED_PAYLOAD_FIELDS := {
	"dialogue_turn": ["dialogue_id", "participant_npc_ids", "dialogue_text", "speaker_name", "listener_name", "visibility", "current_round", "max_rounds", "is_recruitment_request", "recruitment_result"],
	"proactive_talk_started": ["prompt_text", "duration_seconds"],
	"proactive_talk_message": ["dialogue_id", "speaker_name", "listener_name", "speaker_text"],
	"plan_created": ["plan_day", "items"],
	"plan_revised": ["plan_day", "items", "reason", "source"],
	"location_entered": ["to_location_id", "from_location_id"],
	"location_exited": ["from_location_id", "to_location_id"],
	"work_started": ["action_id", "workstation_id"],
	"work_completed": ["action_id", "input_resources", "output_resources"],
	"work_failed": ["action_id", "reason"],
	"eat_completed": ["action_id", "resource_id", "amount", "satiety_restore"],
	"combat_alarm_rang": ["source", "npc_count", "active_enemy_count"],
	"combat_rally_started": ["formation_row", "unit_type", "rally_location_id", "facing_direction"],
	"combat_rally_encountered_enemy": ["enemy_id", "distance"],
	"npc_mode_changed": ["npc_id", "from_mode", "to_mode", "reason"],
	"avoidance_started": ["enemy_id", "distance", "reason", "target_id"],
	"avoidance_ended": ["reason", "active_enemy_count"],
	"damage_taken": ["damage", "hp_before", "hp_after"],
	"unconscious_started": ["damage", "hp_before", "hp_after"],
	"healing_started": ["healer_npc_id", "target_npc_id", "money_spent"],
	"healing_completed": ["healer_npc_id", "target_npc_id", "money_spent"],
	"revived": ["hp_before", "hp_after", "recovery_source"],
	"order_assigned": ["previous_order_text", "new_order_text", "order_revision"],
	"attribute_improved": ["attribute", "before", "after", "assigned_by"]
}

var _events_by_id: Dictionary = {}
var _global_event_ids: Array[String] = []
var _npc_daily_event_ids: Dictionary = {}
var _npc_daily_witness_ids: Dictionary = {}
var _plaza_event_ids: Array[String] = []
var _location_info_nodes: Dictionary = {}
var _last_location_state_keys: Dictionary = {}
var _last_plaza_external_state_keys: Dictionary = {}
var _last_plaza_external_states: Dictionary = {}
var _last_location_external_states: Dictionary = {}
var _last_location_workstation_states: Dictionary = {}
var _event_counter := 0


func initialize() -> void:
	_events_by_id.clear()
	_global_event_ids.clear()
	_npc_daily_event_ids.clear()
	_npc_daily_witness_ids.clear()
	_plaza_event_ids.clear()
	_initialize_location_info_nodes()
	_last_location_state_keys.clear()
	_last_plaza_external_state_keys.clear()
	_last_plaza_external_states.clear()
	_last_location_external_states.clear()
	_last_location_workstation_states.clear()
	_event_counter = 0


func _ready() -> void:
	initialize()
	_sync_initial_people_present()
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and not event_bus.building_state_changed.is_connected(_on_building_state_changed):
		event_bus.building_state_changed.connect(_on_building_state_changed)


func add_event(event: Dictionary) -> Dictionary:
	if event.is_empty():
		return {}

	var normalized := _normalize_event(event)
	if normalized.is_empty():
		return {}

	var event_id := str(normalized["event_id"])
	_events_by_id[event_id] = normalized
	_global_event_ids.append(event_id)

	for npc_id in _get_experiencing_npc_ids(normalized):
		if not _npc_daily_event_ids.has(npc_id):
			_npc_daily_event_ids[npc_id] = []
		if not _npc_daily_event_ids[npc_id].has(event_id):
			_npc_daily_event_ids[npc_id].append(event_id)

	var visibility := str(normalized.get("visibility", DEFAULT_VISIBILITY))
	if visibility == LOCAL_PUBLIC_VISIBILITY:
		var location_id := str(normalized.get("location_id", DEFAULT_LOCATION_ID))
		_emit_location_info_changed(location_id)
		_broadcast_public_event(normalized, location_id)
		if location_id == DEFAULT_LOCATION_ID:
			_plaza_event_ids.append(event_id)
			_emit_public_event_added(normalized)

	_emit_event_recorded(normalized)
	for npc_id in _get_experiencing_npc_ids(normalized):
		_emit_npc_memory_changed(npc_id)
	return normalized.duplicate(true)


func add_witness_event(npc_id: String, event_id: String) -> bool:
	if npc_id.is_empty() or not _events_by_id.has(event_id):
		return false
	if not _can_npc_receive_witness(npc_id):
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
	if normalized_from_location != normalized_to_location:
		_record_location_entry_snapshot_witness(npc_id, normalized_to_location, snapshot)
	return snapshot


func _record_location_entry_snapshot_witness(npc_id: String, location_id: String, snapshot: Dictionary) -> void:
	if npc_id.is_empty() or snapshot.is_empty():
		return

	var normalized_location_id := _normalize_location_id(location_id)
	if not is_enterable_location(normalized_location_id):
		normalized_location_id = DEFAULT_LOCATION_ID

	var event := add_event({
		"type": "location_status_changed",
		"subject_npc_id": PLAZA_STATE_SUBJECT_ID,
		"actor_ids": [PLAZA_STATE_SUBJECT_ID],
		"target_ids": [normalized_location_id],
		"location_id": normalized_location_id,
		"visibility": DEFAULT_VISIBILITY,
		"importance": 30,
		"payload": {
			"reason": "location_entry_snapshot",
			"location_snapshot": snapshot.duplicate(true),
			"building_id": normalized_location_id,
			"building_name": _get_location_name(normalized_location_id),
			"building_snapshot": snapshot.get("building", {})
		}
	})
	if not event.is_empty():
		add_witness_event(npc_id, str(event.get("event_id", "")))


func get_location_snapshot(location_id: String) -> Dictionary:
	var normalized_location_id := _normalize_location_id(location_id)
	if not is_enterable_location(normalized_location_id):
		normalized_location_id = DEFAULT_LOCATION_ID
	if not _location_info_nodes.has(normalized_location_id):
		_ensure_location_info_node(normalized_location_id)

	var node: Dictionary = _location_info_nodes.get(normalized_location_id, {})
	var people_present := _normalize_string_array(node.get("people_present", []))
	var snapshot := {
		"id": normalized_location_id,
		"name": _get_location_name(normalized_location_id),
		"is_enterable": true,
		"people_present": people_present,
		"people_statuses": _get_people_status_snapshots(people_present),
		"current_notice": str(node.get("current_notice", "")),
		"current_orders": str(node.get("current_orders", ""))
	}

	if normalized_location_id == DEFAULT_LOCATION_ID:
		snapshot["building"] = {}
		snapshot["building_external_states"] = _get_all_building_external_state_snapshots()
		snapshot["key_entities"] = snapshot["building_external_states"]
		snapshot["has_building_hp"] = false
		snapshot["current_enemy_count"] = _get_current_enemy_count()
	else:
		snapshot["building"] = _get_building_full_state_snapshot(normalized_location_id)
		snapshot["key_entities"] = {}
		snapshot["has_building_hp"] = false
	var building_snapshot: Dictionary = snapshot.get("building", {})
	var internal_state: Dictionary = building_snapshot.get("internal_state", {})
	snapshot["external_state"] = building_snapshot.get("external_state", {})
	snapshot["internal_state"] = internal_state
	snapshot["workstations"] = internal_state.get("workstations", building_snapshot.get("workstations", []))
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


func broadcast_plaza_event(event: Dictionary) -> Dictionary:
	var public_event := event.duplicate(true)
	public_event["visibility"] = LOCAL_PUBLIC_VISIBILITY
	public_event["location_id"] = DEFAULT_LOCATION_ID
	return add_event(public_event)


func broadcast_plaza_state_change(reason: String, payload: Dictionary = {}, actor_id: String = PLAZA_STATE_SUBJECT_ID) -> Dictionary:
	return _broadcast_plaza_state_changed(reason, payload, actor_id)


func notify_key_entity_state_changed(building_id: String, reason: String = "key_entity_changed") -> Dictionary:
	var key_entities := _get_all_building_external_state_snapshots()
	return _broadcast_plaza_state_changed(reason, {
		"building_id": building_id,
		"building_name": str(key_entities.get(building_id, {}).get("name", building_id)),
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


func debug_broadcast_plaza_event(event_type: String, subject_npc_id: String, payload: Dictionary = {}) -> Dictionary:
	return broadcast_plaza_event({
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


func clear_npc_short_term_memory(npc_id: String) -> Dictionary:
	if npc_id.is_empty():
		return {
			"ok": false,
			"reason": "empty_npc_id",
			"message": "NPC ID 为空。"
		}

	var event_count := get_npc_daily_event_ids(npc_id).size()
	var witness_count := get_npc_daily_witness_ids(npc_id).size()
	_npc_daily_event_ids.erase(npc_id)
	_npc_daily_witness_ids.erase(npc_id)
	_emit_npc_memory_changed(npc_id)
	return {
		"ok": true,
		"npc_id": npc_id,
		"event_count": event_count,
		"witness_count": witness_count
	}


func debug_clear_npc_short_term_memory(npc_id: String) -> Dictionary:
	return clear_npc_short_term_memory(npc_id)


func debug_record_player_money_given(npc_id: String, amount: int, visibility: String = LOCAL_PUBLIC_VISIBILITY) -> Dictionary:
	return record_player_interaction(npc_id, "money_given", {
		"amount": maxi(0, amount),
		"resource_id": "gold"
	}, visibility)


func debug_record_player_attack_npc(npc_id: String, damage: int, visibility: String = LOCAL_PUBLIC_VISIBILITY) -> Dictionary:
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


func get_plaza_events() -> Array[Dictionary]:
	return _events_from_ids(_plaza_event_ids)


func get_supported_event_types() -> Array[String]:
	return EVENT_TYPES.duplicate()


func get_required_payload_fields(event_type: String) -> Array:
	return REQUIRED_PAYLOAD_FIELDS.get(event_type, []).duplicate()


func clear_event_log() -> void:
	_events_by_id.clear()
	_global_event_ids.clear()
	_npc_daily_event_ids.clear()
	_npc_daily_witness_ids.clear()
	_plaza_event_ids.clear()
	_event_counter = 0


func debug_get_all_events() -> Array[Dictionary]:
	return get_all_events()


func debug_get_npc_events(npc_id: String) -> Array[Dictionary]:
	return get_npc_daily_events(npc_id)


func debug_get_npc_witness_events(npc_id: String) -> Array[Dictionary]:
	return get_npc_witness_events(npc_id)


func debug_get_npc_short_term_memory(npc_id: String) -> Dictionary:
	return get_npc_short_term_memory(npc_id)


func debug_get_plaza_events() -> Array[Dictionary]:
	return get_plaza_events()


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


func _on_building_state_changed(building_id: String) -> void:
	if building_id.is_empty():
		return

	var external_snapshot := _get_building_external_state_snapshot(building_id)
	if external_snapshot.is_empty():
		return

	var external_key := JSON.stringify(external_snapshot)
	if str(_last_plaza_external_state_keys.get(building_id, "")) != external_key:
		_last_plaza_external_state_keys[building_id] = external_key
		var plaza_changed_fields := _diff_state_fields(
			_last_plaza_external_states.get(building_id, {}),
			external_snapshot,
			["level", "condition"]
		)
		_last_plaza_external_states[building_id] = external_snapshot.duplicate(true)
		_broadcast_plaza_state_changed("building_external_state_changed", {
			"building_id": building_id,
			"building_name": str(external_snapshot.get("name", building_id)),
			"changed_fields": plaza_changed_fields
		})

	if not is_enterable_location(building_id):
		return

	var location_snapshot := get_location_snapshot(building_id)
	var location_external_state: Dictionary = location_snapshot.get("external_state", {})
	var location_external_key := JSON.stringify(location_external_state)
	var location_external_cache_key := "%s:external" % building_id
	if str(_last_location_state_keys.get(location_external_cache_key, "")) != location_external_key:
		_last_location_state_keys[location_external_cache_key] = location_external_key
		var location_changed_fields := _diff_state_fields(
			_last_location_external_states.get(building_id, {}),
			location_external_state,
			["level", "condition"]
		)
		_last_location_external_states[building_id] = location_external_state.duplicate(true)
		_broadcast_location_state_changed(building_id, "building_external_state_changed", {
			"building_id": building_id,
			"building_name": str(external_snapshot.get("name", building_id)),
			"changed_fields": location_changed_fields
		})

	var workstations := _normalize_workstations_for_info(location_snapshot.get("workstations", []))
	var workstation_state := _workstation_state_by_id(workstations)
	var location_internal_key := JSON.stringify(workstation_state)
	var location_internal_cache_key := "%s:internal" % building_id
	if str(_last_location_state_keys.get(location_internal_cache_key, "")) != location_internal_key:
		_last_location_state_keys[location_internal_cache_key] = location_internal_key
		var changed_workstations := _diff_workstation_states(
			_last_location_workstation_states.get(building_id, {}),
			workstation_state
		)
		_last_location_workstation_states[building_id] = workstation_state.duplicate(true)
		_broadcast_location_state_changed(building_id, "building_internal_state_changed", {
			"building_id": building_id,
			"building_name": str(external_snapshot.get("name", building_id)),
			"changed_workstations": changed_workstations
		})


func _broadcast_public_event(event: Dictionary, location_id: String) -> void:
	if not _events_by_id.has(str(event.get("event_id", ""))):
		return
	var target_location_id := _normalize_location_id(location_id)
	if not is_enterable_location(target_location_id):
		target_location_id = DEFAULT_LOCATION_ID

	var recipient_ids := get_location_people_present(target_location_id)
	var subject_npc_id := str(event.get("subject_npc_id", ""))
	var participant_npc_ids := _normalize_string_array(event.get("payload", {}).get("participant_npc_ids", []))
	for npc_id in recipient_ids:
		if npc_id == subject_npc_id or participant_npc_ids.has(npc_id):
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
	if reason == "notice_changed":
		payload["current_notice"] = str(snapshot.get("current_notice", ""))
	elif not payload.has("changed_fields"):
		payload["enemy_count"] = int(snapshot.get("current_enemy_count", 0))
		payload["key_entities"] = snapshot.get("key_entities", {})
		payload["building_external_states"] = snapshot.get("building_external_states", {})
		payload["current_notice"] = str(snapshot.get("current_notice", ""))
	var target_ids: Array[String] = [DEFAULT_LOCATION_ID]
	if payload.has("building_id"):
		target_ids.append(str(payload["building_id"]))
	return add_event({
		"type": event_type,
		"subject_npc_id": actor_id,
		"actor_ids": [actor_id],
		"target_ids": target_ids,
		"location_id": DEFAULT_LOCATION_ID,
		"visibility": LOCAL_PUBLIC_VISIBILITY,
		"importance": 40,
		"payload": payload
	})


func _broadcast_location_state_changed(
	location_id: String,
	reason: String,
	extra_payload: Dictionary = {}
) -> Dictionary:
	var normalized_location_id := _normalize_location_id(location_id)
	if not is_enterable_location(normalized_location_id):
		normalized_location_id = DEFAULT_LOCATION_ID
	if normalized_location_id == DEFAULT_LOCATION_ID:
		return _broadcast_plaza_state_changed(reason, extra_payload)

	var snapshot := get_location_snapshot(normalized_location_id)
	var payload := extra_payload.duplicate(true)
	payload["reason"] = reason
	payload["building_id"] = normalized_location_id
	payload["building_name"] = _get_location_name(normalized_location_id)
	if not payload.has("changed_fields") and not payload.has("changed_workstations"):
		payload["location_snapshot"] = snapshot
		payload["building_snapshot"] = snapshot.get("building", {})
	return add_event({
		"type": "location_status_changed",
		"subject_npc_id": PLAZA_STATE_SUBJECT_ID,
		"actor_ids": [PLAZA_STATE_SUBJECT_ID],
		"target_ids": [normalized_location_id],
		"location_id": normalized_location_id,
		"visibility": LOCAL_PUBLIC_VISIBILITY,
		"importance": 35,
		"payload": payload
	})


func _get_building_external_state_snapshot(building_id: String) -> Dictionary:
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null:
		return {}
	var building: Dictionary = building_system.get_building(building_id)
	if building.is_empty():
		return {}
	return {
		"id": building_id,
		"name": str(building.get("name", building_id)),
		"level": int(building.get("level", 1)),
		"condition": str(building.get("condition", _derive_building_condition(building)))
	}


func _get_building_full_state_snapshot(building_id: String) -> Dictionary:
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null:
		return {}
	var building: Dictionary = building_system.get_building(building_id)
	if building.is_empty():
		return {}
	var workstations: Array = building.get("workstations", [])
	var node: Dictionary = _location_info_nodes.get(building_id, {})
	var people_present := _normalize_string_array(node.get("people_present", []))
	var people_statuses := _get_people_status_snapshots(people_present)
	var external_state := _get_building_external_state_snapshot(building_id)
	var internal_state := {
		"people_present": people_present,
		"people_statuses": people_statuses,
		"workstations": _normalize_workstations_for_info(workstations)
	}
	var snapshot := external_state.duplicate(true)
	snapshot["external_state"] = external_state
	snapshot["internal_state"] = internal_state
	snapshot["people_present"] = people_present
	snapshot["people_statuses"] = people_statuses
	snapshot["workstations"] = internal_state["workstations"]
	return snapshot


func _get_all_building_external_state_snapshots() -> Dictionary:
	var snapshots := {}
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null or not building_system.has_method("get_building_ids"):
		return snapshots
	for raw_building_id in building_system.get_building_ids():
		var building_id := str(raw_building_id)
		snapshots[building_id] = _get_building_external_state_snapshot(building_id)
	return snapshots


func _derive_building_condition(building: Dictionary) -> String:
	if int(building.get("hp", 0)) >= int(building.get("max_hp", 0)):
		return "intact"
	return "damaged"


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


func _normalize_workstations_for_info(workstations: Array) -> Array[Dictionary]:
	var normalized: Array[Dictionary] = []
	for raw_workstation in workstations:
		if not raw_workstation is Dictionary:
			continue
		var workstation: Dictionary = raw_workstation
		var occupied_by := str(workstation.get("occupied_by", ""))
		if occupied_by == "<null>":
			occupied_by = ""
		normalized.append({
			"id": str(workstation.get("id", "")),
			"type": str(workstation.get("type", "general")),
			"occupied_by": occupied_by,
			"status": "occupied" if not occupied_by.is_empty() else "free"
		})
	return normalized


func _get_people_status_snapshots(people: Array[String]) -> Array[Dictionary]:
	var statuses: Array[Dictionary] = []
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return statuses

	for npc_id in people:
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		if state.is_empty():
			continue
		var hp := int(state.get("hp", 0))
		var max_hp := maxi(1, int(state.get("max_hp", 100)))
		var unconscious := bool(state.get("unconscious", false))
		var healer_ids: Array[String] = []
		if unconscious:
			healer_ids = _get_healing_helpers_for_target(npc_id)
		statuses.append({
			"npc_id": npc_id,
			"name": _get_npc_display_name(npc_id),
			"life_status": _get_life_status_id(hp, max_hp, unconscious),
			"life_status_text": _format_life_status(hp, max_hp, unconscious, healer_ids),
			"healer_npc_ids": healer_ids,
			"healer_names": _get_npc_names(healer_ids),
			"action_status": _format_action_status(str(state.get("current_action", "idle")))
		})
	return statuses


func _get_life_status_id(hp: int, max_hp: int, unconscious: bool) -> String:
	if unconscious:
		return "unconscious"
	if hp >= max_hp:
		return "healthy"
	return "injured"


func _format_life_status(hp: int, max_hp: int, unconscious: bool, healer_ids: Array[String] = []) -> String:
	if unconscious:
		if healer_ids.is_empty():
			return "昏迷"
		return "昏迷，%s正在治疗" % "、".join(_get_npc_names(healer_ids))
	if hp >= max_hp:
		return "健康"
	return "受伤"


func _get_healing_helpers_for_target(target_npc_id: String) -> Array[String]:
	var result: Array[String] = []
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system == null or not action_system.has_method("get_healing_helpers_for_target"):
		return result
	for raw_helper_id in action_system.get_healing_helpers_for_target(target_npc_id):
		var helper_id := str(raw_helper_id)
		if not helper_id.is_empty() and not result.has(helper_id):
			result.append(helper_id)
	return result


func _get_npc_names(npc_ids: Array[String]) -> Array[String]:
	var names: Array[String] = []
	for npc_id in npc_ids:
		names.append(_get_npc_display_name(npc_id))
	return names


func _format_action_status(action_id: String) -> String:
	if action_id.is_empty() or action_id == "idle":
		return "待命"
	if action_id == "unconscious":
		return "昏迷"
	if action_id.begins_with("moving_to_combat_rally"):
		return "前往城门外防线"
	if action_id == "rallying_defense_line":
		return "在城门外集结"
	if action_id == "combat_ready":
		return "准备接敌"
	if action_id == "avoid_combat" or action_id == "avoiding_enemy":
		return "避战"
	if action_id.begins_with("moving_to_avoid_shelter_"):
		return "前往避战点"
	if action_id.begins_with("moving_to_"):
		return "前往%s" % _get_location_name(action_id.trim_prefix("moving_to_"))
	if action_id.begins_with("assist_heal_"):
		return "协助治疗%s" % _get_npc_display_name(action_id.trim_prefix("assist_heal_"))
	if action_id.begins_with("assist_repair_"):
		return "协助修复%s" % _get_location_name(action_id.trim_prefix("assist_repair_"))
	if action_id.begins_with("assist_upgrade_"):
		return "协助升级%s" % _get_location_name(action_id.trim_prefix("assist_upgrade_"))

	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system != null and action_system.has_method("get_action"):
		var action: Dictionary = action_system.get_action(action_id)
		if not action.is_empty():
			return str(action.get("name", action_id))
	return action_id


func _diff_state_fields(previous_state: Dictionary, current_state: Dictionary, field_names: Array[String]) -> Dictionary:
	var changed := {}
	for field_name in field_names:
		if previous_state.get(field_name) != current_state.get(field_name):
			changed[field_name] = current_state.get(field_name)
	return changed


func _workstation_state_by_id(workstations: Array) -> Dictionary:
	var states := {}
	for raw_workstation in workstations:
		if not raw_workstation is Dictionary:
			continue
		var workstation: Dictionary = raw_workstation
		var workstation_id := str(workstation.get("id", workstation.get("type", "")))
		if workstation_id.is_empty():
			continue
		states[workstation_id] = {
			"id": workstation_id,
			"type": str(workstation.get("type", "general")),
			"occupied_by": str(workstation.get("occupied_by", "")),
			"status": str(workstation.get("status", "free"))
		}
	return states


func _diff_workstation_states(previous_states: Dictionary, current_states: Dictionary) -> Array[Dictionary]:
	var changed: Array[Dictionary] = []
	for workstation_id in current_states.keys():
		var current_state: Dictionary = current_states[workstation_id]
		var previous_state: Dictionary = previous_states.get(workstation_id, {})
		if previous_state.get("occupied_by") != current_state.get("occupied_by") or previous_state.get("status") != current_state.get("status"):
			changed.append(current_state.duplicate(true))
	return changed


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
		visibility = LOCAL_PUBLIC_VISIBILITY
		location_id = DEFAULT_LOCATION_ID
	if not [DEFAULT_VISIBILITY, LOCAL_PUBLIC_VISIBILITY].has(visibility):
		push_warning("MemorySystem changed invalid visibility '%s' to private." % visibility)
		visibility = DEFAULT_VISIBILITY

	var payload: Dictionary = event.get("payload", {})
	if payload.is_empty():
		payload = _legacy_payload_from_event(event)

	if visibility == LOCAL_PUBLIC_VISIBILITY and not is_enterable_location(location_id):
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
		return "广场公告更新：%s" % str(payload.get("notice", ""))
	if event_type == "plaza_status_changed":
		return _format_building_or_plaza_state_summary(payload)
	if event_type == "location_status_changed":
		return _format_location_state_summary(payload)
	var actor := _get_npc_display_name(str(event.get("subject_npc_id", "")))
	var location := _get_location_name(str(event.get("location_id", DEFAULT_LOCATION_ID)))

	match event_type:
		"location_entered":
			return _format_location_entered_summary(actor, payload, event)
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
		"skill_improved":
			return _format_skill_improved_summary(actor, payload, location)
		"attribute_improved":
			return "%s为%s分配了1点技能点，%s从%d提高到%d。" % [
				PLAYER_DISPLAY_NAME,
				actor,
				str(payload.get("attribute_label", payload.get("attribute", "属性"))),
				int(payload.get("before", 0)),
				int(payload.get("after", 0))
			]
		"repair_assist_started":
			return "%s开始协助修复%s。" % [actor, _get_location_name(str(payload.get("building_id", event.get("location_id", DEFAULT_LOCATION_ID))))]
		"upgrade_assist_started":
			return "%s开始协助升级%s。" % [actor, _get_location_name(str(payload.get("building_id", event.get("location_id", DEFAULT_LOCATION_ID))))]
		"eat_started":
			return "%s开始在%s吃饭。" % [actor, location]
		"eat_completed":
			return "%s吃了%s，恢复了%d点饱食度。" % [
				actor,
				_get_resource_name(str(payload.get("resource_id", ""))),
				int(payload.get("satiety_restore", 0))
			]
		"dialogue_turn":
			return "%s对%s说：“%s” %s回答：“%s”" % [
				str(payload.get("speaker_name", PLAYER_DISPLAY_NAME)),
				str(payload.get("listener_name", actor)),
				str(payload.get("speaker_text", "")),
				str(payload.get("listener_name", actor)),
				str(payload.get("reply_text", ""))
			]
		"proactive_talk_started":
			return "%s想主动找守备官交涉。" % actor
		"proactive_talk_message":
			return "%s对守备官说：“%s”" % [actor, str(payload.get("speaker_text", ""))]
		"plan_created":
			return "%s制定了第%d天的行动计划，包含%d个工作阶段。" % [
				actor,
				int(payload.get("plan_day", event.get("day", 1))),
				int(payload.get("work_phase_count", 0))
			]
		"plan_revised":
			return "%s重新评估了当前计划：%s。" % [actor, str(payload.get("summary", payload.get("reason", "计划异常")))]
		"money_given":
			return "%s给了%s%d枚第纳尔。" % [PLAYER_DISPLAY_NAME, actor, int(payload.get("amount", 0))]
		"equipment_given":
			return "%s把%s交给了%s。" % [PLAYER_DISPLAY_NAME, str(payload.get("equipment_name", "装备")), actor]
		"equipment_changed":
			return "%s为%s更换了%s。" % [PLAYER_DISPLAY_NAME, actor, str(payload.get("equipment_name", "装备"))]
		"order_assigned":
			return "守备官制定了新的指令。"
		"npc_attacked_by_player":
			return "%s攻击了%s，造成%d点伤害。" % [PLAYER_DISPLAY_NAME, actor, int(payload.get("damage", 0))]
		"combat_alarm_rang":
			return "%s听到了警铃，守备官正在召集所有人。" % actor
		"combat_rally_started":
			return "%s作为%s前往%s集结，面向敌人来袭方向。" % [
				actor,
				str(payload.get("unit_type_label", payload.get("unit_type", "战斗人员"))),
				str(payload.get("rally_location_name", "城门外防线"))
			]
		"combat_rally_encountered_enemy":
			return "%s在集结途中遭遇%s，放弃集结并准备接敌。" % [
				actor,
				str(payload.get("enemy_name", payload.get("enemy_id", "敌人")))
			]
		"npc_mode_changed":
			return "%s从%s切换到%s，原因：%s。" % [
				actor,
				str(payload.get("from_mode_label", _format_behavior_mode_label(str(payload.get("from_mode", ""))))),
				str(payload.get("to_mode_label", _format_behavior_mode_label(str(payload.get("to_mode", ""))))),
				str(payload.get("reason", "mode_changed"))
			]
		"avoidance_started":
			return "%s发现%s接近，正在前往%s避战。" % [
				actor,
				str(payload.get("enemy_name", payload.get("enemy_id", "敌人"))),
				str(payload.get("target_name", "安全位置"))
			]
		"avoidance_ended":
			return "%s不再避战，回到驿站日常安排。" % actor
		"damage_taken":
			var damage_actor_ids := _normalize_string_array(event.get("actor_ids", []))
			var damage_actor_id := "" if damage_actor_ids.is_empty() else damage_actor_ids[0]
			return "%s受到%s造成的%d点伤害，HP 从%d降到%d。" % [
				actor,
				_get_actor_display_name(damage_actor_id),
				int(payload.get("damage", 0)),
				int(payload.get("hp_before", 0)),
				int(payload.get("hp_after", 0))
			]
		"unconscious_started":
			return "%s在%s昏迷了。" % [actor, location]
		"healing_started":
			return "%s开始在%s协助治疗%s。" % [
				_get_npc_display_name(str(payload.get("healer_npc_id", ""))),
				location,
				_get_npc_display_name(str(payload.get("target_npc_id", "")))
			]
		"healing_completed":
			return "%s结束了对%s的治疗，消耗%d枚第纳尔。" % [
				_get_npc_display_name(str(payload.get("healer_npc_id", ""))),
				_get_npc_display_name(str(payload.get("target_npc_id", ""))),
				int(payload.get("money_spent", 0))
			]
		"revived":
			return "%s在%s苏醒了。" % [actor, location]
		"sleep_started":
			return "%s开始在%s休息。" % [actor, location]
		"sleep_ended":
			return "%s在%s休息后恢复了些精神。" % [actor, location]
		_:
			return "%s发生了%s事件。" % [actor, event_type]


func _format_building_or_plaza_state_summary(payload: Dictionary) -> String:
	var building_snapshot: Dictionary = payload.get("building_snapshot", {})
	var building_name := str(payload.get("building_name", building_snapshot.get("name", "")))
	var changed_fields: Dictionary = payload.get("changed_fields", {})
	if not building_name.is_empty() and not changed_fields.is_empty():
		return _format_external_state_delta_sentence(building_name, changed_fields)
	if not building_name.is_empty():
		return _format_external_state_sentence(building_name, building_snapshot)
	return "广场公告变为：%s。" % str(payload.get("current_notice", ""))


func _format_location_entered_summary(actor: String, payload: Dictionary, event: Dictionary) -> String:
	var location_id := str(payload.get("to_location_id", event.get("location_id", DEFAULT_LOCATION_ID)))
	var location_name := _get_location_name(location_id)
	return "%s进入了%s。" % [actor, location_name]


func _format_skill_improved_summary(actor: String, payload: Dictionary, location: String) -> String:
	var skill_name := str(payload.get("skill_name", "熟练度"))
	var reason := str(payload.get("reason", ""))
	if reason == "clinic_study":
		return "%s在%s研读医学著作，%s略有长进。" % [actor, location, skill_name]
	if reason == "clinic_treatment":
		return "%s在%s治疗伤员，%s略有长进。" % [actor, location, skill_name]
	if reason == "training_solo":
		return "%s在%s独自练习，%s略有长进。" % [actor, location, skill_name]
	if reason == "training_student":
		return "%s在%s受训，%s略有长进。" % [actor, location, skill_name]
	if reason == "training_coaching":
		return "%s在%s指导训练，%s略有长进。" % [actor, location, skill_name]
	if reason == "work_completed":
		return "%s在%s工作后，%s略有长进。" % [actor, location, skill_name]
	return "%s的%s略有长进。" % [actor, skill_name]


func _format_behavior_mode_label(mode: String) -> String:
	match mode:
		"work":
			return "工作模式"
		"rally":
			return "集结模式"
		"combat":
			return "战斗模式"
		"avoid_combat":
			return "避战模式"
		"unconscious":
			return "昏迷"
		"escaped":
			return "逃离"
		_:
			return mode


func _format_location_state_summary(payload: Dictionary) -> String:
	var building_snapshot: Dictionary = payload.get("building_snapshot", {})
	var external_state: Dictionary = building_snapshot.get("external_state", building_snapshot)
	var internal_state: Dictionary = building_snapshot.get("internal_state", {})
	var building_name := str(payload.get("building_name", external_state.get("name", "该建筑")))
	var reason := str(payload.get("reason", ""))
	if reason == "location_entry_snapshot":
		return _format_location_entry_snapshot_summary(payload)
	if reason == "building_external_state_changed" and payload.has("changed_fields"):
		return _format_external_state_delta_sentence(building_name, payload.get("changed_fields", {}))
	if reason == "building_internal_state_changed" and payload.has("changed_workstations"):
		return "%s里的工位状态：%s。" % [building_name, _format_workstation_states(payload.get("changed_workstations", []))]
	if reason == "npc_entered_location":
		return "%s %s内现在有%s。%s %s里的工位状态：%s。" % [
			_format_external_state_sentence(building_name, external_state),
			building_name,
			_format_people_present(internal_state.get("people_present", [])),
			_format_people_statuses(internal_state.get("people_statuses", [])),
			building_name,
			_format_workstation_states(internal_state.get("workstations", []))
		]
	if reason == "npc_left_location":
		return "%s内现在有%s。" % [building_name, _format_people_present(internal_state.get("people_present", []))]
	if reason == "building_internal_state_changed":
		return "%s里的工位状态：%s。" % [building_name, _format_workstation_states(internal_state.get("workstations", []))]
	if reason == "building_external_state_changed":
		return _format_external_state_sentence(building_name, external_state)
	return _format_external_state_sentence(building_name, external_state)


func _format_location_entry_snapshot_summary(payload: Dictionary) -> String:
	var snapshot: Dictionary = payload.get("location_snapshot", {})
	var location_name := str(snapshot.get("name", payload.get("building_name", "")))
	if location_name.is_empty():
		location_name = _get_location_name(str(payload.get("building_id", DEFAULT_LOCATION_ID)))

	var building_snapshot: Dictionary = snapshot.get("building", {})
	if building_snapshot.is_empty():
		var external_states: Dictionary = snapshot.get("building_external_states", {})
		var plaza_parts: Array[String] = []
		plaza_parts.append("%s现在有%s。" % [location_name, _format_people_present(snapshot.get("people_present", []))])
		plaza_parts.append(_format_people_statuses(snapshot.get("people_statuses", [])))
		var current_notice := str(snapshot.get("current_notice", ""))
		if current_notice.is_empty():
			plaza_parts.append("公告牌目前没有公告。")
		else:
			plaza_parts.append("公告牌写着：%s。" % current_notice)
		for building_id in external_states.keys():
			var external_state: Dictionary = external_states[building_id]
			plaza_parts.append(_format_external_state_sentence(str(external_state.get("name", building_id)), external_state))
		if external_states.is_empty():
			plaza_parts.append("%s当前没有可传播的建筑状态。" % location_name)
		if plaza_parts.is_empty():
			return "%s当前没有可传播的建筑状态。" % location_name
		return "%s当前状态：%s" % [location_name, " ".join(plaza_parts)]

	var external_state: Dictionary = building_snapshot.get("external_state", building_snapshot)
	var internal_state: Dictionary = building_snapshot.get("internal_state", {})
	var parts: Array[String] = [
		_format_external_state_sentence(location_name, external_state),
		"%s内现在有%s。" % [location_name, _format_people_present(internal_state.get("people_present", []))],
		_format_people_statuses(internal_state.get("people_statuses", [])),
		"%s里的工位状态：%s。" % [location_name, _format_workstation_states(internal_state.get("workstations", []))]
	]
	return " ".join(parts)


func _format_external_state_delta_sentence(building_name: String, changed_fields: Dictionary) -> String:
	if changed_fields.is_empty():
		return "%s状态未变。" % building_name
	if changed_fields.has("condition"):
		return "%s%s。" % [building_name, _format_building_condition(str(changed_fields.get("condition", "unknown")))]
	if changed_fields.has("level"):
		return "%s等级变为%d级。" % [building_name, int(changed_fields.get("level", 1))]
	return "%s状态发生变化。" % building_name


func _format_external_state_sentence(building_name: String, external_state: Dictionary) -> String:
	var level := int(external_state.get("level", 1))
	var condition := str(external_state.get("condition", "unknown"))
	if condition == "intact" and level > 1:
		return "%s等级变为%d级。" % [building_name, level]
	return "%s%s。" % [building_name, _format_building_condition(condition)]


func _format_people_present(raw_people: Variant) -> String:
	var people := _normalize_string_array(raw_people)
	if people.is_empty():
		return "没有人"
	var names: Array[String] = []
	for npc_id in people:
		names.append(_get_npc_display_name(npc_id))
	return "、".join(names)


func _format_people_statuses(raw_statuses: Variant) -> String:
	if not raw_statuses is Array or (raw_statuses as Array).is_empty():
		return "在场人员状态：无。"
	var parts: Array[String] = []
	for raw_status in raw_statuses:
		if not raw_status is Dictionary:
			continue
		var status: Dictionary = raw_status
		var name := str(status.get("name", _get_npc_display_name(str(status.get("npc_id", "")))))
		var life_status_text := str(status.get("life_status_text", "状态未知"))
		var action_status := str(status.get("action_status", "待命"))
		parts.append("%s%s，行动：%s" % [name, life_status_text, action_status])
	if parts.is_empty():
		return "在场人员状态：无。"
	return "在场人员状态：%s。" % "；".join(parts)


func _format_workstation_states(raw_workstations: Variant) -> String:
	if not raw_workstations is Array or (raw_workstations as Array).is_empty():
		return "没有工位"
	var parts: Array[String] = []
	for raw_workstation in raw_workstations:
		if not raw_workstation is Dictionary:
			continue
		var workstation: Dictionary = raw_workstation
		var station_name := str(workstation.get("id", workstation.get("type", "工位")))
		var occupied_by := str(workstation.get("occupied_by", ""))
		if occupied_by.is_empty() or occupied_by == "<null>":
			parts.append("%s空闲" % station_name)
		else:
			parts.append("%s被%s占用" % [station_name, _get_npc_display_name(occupied_by)])
	if parts.is_empty():
		return "没有工位"
	return "，".join(parts)


func _format_building_condition(condition: String) -> String:
	match condition:
		"intact":
			return "完好"
		"damaged":
			return "受损"
		"repairing":
			return "正在修复"
		"upgrading":
			return "正在升级"
		_:
			return "状态未知"


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
	if ["damage_taken", "unconscious_started", "healing_started", "healing_completed"].has(event_type) and payload.has("target_npc_id"):
		target_ids.append(str(payload["target_npc_id"]))
	if ["healing_started", "healing_completed"].has(event_type) and payload.has("healer_npc_id"):
		target_ids.append(str(payload["healer_npc_id"]))
	return target_ids


func _get_experiencing_npc_ids(event: Dictionary) -> Array[String]:
	var npc_ids: Array[String] = []
	var subject_npc_id := str(event.get("subject_npc_id", ""))
	if not subject_npc_id.is_empty() and subject_npc_id != PLAYER_ACTOR_ID:
		npc_ids.append(subject_npc_id)
	if str(event.get("type", "")) != "dialogue_turn":
		return npc_ids
	var payload: Dictionary = event.get("payload", {})
	for participant_id in _normalize_string_array(payload.get("participant_npc_ids", [])):
		if participant_id != PLAYER_ACTOR_ID and not npc_ids.has(participant_id):
			npc_ids.append(participant_id)
	return npc_ids


func _get_npc_current_info_location(npc_id: String) -> String:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return DEFAULT_LOCATION_ID
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var location_id := _normalize_location_id(str(state.get("current_location", DEFAULT_LOCATION_ID)))
	if not is_enterable_location(location_id):
		return DEFAULT_LOCATION_ID
	return location_id


func _can_npc_receive_witness(npc_id: String) -> bool:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return true
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	if bool(state.get("unconscious", false)):
		return false
	return str(state.get("current_action", "")) != "sleep_in_dormitory"


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
	if npc_id == PLAZA_STATE_SUBJECT_ID:
		return "系统"
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return npc_id
	var npc: Dictionary = npc_system.get_npc(npc_id)
	return str(npc.get("name", npc_id))


func _get_actor_display_name(actor_id: String) -> String:
	if actor_id == PLAYER_ACTOR_ID:
		return PLAYER_DISPLAY_NAME
	if actor_id.begins_with("wave_") or actor_id.begins_with("enemy_"):
		return "敌人"
	return _get_npc_display_name(actor_id)


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
