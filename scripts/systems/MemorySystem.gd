extends Node

const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const BUILDING_SYSTEM_PATH := "/root/Main/Systems/BuildingSystem"
const RESOURCE_SYSTEM_PATH := "/root/Main/Systems/ResourceSystem"
const ACTION_SYSTEM_PATH := "/root/Main/Systems/ActionSystem"
const NOTICE_BOARD_DEFAULTS_FILE := "notice_board_defaults.json"
const DEFAULT_LOCATION_ID := "plaza"
const DEFAULT_VISIBILITY := "private"
const LOCAL_PUBLIC_VISIBILITY := "local_public"
const STATION_WIDE_PUBLIC_EVENT_TYPES: Array[String] = [
	"plaza_notice_changed", "plaza_schedule_changed",
	"piety_meteor_impact", "piety_meteor_enemy_defeated"
]
const PLAYER_ACTOR_ID := "guard_officer"
const PLAYER_DISPLAY_NAME := "守备官"
const ENTERABLE_LOCATION_IDS: Array[String] = [
	"plaza", "dormitory", "dining_hall", "tavern", "garden", "blacksmith",
	"training_ground", "stable", "chapel", "clinic", "workshop"
]
const PLAZA_STATE_SUBJECT_ID := "system"
const PRODUCTION_SPECIAL_FIELDS: Array[String] = [
	"target_item_id", "target_name", "completed_stages", "total_stages",
	"current_stage_index", "current_stage_name"
]
const HORSE_COUNT_SPECIAL_FIELDS: Array[String] = ["total", "adult", "foal"]
const DEVELOPMENT_ONLY_EVENT_TYPES: Array[String] = ["npc_mode_changed"]

const EVENT_TYPES: Array[String] = [
	"wake_up", "plan_created", "plan_revised", "reflection_started", "sleep_started", "sleep_ended",
	"location_entered", "location_exited",
	"work_started", "work_completed", "work_failed", "repair_assist_started", "upgrade_assist_started", "eat_started", "eat_completed", "wine_consumed",
	"prayer_started", "prayer_joined_mass", "prayer_resumed_alone", "prayer_completed", "prayer_failed", "visit_started", "visit_completed",
	"dialogue_turn", "dialogue_special_interaction_result", "proactive_talk_started", "proactive_talk_message",
	"money_given", "wine_given", "equipment_given", "equipment_changed", "order_assigned", "npc_attacked_by_player",
	"skill_improved", "attribute_improved", "npc_recruited", "npc_left_recruited_state", "work_encouragement_result", "work_encouragement_boost_started", "work_encouragement_boost_ended",
	"combat_started", "combat_ended", "combat_alarm_rang", "combat_rally_started", "combat_rally_encountered_enemy", "battle_psychology_result", "morale_boost_started", "morale_boost_ended", "attack_made", "damage_taken", "horse_born", "horse_damaged", "horse_died", "low_hp_triggered",
	"combat_strategy_selected",
	"avoidance_started", "avoidance_ended", "unconscious_started", "healing_started", "healing_completed", "healing_failed", "revived", "escape_started", "escaped", "escape_intervention_result", "escape_speed_changed",
	"building_damaged", "building_repaired", "building_upgraded", "resource_changed",
	"plaza_notice_changed", "plaza_schedule_changed", "plaza_status_changed", "location_status_changed",
	"merchant_arrived", "merchant_departed", "merchant_trade_completed",
	"defense_device_deployed", "defense_device_triggered",
	"piety_meteor_cast", "piety_meteor_impact", "piety_meteor_enemy_defeated"
]

const REQUIRED_PAYLOAD_FIELDS := {
	"wake_up": ["day", "hour", "reason"],
	"dialogue_turn": ["dialogue_id", "participant_npc_ids", "dialogue_text", "speaker_name", "listener_name", "visibility", "current_round", "max_rounds"],
	"dialogue_special_interaction_result": ["dialogue_id", "participant_npc_ids", "special_type", "outcome", "success", "npc_id", "npc_name", "visibility", "current_round"],
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
	"wine_consumed": ["action_id", "resource_id", "amount", "npc_wine_before", "npc_wine_after", "context_effect"],
	"wine_given": ["amount", "resource_id", "npc_wine_before", "npc_wine_after"],
	"prayer_started": ["action_id", "workstation_id", "duration_seconds"],
	"prayer_joined_mass": ["action_id", "leader_npc_id", "trigger", "from_mode", "to_mode"],
	"prayer_resumed_alone": ["action_id", "leader_npc_id", "trigger", "from_mode", "to_mode"],
	"prayer_completed": ["action_id", "workstation_id", "duration_seconds"],
	"prayer_failed": ["action_id", "reason"],
	"visit_started": ["action_id", "location_id", "duration_seconds"],
	"visit_completed": ["action_id", "location_id", "duration_seconds"],
	"combat_alarm_rang": ["source", "npc_count", "active_enemy_count"],
	"combat_started": ["wave_number", "enemy_count", "enemy_roster", "friendly_combatant_count", "friendly_roster"],
	"combat_ended": ["wave_number", "enemy_count", "injured_npcs", "unconscious_npcs", "defeated_by_npc", "reason"],
	"combat_rally_started": ["formation_row", "unit_type", "rally_location_id", "facing_direction"],
	"combat_rally_encountered_enemy": ["enemy_id", "distance"],
	"battle_psychology_result": ["trigger", "decision", "battlefield_context_summary"],
	"low_hp_triggered": ["hp_before", "hp_after", "max_hp"],
	"morale_boost_started": ["source_event_id", "trigger", "duration_seconds", "attack_bonus", "move_speed_bonus"],
	"morale_boost_ended": ["source_event_id", "duration_seconds"],
	"work_encouragement_result": ["decision", "dialogue_id"],
	"work_encouragement_boost_started": ["source_event_id", "duration_seconds", "output_bonus", "output_multiplier"],
	"work_encouragement_boost_ended": ["source_event_id", "duration_seconds"],
	"avoidance_started": ["enemy_id", "distance", "reason", "target_id"],
	"avoidance_ended": ["reason", "active_enemy_count"],
	"attack_made": ["attacker_npc_id", "target_type", "target_enemy_id", "damage", "hp_before", "hp_after"],
	"combat_strategy_selected": ["npc_id", "strategy_id", "strategy_label", "unit_type"],
	"damage_taken": ["damage", "hp_before", "hp_after"],
	"horse_damaged": ["target_npc_id", "horse_id", "horse_name", "damage", "hp_before", "hp_after", "share_ratio"],
	"horse_died": ["target_npc_id", "horse_id", "horse_name", "damage", "hp_before", "hp_after", "share_ratio"],
	"horse_born": ["horse_id", "horse_name", "template_id", "stable_slot_id", "named_by"],
	"unconscious_started": ["damage", "hp_before", "hp_after"],
	"healing_started": ["healer_npc_id", "target_npc_id", "money_spent"],
	"healing_completed": ["healer_npc_id", "target_npc_id", "money_spent"],
	"healing_failed": ["healer_npc_id", "target_npc_id", "money_spent", "reason"],
	"revived": ["hp_before", "hp_after", "recovery_source"],
	"escape_started": ["npc_id", "exit_target_id", "exit_target_name", "trigger"],
	"escaped": ["npc_id", "exit_target_id", "exit_target_name", "reason"],
	"escape_intervention_result": ["npc_id", "decision", "current_round", "max_rounds"],
	"escape_speed_changed": ["npc_id", "trigger", "speed_multiplier_before", "speed_multiplier_after"],
	"order_assigned": ["previous_order_text", "new_order_text", "order_revision"],
	"attribute_improved": ["attribute", "attribute_label", "before", "after", "training_kind"],
	"plaza_schedule_changed": ["reference_schedule", "schedule_advisory_note"],
	"merchant_arrived": ["merchant_id", "merchant_name", "arrival_time", "departure_time", "visit_day"],
	"merchant_departed": ["merchant_id", "merchant_name", "arrival_time", "departure_time", "visit_day"],
	"merchant_trade_completed": ["merchant_id", "direction", "resource_id", "amount", "unit_price", "total_price", "money_delta", "resource_delta"],
	"defense_device_deployed": ["deployment_id", "device_id", "device_name", "slot_id", "slot_name", "inventory_resource_id", "inventory_cost"],
	"defense_device_triggered": ["deployment_id", "device_id", "device_name", "target_enemy_id", "damage", "hp_before", "hp_after"],
	"piety_meteor_cast": ["cast_id", "target_position", "radius", "piety_spent"],
	"piety_meteor_impact": ["cast_id", "target_position", "radius", "impact_damage", "impact_max_targets", "enemy_hit_count", "enemy_defeated_count", "burn_duration_seconds", "friendly_fire"],
	"piety_meteor_enemy_defeated": ["cast_id", "enemy_defeated_count"]
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
var _last_location_special_states: Dictionary = {}
var _event_counter := 0
var _notice_board_defaults: Dictionary = {}
var _initial_notice_board_seeded := false


func initialize() -> void:
	_events_by_id.clear()
	_global_event_ids.clear()
	_npc_daily_event_ids.clear()
	_npc_daily_witness_ids.clear()
	_plaza_event_ids.clear()
	_load_notice_board_defaults()
	_initialize_location_info_nodes()
	_apply_notice_board_defaults_to_plaza_node()
	_last_location_state_keys.clear()
	_last_plaza_external_state_keys.clear()
	_last_plaza_external_states.clear()
	_last_location_external_states.clear()
	_last_location_workstation_states.clear()
	_last_location_special_states.clear()
	_seed_special_state_caches()
	_event_counter = 0
	_initial_notice_board_seeded = false
	_sync_initial_people_present()
	_seed_initial_notice_board_witnesses()


func _ready() -> void:
	initialize()
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and not event_bus.building_state_changed.is_connected(_on_building_state_changed):
		event_bus.building_state_changed.connect(_on_building_state_changed)


func add_event(event: Dictionary) -> Dictionary:
	if event.is_empty():
		return {}
	if DEVELOPMENT_ONLY_EVENT_TYPES.has(str(event.get("type", ""))):
		# 模式切换和内部 reason 只供运行时状态 / GM 快照诊断，禁止进入事件、见闻与 LLM 记忆。
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


func remove_npc_from_all_locations(npc_id: String) -> bool:
	if npc_id.is_empty():
		return false
	var removed_from: Array[String] = []
	for raw_location_id in _location_info_nodes.keys():
		var location_id := str(raw_location_id)
		var node: Dictionary = _location_info_nodes.get(location_id, {})
		var people := _normalize_string_array(node.get("people_present", []))
		if not people.has(npc_id):
			continue
		_remove_person_from_location(location_id, npc_id, false)
		removed_from.append(location_id)
	for location_id in removed_from:
		_emit_location_info_changed(location_id)
	return not removed_from.is_empty()


func restore_npc_location_membership_silent(npc_id: String, location_id: String) -> Dictionary:
	# Save restoration reconstructs current presence, not a new witnessed arrival.
	# Keep this separate from move_npc_between_locations so loading cannot append
	# duplicate entry snapshots to an NPC's witness log.
	if npc_id.is_empty():
		return {"ok": false, "reason": "npc_id_missing"}
	var normalized_location := _normalize_location_id(location_id)
	if not is_enterable_location(normalized_location):
		normalized_location = DEFAULT_LOCATION_ID
	for raw_location_id in _location_info_nodes.keys():
		_remove_person_from_location(str(raw_location_id), npc_id, false)
	_add_person_to_location(normalized_location, npc_id)
	for raw_location_id in _location_info_nodes.keys():
		_emit_location_info_changed(str(raw_location_id))
	return {
		"ok": true,
		"npc_id": npc_id,
		"location_id": normalized_location,
		"witness_event_created": false
	}


func _record_location_entry_snapshot_witness(npc_id: String, location_id: String, snapshot: Dictionary) -> void:
	if npc_id.is_empty() or snapshot.is_empty():
		return

	var normalized_location_id := _normalize_location_id(location_id)
	if not is_enterable_location(normalized_location_id):
		normalized_location_id = DEFAULT_LOCATION_ID
	var witness_snapshot := snapshot.duplicate(true)
	if normalized_location_id == DEFAULT_LOCATION_ID:
		# 公告牌两页改为发布时全站广播；入场快照不再重复写入同一内容。
		witness_snapshot.erase("current_notice")
		witness_snapshot.erase("reference_schedule")
		witness_snapshot.erase("schedule_advisory_note")

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
			"location_snapshot": witness_snapshot,
			"building_id": normalized_location_id,
			"building_name": _get_location_name(normalized_location_id),
			"building_snapshot": witness_snapshot.get("building", {})
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
		"reference_schedule": _duplicate_schedule(node.get("reference_schedule", [])),
		"schedule_advisory_note": str(node.get("schedule_advisory_note", "")),
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
	snapshot["special_state"] = internal_state.get("special_state", building_snapshot.get("special_state", {}))
	if not building_snapshot.is_empty():
		var external_state: Dictionary = snapshot.get("external_state", {})
		snapshot["is_enterable"] = bool(external_state.get("is_enterable", true))
		snapshot["operational_efficiency"] = float(external_state.get("operational_efficiency", 1.0))
	else:
		snapshot["operational_efficiency"] = 1.0
	return snapshot.duplicate(true)


func get_location_people_present(location_id: String) -> Array[String]:
	var snapshot := get_location_snapshot(location_id)
	return _normalize_string_array(snapshot.get("people_present", []))


func is_enterable_location(location_id: String) -> bool:
	return ENTERABLE_LOCATION_IDS.has(_normalize_location_id(location_id))


func set_plaza_notice(text: String, actor_id: String = PLAZA_STATE_SUBJECT_ID) -> Dictionary:
	_ensure_location_info_node(DEFAULT_LOCATION_ID)
	var node: Dictionary = _location_info_nodes[DEFAULT_LOCATION_ID]
	var normalized_text := text.strip_edges()
	if str(node.get("current_notice", "")) == normalized_text:
		return {}
	node["current_notice"] = normalized_text
	_location_info_nodes[DEFAULT_LOCATION_ID] = node
	return _broadcast_plaza_state_changed("notice_changed", {"notice": normalized_text}, actor_id, "plaza_notice_changed")


func set_plaza_reference_schedule(entries: Array, actor_id: String = PLAZA_STATE_SUBJECT_ID) -> Dictionary:
	var validation := _normalize_reference_schedule(entries)
	if not bool(validation.get("ok", false)):
		return validation

	_ensure_location_info_node(DEFAULT_LOCATION_ID)
	var normalized_schedule: Array[Dictionary] = validation.get("schedule", [])
	var node: Dictionary = _location_info_nodes[DEFAULT_LOCATION_ID]
	var current_schedule := _duplicate_schedule(node.get("reference_schedule", []))
	if JSON.stringify(current_schedule) == JSON.stringify(normalized_schedule):
		return {
			"ok": true,
			"changed": false,
			"status": "unchanged",
			"schedule": current_schedule
		}

	node["reference_schedule"] = normalized_schedule.duplicate(true)
	_location_info_nodes[DEFAULT_LOCATION_ID] = node
	var advisory_note := str(node.get("schedule_advisory_note", ""))
	var event := _broadcast_plaza_state_changed(
		"reference_schedule_changed",
		{
			"reference_schedule": normalized_schedule.duplicate(true),
			"schedule_advisory_note": advisory_note
		},
		actor_id,
		"plaza_schedule_changed"
	)
	return {
		"ok": not event.is_empty(),
		"changed": not event.is_empty(),
		"status": "published" if not event.is_empty() else "event_failed",
		"schedule": normalized_schedule.duplicate(true),
		"event": event.duplicate(true)
	}


func get_plaza_reference_schedule() -> Array[Dictionary]:
	_ensure_location_info_node(DEFAULT_LOCATION_ID)
	var node: Dictionary = _location_info_nodes[DEFAULT_LOCATION_ID]
	return _duplicate_schedule(node.get("reference_schedule", []))


func get_notice_board_state() -> Dictionary:
	var plaza := get_location_snapshot(DEFAULT_LOCATION_ID)
	return {
		"current_notice": str(plaza.get("current_notice", "")),
		"reference_schedule": _duplicate_schedule(plaza.get("reference_schedule", [])),
		"schedule_advisory_note": str(plaza.get("schedule_advisory_note", ""))
	}


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


func debug_set_plaza_notice(text: String) -> Dictionary:
	return set_plaza_notice(text)


func debug_set_plaza_reference_schedule(entries: Array) -> Dictionary:
	return set_plaza_reference_schedule(entries)


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
	var snapshot := get_npc_short_term_memory_snapshot(npc_id)
	return {
		"npc_id": npc_id,
		"event_log": snapshot.get("event_log", []),
		"witness_log": snapshot.get("witness_log", []),
		"event_count": int(snapshot.get("event_count", 0)),
		"witness_count": int(snapshot.get("witness_count", 0))
	}


func get_npc_short_term_memory_snapshot(npc_id: String) -> Dictionary:
	var event_ids := get_npc_daily_event_ids(npc_id)
	var witness_ids := get_npc_daily_witness_ids(npc_id)
	return {
		"npc_id": npc_id,
		"event_ids": event_ids,
		"witness_ids": witness_ids,
		"event_log": _events_from_ids(event_ids),
		"witness_log": _events_from_ids(witness_ids),
		"event_count": event_ids.size(),
		"witness_count": witness_ids.size()
	}


func get_npc_short_term_memory_ids(npc_id: String) -> Dictionary:
	return {
		"npc_id": npc_id,
		"event_log": get_npc_daily_event_ids(npc_id),
		"witness_log": get_npc_daily_witness_ids(npc_id)
	}


func clear_npc_short_term_memory_snapshot(
	npc_id: String,
	snapshot: Dictionary
) -> Dictionary:
	if npc_id.is_empty():
		return {
			"ok": false,
			"reason": "empty_npc_id",
			"message": "NPC ID 为空。"
		}
	var snapshot_event_ids: Array = (
		snapshot.get("event_ids", [])
		if snapshot.get("event_ids", []) is Array
		else []
	)
	var snapshot_witness_ids: Array = (
		snapshot.get("witness_ids", [])
		if snapshot.get("witness_ids", []) is Array
		else []
	)
	var current_event_ids := get_npc_daily_event_ids(npc_id)
	var current_witness_ids := get_npc_daily_witness_ids(npc_id)
	var remaining_event_ids := _without_snapshot_ids(
		current_event_ids,
		snapshot_event_ids
	)
	var remaining_witness_ids := _without_snapshot_ids(
		current_witness_ids,
		snapshot_witness_ids
	)
	var cleared_event_count := current_event_ids.size() - remaining_event_ids.size()
	var cleared_witness_count := current_witness_ids.size() - remaining_witness_ids.size()
	if remaining_event_ids.is_empty():
		_npc_daily_event_ids.erase(npc_id)
	else:
		_npc_daily_event_ids[npc_id] = remaining_event_ids
	if remaining_witness_ids.is_empty():
		_npc_daily_witness_ids.erase(npc_id)
	else:
		_npc_daily_witness_ids[npc_id] = remaining_witness_ids
	if cleared_event_count > 0 or cleared_witness_count > 0:
		_emit_npc_memory_changed(npc_id)
	return {
		"ok": true,
		"npc_id": npc_id,
		"snapshot_event_count": snapshot_event_ids.size(),
		"snapshot_witness_count": snapshot_witness_ids.size(),
		"cleared_event_count": cleared_event_count,
		"cleared_witness_count": cleared_witness_count,
		"remaining_event_count": remaining_event_ids.size(),
		"remaining_witness_count": remaining_witness_ids.size(),
		"remaining_event_ids": remaining_event_ids.duplicate(),
		"remaining_witness_ids": remaining_witness_ids.duplicate()
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


func _load_notice_board_defaults() -> void:
	_notice_board_defaults = {}
	var config_loader := get_node_or_null("/root/ConfigLoader")
	if config_loader == null or not config_loader.has_method("load_data_file"):
		push_error("MemorySystem requires ConfigLoader to load notice board defaults.")
		return
	var loaded: Variant = config_loader.load_data_file(NOTICE_BOARD_DEFAULTS_FILE, {})
	if not loaded is Dictionary:
		push_error("Notice board defaults must be a JSON object: %s" % NOTICE_BOARD_DEFAULTS_FILE)
		return
	_notice_board_defaults = (loaded as Dictionary).duplicate(true)


func _apply_notice_board_defaults_to_plaza_node() -> void:
	_ensure_location_info_node(DEFAULT_LOCATION_ID)
	var validation := _normalize_reference_schedule(_notice_board_defaults.get("initial_schedule", []))
	var initial_schedule: Array[Dictionary] = []
	if bool(validation.get("ok", false)):
		initial_schedule = _duplicate_schedule(validation.get("schedule", []))
	else:
		push_error("Notice board initial schedule is invalid: %s" % str(validation.get("message", "unknown error")))
	var node: Dictionary = _location_info_nodes[DEFAULT_LOCATION_ID]
	node["current_notice"] = str(_notice_board_defaults.get("initial_notice", "")).strip_edges()
	node["reference_schedule"] = initial_schedule.duplicate(true)
	node["schedule_advisory_note"] = str(_notice_board_defaults.get("schedule_advisory_note", "")).strip_edges()
	_location_info_nodes[DEFAULT_LOCATION_ID] = node


func _seed_initial_notice_board_witnesses() -> void:
	if _initial_notice_board_seeded:
		return
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_ids"):
		return
	_initial_notice_board_seeded = true
	var board_state := get_notice_board_state()
	var event_ids: Array[String] = []
	var current_notice := str(board_state.get("current_notice", ""))
	if not current_notice.is_empty():
		var notice_event := add_event({
			"type": "plaza_notice_changed",
			"subject_npc_id": PLAZA_STATE_SUBJECT_ID,
			"actor_ids": [PLAZA_STATE_SUBJECT_ID],
			"target_ids": [DEFAULT_LOCATION_ID],
			"location_id": DEFAULT_LOCATION_ID,
			"visibility": LOCAL_PUBLIC_VISIBILITY,
			"importance": 55,
			"payload": {
				"reason": "initial_notice_board_state",
				"notice": current_notice,
				"current_notice": current_notice
			}
		})
		if not notice_event.is_empty():
			event_ids.append(str(notice_event.get("event_id", "")))

	var reference_schedule := _duplicate_schedule(board_state.get("reference_schedule", []))
	if not reference_schedule.is_empty():
		var schedule_event := add_event({
			"type": "plaza_schedule_changed",
			"subject_npc_id": PLAZA_STATE_SUBJECT_ID,
			"actor_ids": [PLAZA_STATE_SUBJECT_ID],
			"target_ids": [DEFAULT_LOCATION_ID],
			"location_id": DEFAULT_LOCATION_ID,
			"visibility": LOCAL_PUBLIC_VISIBILITY,
			"importance": 55,
			"payload": {
				"reason": "initial_notice_board_state",
				"reference_schedule": reference_schedule.duplicate(true),
				"schedule_advisory_note": str(board_state.get("schedule_advisory_note", ""))
			}
		})
		if not schedule_event.is_empty():
			event_ids.append(str(schedule_event.get("event_id", "")))

	for npc_id in npc_system.get_npc_ids():
		var state: Dictionary = npc_system.get_npc_state(str(npc_id))
		if bool(state.get("escaped", false)) or str(state.get("current_location", "")) == "outside_station":
			continue
		for event_id in event_ids:
			_add_initial_witness_event(str(npc_id), event_id)


func _add_initial_witness_event(npc_id: String, event_id: String) -> void:
	if npc_id.is_empty() or event_id.is_empty() or not _events_by_id.has(event_id):
		return
	if not _npc_daily_witness_ids.has(npc_id):
		_npc_daily_witness_ids[npc_id] = []
	if _npc_daily_witness_ids[npc_id].has(event_id):
		return
	_npc_daily_witness_ids[npc_id].append(event_id)
	_emit_npc_memory_changed(npc_id)


func _seed_special_state_caches() -> void:
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null or not building_system.has_method("get_building"):
		return
	for building_id in ENTERABLE_LOCATION_IDS:
		if building_id == DEFAULT_LOCATION_ID:
			continue
		var building: Dictionary = building_system.get_building(building_id)
		if building.is_empty():
			continue
		var external_state := _get_building_external_state_snapshot(building_id)
		_last_plaza_external_states[building_id] = external_state.duplicate(true)
		_last_plaza_external_state_keys[building_id] = JSON.stringify(external_state)
		_last_location_external_states[building_id] = external_state.duplicate(true)
		_last_location_state_keys["%s:external" % building_id] = JSON.stringify(external_state)
		var normalized_workstations := _normalize_workstations_for_info(building.get("workstations", []))
		var workstation_states := _workstation_state_by_id(normalized_workstations)
		_last_location_workstation_states[building_id] = workstation_states.duplicate(true)
		_last_location_state_keys["%s:internal" % building_id] = JSON.stringify(workstation_states)
		var special_state := _normalize_special_state_for_info(building_id, building.get("special_state", {}))
		_last_location_special_states[building_id] = special_state.duplicate(true)
		_last_location_state_keys["%s:special" % building_id] = JSON.stringify(special_state)


func _ensure_location_info_node(location_id: String) -> void:
	var normalized_location_id := _normalize_location_id(location_id)
	if _location_info_nodes.has(normalized_location_id):
		return
	_location_info_nodes[normalized_location_id] = {
		"id": normalized_location_id,
		"name": _get_location_name(normalized_location_id),
		"people_present": [],
		"current_notice": "",
		"reference_schedule": [],
		"schedule_advisory_note": "",
		"current_orders": ""
	}


func _sync_initial_people_present() -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_ids"):
		return

	for npc_id in npc_system.get_npc_ids():
		var npc_state: Dictionary = npc_system.get_npc_state(str(npc_id))
		if (
			bool(npc_state.get("escaped", false))
			or str(npc_state.get("behavior_mode", "")) == "escaped"
			or str(npc_state.get("current_location", "")) == "outside_station"
		):
			continue
		var location_id := _normalize_location_id(str(npc_state.get("current_location", DEFAULT_LOCATION_ID)))
		if not is_enterable_location(location_id):
			location_id = DEFAULT_LOCATION_ID
		_add_person_to_location(location_id, str(npc_id))


func _normalize_location_id(location_id: String) -> String:
	if location_id.is_empty():
		return DEFAULT_LOCATION_ID
	return location_id


func _normalize_reference_schedule(entries: Array) -> Dictionary:
	var normalized: Array[Dictionary] = []
	var used_ids: Array[String] = []
	for index in range(entries.size()):
		var raw_entry: Variant = entries[index]
		if not raw_entry is Dictionary:
			return _schedule_validation_failure("invalid_entry", "第%d条日程不是有效记录。" % (index + 1), index)
		var entry: Dictionary = raw_entry
		var entry_id := str(entry.get("id", "")).strip_edges()
		if entry_id.is_empty():
			entry_id = "schedule_%02d" % (index + 1)
		if used_ids.has(entry_id):
			return _schedule_validation_failure("duplicate_id", "日程编号重复：%s。" % entry_id, index)
		used_ids.append(entry_id)

		var start_time := str(entry.get("start_time", "")).strip_edges()
		var end_time := str(entry.get("end_time", "")).strip_edges()
		var start_minutes := _parse_schedule_time(start_time, false)
		var end_minutes := _parse_schedule_time(end_time, true)
		if start_minutes < 0:
			return _schedule_validation_failure("invalid_start_time", "第%d条日程的开始时间无效。" % (index + 1), index)
		if end_minutes < 0:
			return _schedule_validation_failure("invalid_end_time", "第%d条日程的结束时间无效。" % (index + 1), index)
		if end_minutes <= start_minutes:
			return _schedule_validation_failure("invalid_time_range", "第%d条日程的结束时间必须晚于开始时间。" % (index + 1), index)
		var content := str(entry.get("content", "")).strip_edges()
		if content.is_empty():
			return _schedule_validation_failure("empty_content", "第%d条日程还没有填写内容。" % (index + 1), index)
		normalized.append({
			"id": entry_id,
			"start_time": _format_schedule_time(start_minutes),
			"end_time": _format_schedule_time(end_minutes),
			"content": content,
			"_start_minutes": start_minutes,
			"_end_minutes": end_minutes
		})

	normalized.sort_custom(_sort_reference_schedule_entries)
	for index in range(1, normalized.size()):
		var previous: Dictionary = normalized[index - 1]
		var current: Dictionary = normalized[index]
		if int(current.get("_start_minutes", 0)) < int(previous.get("_end_minutes", 0)):
			return _schedule_validation_failure(
				"overlapping_entries",
				"“%s”和“%s”的时间发生重叠。" % [str(previous.get("content", "")), str(current.get("content", ""))],
				index
			)
	for entry in normalized:
		entry.erase("_start_minutes")
		entry.erase("_end_minutes")
	return {
		"ok": true,
		"changed": false,
		"status": "valid",
		"schedule": normalized.duplicate(true)
	}


func _schedule_validation_failure(error_code: String, message: String, entry_index: int) -> Dictionary:
	return {
		"ok": false,
		"changed": false,
		"status": "invalid_schedule",
		"error_code": error_code,
		"entry_index": entry_index,
		"message": message,
		"schedule": []
	}


func _sort_reference_schedule_entries(left: Dictionary, right: Dictionary) -> bool:
	var left_start := int(left.get("_start_minutes", 0))
	var right_start := int(right.get("_start_minutes", 0))
	if left_start == right_start:
		return int(left.get("_end_minutes", 0)) < int(right.get("_end_minutes", 0))
	return left_start < right_start


func _parse_schedule_time(value: String, allow_end_of_day: bool) -> int:
	var parts := value.split(":", false)
	if parts.size() != 2 or not str(parts[0]).is_valid_int() or not str(parts[1]).is_valid_int():
		return -1
	var hour := int(parts[0])
	var minute := int(parts[1])
	if allow_end_of_day and hour == 24 and minute == 0:
		return 24 * 60
	if hour < 0 or hour > 23 or minute < 0 or minute > 59:
		return -1
	return hour * 60 + minute


func _format_schedule_time(minutes: int) -> String:
	if minutes >= 24 * 60:
		return "24:00"
	return "%02d:%02d" % [minutes / 60, minutes % 60]


func _duplicate_schedule(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not value is Array:
		return result
	for raw_entry in value:
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry
		result.append({
			"id": str(entry.get("id", "")),
			"start_time": str(entry.get("start_time", "")),
			"end_time": str(entry.get("end_time", "")),
			"content": str(entry.get("content", ""))
		})
	return result


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
			[
				"level", "condition", "is_enterable", "operational_efficiency",
				"active_job", "job_total_duration_text"
			]
		)
		_strip_damaged_building_efficiency(external_snapshot, plaza_changed_fields)
		_last_plaza_external_states[building_id] = external_snapshot.duplicate(true)
		if not plaza_changed_fields.is_empty():
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
			[
				"level", "condition", "is_enterable", "operational_efficiency",
				"active_job", "job_total_duration_text"
			]
		)
		_strip_damaged_building_efficiency(location_external_state, location_changed_fields)
		_last_location_external_states[building_id] = location_external_state.duplicate(true)
		if not location_changed_fields.is_empty():
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

	var special_state := _normalize_special_state_for_info(
		building_id,
		location_snapshot.get("special_state", location_snapshot.get("internal_state", {}).get("special_state", {}))
	)
	var special_state_key := JSON.stringify(special_state)
	var location_special_cache_key := "%s:special" % building_id
	if str(_last_location_state_keys.get(location_special_cache_key, "")) != special_state_key:
		_last_location_state_keys[location_special_cache_key] = special_state_key
		var changed_special_state := _diff_special_state(
			_last_location_special_states.get(building_id, {}),
			special_state
		)
		_last_location_special_states[building_id] = special_state.duplicate(true)
		if not changed_special_state.is_empty():
			_broadcast_location_state_changed(building_id, "building_internal_special_state_changed", {
				"building_id": building_id,
				"building_name": str(external_snapshot.get("name", building_id)),
				"changed_special_state": changed_special_state
			})


func _broadcast_public_event(event: Dictionary, location_id: String) -> void:
	if not _events_by_id.has(str(event.get("event_id", ""))):
		return
	var target_location_id := _normalize_location_id(location_id)
	if not is_enterable_location(target_location_id):
		target_location_id = DEFAULT_LOCATION_ID

	var recipient_ids: Array[String] = []
	if STATION_WIDE_PUBLIC_EVENT_TYPES.has(str(event.get("type", ""))):
		recipient_ids = _get_all_station_npc_ids()
	else:
		recipient_ids = get_location_people_present(target_location_id)
	var subject_npc_id := str(event.get("subject_npc_id", ""))
	var participant_npc_ids := _normalize_string_array(event.get("payload", {}).get("participant_npc_ids", []))
	for npc_id in recipient_ids:
		if npc_id == subject_npc_id or participant_npc_ids.has(npc_id):
			continue
		add_witness_event(npc_id, str(event.get("event_id", "")))


func _get_all_station_npc_ids() -> Array[String]:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_ids"):
		return []
	return _normalize_string_array(npc_system.get_npc_ids())


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
	if not payload.has("changed_fields") and not payload.has("changed_workstations") and not payload.has("changed_special_state"):
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
	var repair_status: Dictionary = building.get("repair_status", {}) if building.get("repair_status", {}) is Dictionary else {}
	var upgrade_status: Dictionary = building.get("upgrade_status", {}) if building.get("upgrade_status", {}) is Dictionary else {}
	var active_job := ""
	var job_total_duration_text := ""
	if not repair_status.is_empty():
		active_job = "repair"
		job_total_duration_text = str(repair_status.get("duration_text", ""))
	elif not upgrade_status.is_empty():
		active_job = "upgrade"
		job_total_duration_text = str(upgrade_status.get("duration_text", ""))
	return {
		"id": building_id,
		"name": str(building.get("name", building_id)),
		"level": int(building.get("level", 1)),
		"condition": str(building.get("condition", _derive_building_condition(building))),
		"is_enterable": bool(building.get("is_enterable", ENTERABLE_LOCATION_IDS.has(building_id))),
		"active_job": active_job,
		"job_total_duration_text": job_total_duration_text,
		"operational_efficiency": _to_operational_efficiency_band(float(building.get(
			"operational_efficiency",
			building.get("operational_efficiency_multiplier", 1.0)
		)))
	}


func _to_operational_efficiency_band(multiplier: float) -> float:
	var normalized := clampf(multiplier, 0.0, 1.0)
	if normalized <= 0.0:
		return 0.0
	if normalized >= 0.999:
		return 1.0
	if normalized >= 0.75:
		return 0.75
	if normalized >= 0.5:
		return 0.5
	return 0.25


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
	var special_state := _normalize_special_state_for_info(building_id, building.get("special_state", {}))
	var internal_state := {
		"people_present": people_present,
		"people_statuses": people_statuses,
		"workstations": _normalize_workstations_for_info(workstations),
		"special_state": special_state
	}
	var snapshot := external_state.duplicate(true)
	snapshot["external_state"] = external_state
	snapshot["internal_state"] = internal_state
	snapshot["people_present"] = people_present
	snapshot["people_statuses"] = people_statuses
	snapshot["workstations"] = internal_state["workstations"]
	snapshot["special_state"] = special_state.duplicate(true)
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
		var reserved_by := str(workstation.get("reserved_by", ""))
		if reserved_by == "<null>":
			reserved_by = ""
		normalized.append({
			"id": str(workstation.get("id", "")),
			"name": str(workstation.get("name", workstation.get("id", workstation.get("type", "位置")))),
			"type": str(workstation.get("type", "general")),
			"occupied_by": occupied_by,
			"reserved_by": reserved_by,
			"status": "occupied" if not occupied_by.is_empty() else "reserved" if not reserved_by.is_empty() else "free"
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
	if action_id == "planning_day":
		return "制定计划"
	if action_id == "proactive_talk":
		return "主动找守备官交涉"
	if action_id.begins_with("moving_to_combat_rally"):
		return "前往城门外防线"
	if action_id.begins_with("moving_to_combat_strategy_avoid_"):
		return "正在避战"
	if action_id.begins_with("moving_to_combat_strategy_"):
		return "进行战术移动"
	if action_id == "keep_distance_retreating":
		return "拉开距离"
	if action_id == "rallying_defense_line":
		return "在城门外集结"
	if action_id == "combat_strategy_avoid_holding":
		return "避战待命"
	if action_id == "combat_ready":
		return "准备接敌"
	if action_id == "meeting_assigned_horse":
		return "前往会合马匹"
	if action_id == "waiting_for_assigned_horse":
		return "等待马匹会合"
	if action_id.begins_with("attacking_"):
		return "攻击敌人"
	if action_id.begins_with("winding_up_"):
		return "准备攻击敌人"
	if action_id == "avoid_combat" or action_id == "avoiding_enemy":
		return "避战"
	if action_id.begins_with("moving_to_avoid_shelter_"):
		return "远离敌人避战"
	if action_id == "escaping_station" or action_id.begins_with("moving_to_back_gate_escape_exit"):
		return "正朝后门逃离"
	if action_id == "escaped":
		return "已离开驿站"
	if action_id.begins_with("visit_location_"):
		return "停留在%s" % _get_location_name(action_id.trim_prefix("visit_location_"))
	if action_id.begins_with("moving_to_healing_target_"):
		return "前往协助治疗%s" % _get_npc_display_name(action_id.trim_prefix("moving_to_healing_target_"))
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


func _strip_damaged_building_efficiency(current_state: Dictionary, changed_fields: Dictionary) -> void:
	if str(current_state.get("condition", "")) == "damaged":
		changed_fields.erase("operational_efficiency")


func _normalize_special_state_for_info(building_id: String, raw_state: Variant) -> Dictionary:
	var source: Dictionary = raw_state if raw_state is Dictionary else {}
	var normalized := {}
	if ["blacksmith", "workshop"].has(building_id):
		var raw_production: Variant = source.get("production", {})
		if raw_production is Dictionary:
			var production := {}
			for field_name in PRODUCTION_SPECIAL_FIELDS:
				if raw_production.has(field_name):
					production[field_name] = raw_production.get(field_name)
			if not production.is_empty():
				normalized["production"] = production
	elif building_id == "stable":
		var raw_horses: Variant = source.get("horses", {})
		if raw_horses is Dictionary:
			var horses := {}
			for field_name in HORSE_COUNT_SPECIAL_FIELDS:
				if raw_horses.has(field_name):
					horses[field_name] = int(raw_horses.get(field_name, 0))
			if not horses.is_empty():
				normalized["horses"] = horses
	return normalized


func _diff_special_state(previous_state: Dictionary, current_state: Dictionary) -> Dictionary:
	var changed := {}
	var section_ids: Array[String] = []
	for raw_section_id in previous_state.keys():
		var section_id := str(raw_section_id)
		if not section_ids.has(section_id):
			section_ids.append(section_id)
	for raw_section_id in current_state.keys():
		var current_section_id := str(raw_section_id)
		if not section_ids.has(current_section_id):
			section_ids.append(current_section_id)
	for section_id in section_ids:
		var previous_section: Dictionary = previous_state.get(section_id, {}) if previous_state.get(section_id, {}) is Dictionary else {}
		var current_section: Dictionary = current_state.get(section_id, {}) if current_state.get(section_id, {}) is Dictionary else {}
		if previous_section == current_section:
			continue
		if not current_state.has(section_id):
			changed[section_id] = {}
			continue
		var changed_fields := {}
		var field_names: Array[String] = []
		for raw_field_name in previous_section.keys():
			var field_name := str(raw_field_name)
			if not field_names.has(field_name):
				field_names.append(field_name)
		for raw_field_name in current_section.keys():
			var current_field_name := str(raw_field_name)
			if not field_names.has(current_field_name):
				field_names.append(current_field_name)
		for field_name in field_names:
			if previous_section.get(field_name) != current_section.get(field_name):
				changed_fields[field_name] = current_section.get(field_name)
		if not changed_fields.is_empty():
			changed[section_id] = changed_fields
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
			"name": str(workstation.get("name", workstation_id)),
			"type": str(workstation.get("type", "general")),
			"occupied_by": str(workstation.get("occupied_by", "")),
			"reserved_by": str(workstation.get("reserved_by", "")),
			"status": str(workstation.get("status", "free"))
		}
	return states


func _diff_workstation_states(previous_states: Dictionary, current_states: Dictionary) -> Array[Dictionary]:
	var changed: Array[Dictionary] = []
	for workstation_id in current_states.keys():
		var current_state: Dictionary = current_states[workstation_id]
		var previous_state: Dictionary = previous_states.get(workstation_id, {})
		if previous_state.is_empty():
			var added_state := current_state.duplicate(true)
			added_state["change"] = "added"
			changed.append(added_state)
			continue
		if (
			previous_state.get("name") != current_state.get("name")
			or previous_state.get("type") != current_state.get("type")
			or previous_state.get("occupied_by") != current_state.get("occupied_by")
			or previous_state.get("reserved_by") != current_state.get("reserved_by")
			or previous_state.get("status") != current_state.get("status")
		):
			var updated_state := current_state.duplicate(true)
			updated_state["change"] = "updated"
			changed.append(updated_state)
	for workstation_id in previous_states.keys():
		if current_states.has(workstation_id):
			continue
		var removed_state: Dictionary = (previous_states.get(workstation_id, {}) as Dictionary).duplicate(true)
		removed_state["change"] = "removed"
		removed_state["removed"] = true
		removed_state["status"] = "removed"
		changed.append(removed_state)
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

	var payload: Dictionary = (
		(event.get("payload", {}) as Dictionary).duplicate(true)
		if event.get("payload", {}) is Dictionary
		else {}
	)
	if payload.is_empty():
		payload = _legacy_payload_from_event(event)
	payload = _sanitize_narrative_event_payload(event_type, payload)

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


func _sanitize_narrative_event_payload(event_type: String, payload: Dictionary) -> Dictionary:
	var sanitized := payload.duplicate(true)
	match event_type:
		"work_failed", "prayer_failed":
			sanitized["reason"] = _format_memory_reason(
				sanitized.get("reason", ""),
				"行动条件不满足"
			)
		"plan_revised":
			sanitized["reason"] = _format_memory_reason(
				sanitized.get("reason", ""),
				"原计划需要重新评估"
			)
			sanitized["summary"] = _format_memory_reason(
				sanitized.get("summary", sanitized.get("reason", "")),
				"原计划已经不再适用"
			)
	return sanitized


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
		var notice := str(payload.get("notice", ""))
		if str(payload.get("reason", "")) == "initial_notice_board_state":
			return "公告牌初始通告：%s" % notice
		var notice_actor_ids := _normalize_string_array(event.get("actor_ids", []))
		var notice_actor_id := str(event.get("subject_npc_id", PLAZA_STATE_SUBJECT_ID))
		if not notice_actor_ids.is_empty():
			notice_actor_id = notice_actor_ids[0]
		var notice_actor := _get_actor_display_name(notice_actor_id)
		return "%s更新了通告：%s" % [notice_actor, "当前无通告。" if notice.is_empty() else notice]
	if event_type == "plaza_schedule_changed":
		var schedule_actor := ""
		if str(payload.get("reason", "")) != "initial_notice_board_state":
			var schedule_actor_ids := _normalize_string_array(event.get("actor_ids", []))
			var schedule_actor_id := str(event.get("subject_npc_id", PLAZA_STATE_SUBJECT_ID))
			if not schedule_actor_ids.is_empty():
				schedule_actor_id = schedule_actor_ids[0]
			schedule_actor = _get_actor_display_name(schedule_actor_id)
		return _format_reference_schedule_summary(
			payload.get("reference_schedule", []),
			str(payload.get("schedule_advisory_note", "")),
			false,
			schedule_actor
		)
	if event_type == "plaza_status_changed":
		return _format_building_or_plaza_state_summary(payload)
	if event_type == "location_status_changed":
		return _format_location_state_summary(payload)
	if event_type == "horse_born":
		return "一匹小马出生了，守备官给它取名为%s。" % str(payload.get("horse_name", "未命名"))
	if event_type == "merchant_arrived":
		return "%s在%s抵达后门，将停留到%s。" % [
			str(payload.get("merchant_name", "商队")),
			str(payload.get("arrival_time", "--")),
			str(payload.get("departure_time", "--"))
		]
	if event_type == "merchant_departed":
		return "%s在%s离开了后门。" % [
			str(payload.get("merchant_name", "商队")),
			str(event.get("time", "--"))
		]
	if event_type == "merchant_trade_completed":
		var resource_name := str(payload.get("resource_name", _get_resource_name(str(payload.get("resource_id", "")))))
		if str(payload.get("direction", "buy")) == "sell":
			return "守备官向商人出售了%d份%s，获得了%d枚第纳尔。" % [
				int(payload.get("amount", 0)),
				resource_name,
				int(payload.get("total_price", 0))
			]
		return "守备官从商人处购买了%d份%s，支付了%d枚第纳尔。" % [
			int(payload.get("amount", 0)),
			resource_name,
			int(payload.get("total_price", 0))
		]
	var actor := _get_npc_display_name(str(event.get("subject_npc_id", "")))
	var location := _get_location_name(str(event.get("location_id", DEFAULT_LOCATION_ID)))

	match event_type:
		"wake_up":
			return "%s在第%d天%02d点起床，开始安排新一天。" % [
				actor,
				int(payload.get("day", event.get("day", 1))),
				int(payload.get("hour", 6))
			]
		"location_entered":
			return _format_location_entered_summary(actor, payload, event)
		"location_exited":
			return "%s离开了%s。" % [actor, _get_location_name(str(payload.get("from_location_id", event.get("location_id", DEFAULT_LOCATION_ID))))]
		"work_started":
			return "%s开始在%s进行%s。" % [actor, location, _get_action_name(str(payload.get("action_id", "")))]
		"work_completed":
			var pending_outputs: Dictionary = payload.get("pending_output_resources", {}) if payload.get("pending_output_resources", {}) is Dictionary else {}
			if not pending_outputs.is_empty():
				return "%s完成了%s，消耗%s，制成待收取的%s。" % [
					actor,
					_get_action_name(str(payload.get("action_id", ""))),
					_format_resource_delta(payload.get("input_resources", {})),
					_format_resource_delta(pending_outputs)
				]
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
				_format_memory_reason(payload.get("reason", ""), "行动条件不满足")
			]
		"skill_improved":
			return _format_skill_improved_summary(actor, payload, location)
		"attribute_improved":
			var training_label := "体力" if str(payload.get("attribute", "")) == "strength" else "脑力"
			return "%s通过锻炼%s，%s从%d提高到%d。" % [
				actor,
				training_label,
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
		"wine_consumed":
			return "%s喝了一份酒，心情有所改善，过去的伤痛也暂时淡了一些。" % actor
		"prayer_started":
			if str(payload.get("prayer_mode", "")) == "mass_attendance":
				return "%s开始在%s参加弥撒。" % [actor, location]
			return "%s开始在%s%s。" % [actor, location, _get_action_name(str(payload.get("action_id", "pray_at_chapel")))]
		"prayer_joined_mass":
			if str(payload.get("trigger", "")) == "prayer_started_during_mass":
				return "%s到达%s祈祷时，%s正在主持弥撒，%s随众参加弥撒。" % [
					actor,
					location,
					_get_npc_display_name(str(payload.get("leader_npc_id", ""))),
					actor
				]
			return "%s因为%s开始主持弥撒，转为参加弥撒。" % [
				actor,
				_get_npc_display_name(str(payload.get("leader_npc_id", "")))
			]
		"prayer_resumed_alone":
			if str(payload.get("trigger", "")) == "mass_leader_stopped":
				return "%s参加的弥撒因主持中断而结束，%s继续在%s独自祈祷。" % [
					actor,
					actor,
					location
				]
			return "%s参加的弥撒结束，继续在%s独自祈祷。" % [actor, location]
		"prayer_completed":
			return "%s完成了在%s的%s。" % [actor, location, _get_action_name(str(payload.get("action_id", "pray_at_chapel")))]
		"prayer_failed":
			return "%s没能在%s继续%s：%s。" % [
				actor,
				location,
				_get_action_name(str(payload.get("action_id", "pray_at_chapel"))),
				_format_memory_reason(payload.get("reason", ""), "行动条件不满足")
			]
		"visit_started":
			return "%s抵达%s并准备暂时停留。" % [actor, location]
		"visit_completed":
			return "%s结束了在%s的停留。" % [actor, location]
		"dialogue_turn":
			var completed_transcript := _format_completed_player_dialogue_transcript(payload)
			if not completed_transcript.is_empty():
				return completed_transcript
			if str(payload.get("reply_text", "")).is_empty():
				return "%s对%s说：“%s”" % [
					str(payload.get("speaker_name", PLAYER_DISPLAY_NAME)),
					str(payload.get("listener_name", actor)),
					str(payload.get("speaker_text", ""))
				]
			return "%s对%s说：“%s” %s回答：“%s”" % [
				str(payload.get("speaker_name", PLAYER_DISPLAY_NAME)),
				str(payload.get("listener_name", actor)),
				str(payload.get("speaker_text", "")),
				str(payload.get("listener_name", actor)),
				str(payload.get("reply_text", ""))
			]
		"dialogue_special_interaction_result":
			return _format_dialogue_special_interaction_result(actor, payload)
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
			var revision_text := _format_memory_reason(
				payload.get("summary", payload.get("reason", "")),
				"原计划已经不再适用"
			)
			return "%s重新评估了当前计划：%s。" % [actor, revision_text]
		"money_given":
			return "%s给了%s%d枚第纳尔。" % [PLAYER_DISPLAY_NAME, actor, int(payload.get("amount", 0))]
		"wine_given":
			return "%s给了%s%d份酒。" % [PLAYER_DISPLAY_NAME, actor, int(payload.get("amount", 0))]
		"equipment_given":
			return "%s把%s交给了%s。" % [PLAYER_DISPLAY_NAME, str(payload.get("equipment_name", "装备")), actor]
		"equipment_changed":
			if str(payload.get("slot", "")) == "mount" and str(payload.get("equipment_id", "")).is_empty():
				return "%s收回了分配给%s的马匹。" % [PLAYER_DISPLAY_NAME, actor]
			return "%s为%s更换了%s。" % [PLAYER_DISPLAY_NAME, actor, str(payload.get("equipment_name", "装备"))]
		"order_assigned":
			return "守备官制定了新的指令。"
		"npc_attacked_by_player":
			return "%s攻击了%s，造成%d点伤害。" % [PLAYER_DISPLAY_NAME, actor, int(payload.get("damage", 0))]
		"combat_started":
			return _format_combat_started_summary(payload)
		"combat_ended":
			return _format_combat_ended_summary(payload)
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
		"battle_psychology_result":
			return "%s在战斗压力下作出了判断：%s。" % [actor, _format_battle_psychology_decision(str(payload.get("decision", "none")))]
		"low_hp_triggered":
			return "%s被打到残血，HP 从%d降到%d。" % [
				actor,
				int(payload.get("hp_before", 0)),
				int(payload.get("hp_after", 0))
			]
		"morale_boost_started":
			if str(payload.get("trigger", "wartime_dialogue")) == "low_hp":
				return "%s在残血压力下激起了斗志，攻击和移动暂时提升。" % actor
			return "%s被守备官的话激起了斗志，攻击和移动暂时提升。" % actor
		"morale_boost_ended":
			return "%s的斗志激昂状态消退了。" % actor
		"work_encouragement_result":
			match str(payload.get("decision", "none")):
				"work_boost":
					return "%s受到守备官鼓励，决定更积极地投入工作。" % actor
				"escape":
					return "%s听完守备官的话后决定逃离驿站。" % actor
				_:
					return "%s听完守备官的话后仍照常工作。" % actor
		"work_encouragement_boost_started":
			return "%s受到鼓励，当天工作产出效率提高了。" % actor
		"work_encouragement_boost_ended":
			return "%s的工作鼓励状态在跨天后结束了。" % actor
		"avoidance_started":
			return "%s发现敌军正在接近，正在避战。" % actor
		"avoidance_ended":
			return "%s不再避战，回到驿站日常安排。" % actor
		"escape_started":
			return "%s开始朝%s逃离驿站。" % [
				actor,
				str(payload.get("exit_target_name", "后门"))
			]
		"escaped":
			return "%s已经从%s离开了驿站。" % [
				actor,
				str(payload.get("exit_target_name", "后门"))
			]
		"escape_intervention_result":
			if str(payload.get("decision", "")) == "stay":
				return "%s被守备官挽留下来，停止逃离驿站。" % actor
			return "%s听完守备官的话后，仍继续逃离驿站。" % actor
		"escape_speed_changed":
			if str(payload.get("trigger", "")) == "money_given":
				return "%s收下守备官给的钱，逃离脚步慢了下来。" % actor
			if str(payload.get("trigger", "")) == "guard_attack":
				return "%s被守备官攻击后，逃离脚步更急了。" % actor
			return "%s逃离驿站的速度发生变化。" % actor
		"attack_made":
			var target_name := str(payload.get("target_enemy_name", payload.get("target_enemy_id", "敌人")))
			var defeated_text := "，击退了敌人" if bool(payload.get("defeated", false)) else ""
			return "%s攻击了%s，造成%d点伤害%s。" % [
				actor,
				target_name,
				int(payload.get("damage", 0)),
				defeated_text
			]
		"combat_strategy_selected":
			return "守备官将%s的战斗策略调整为%s。" % [
				actor,
				str(payload.get("strategy_label", payload.get("strategy_id", "未指定策略")))
			]
		"defense_device_deployed":
			return "%s把%s部署在%s，消耗了%d份工程器械库存。" % [
				actor,
				str(payload.get("device_name", "工程器械")),
				str(payload.get("slot_name", "围墙部署槽")),
				int(payload.get("inventory_cost", 1))
			]
		"defense_device_triggered":
			var defeated_text := "，并击退了敌人" if bool(payload.get("defeated", false)) else ""
			return "%s部署的%s攻击了%s，造成%d点伤害%s。" % [
				actor,
				str(payload.get("device_name", "工程器械")),
				str(payload.get("target_enemy_name", payload.get("target_enemy_id", "敌人"))),
				int(payload.get("damage", 0)),
				defeated_text
			]
		"piety_meteor_cast":
			return "守备官消耗全部虔诚，指定了一处陨石落点。"
		"piety_meteor_impact":
			return "由于全站虔诚祈祷，天降陨石砸向敌人并点燃了地面，而我方毫发无损。"
		"piety_meteor_enemy_defeated":
			return "陨石以相当直接的正义砸死了%d名敌人；看来天意这次没有采用含蓄的表达方式。" % int(payload.get("enemy_defeated_count", 0))
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
		"horse_damaged":
			return "%s骑乘的%s承受了%.1f点伤害，HP 从%.1f降到%.1f。" % [
				actor,
				str(payload.get("horse_name", "马匹")),
				float(payload.get("damage", 0.0)),
				float(payload.get("hp_before", 0.0)),
				float(payload.get("hp_after", 0.0))
			]
		"horse_died":
			return "%s骑乘的%s在战斗中阵亡，%s改为步战。" % [
				actor,
				str(payload.get("horse_name", "马匹")),
				actor
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
		"healing_failed":
			return "%s对%s的治疗中断了。" % [
				_get_npc_display_name(str(payload.get("healer_npc_id", ""))),
				_get_npc_display_name(str(payload.get("target_npc_id", "")))
			]
		"revived":
			return "%s在%s苏醒了。" % [actor, location]
		"sleep_started":
			return "%s开始在%s休息。" % [actor, location]
		"sleep_ended":
			return "%s在%s休息后恢复了些精神。" % [actor, location]
		_:
			return "%s经历了一件值得记录的事。" % actor


func _format_memory_reason(raw_value: Variant, fallback: String) -> String:
	var text_value := str(raw_value).strip_edges()
	if (
		text_value.is_empty()
		or not _contains_cjk_text(text_value)
		or text_value.contains("_")
		or text_value.contains("res://")
		or text_value.contains("\\")
		or text_value.contains("::")
		or text_value.contains("=")
	):
		return fallback
	while text_value.ends_with("。") or text_value.ends_with("."):
		text_value = text_value.left(-1).strip_edges()
	return fallback if text_value.is_empty() else text_value


func _contains_cjk_text(text_value: String) -> bool:
	for index in range(text_value.length()):
		var codepoint := text_value.unicode_at(index)
		if (codepoint >= 0x3400 and codepoint <= 0x4DBF) or (codepoint >= 0x4E00 and codepoint <= 0x9FFF):
			return true
	return false


func _format_completed_player_dialogue_transcript(payload: Dictionary) -> String:
	if not bool(payload.get("session_completed", false)):
		return ""
	var raw_history: Variant = payload.get("dialogue_text", [])
	if not raw_history is Array:
		return ""
	var transcript_lines: Array[String] = []
	for raw_turn in raw_history:
		if not raw_turn is Dictionary:
			continue
		var turn: Dictionary = raw_turn
		var turn_speaker_name := str(turn.get("speaker_name", "")).strip_edges()
		var turn_text := str(turn.get("text", "")).strip_edges()
		if turn_speaker_name.is_empty() or turn_text.is_empty():
			continue
		transcript_lines.append("%s：“%s”" % [turn_speaker_name, turn_text])
	if transcript_lines.is_empty():
		return ""
	var speaker_name := str(payload.get("speaker_name", PLAYER_DISPLAY_NAME)).strip_edges()
	var listener_name := str(payload.get("listener_name", "")).strip_edges()
	var heading := "对话"
	if not speaker_name.is_empty() and not listener_name.is_empty():
		heading = "%s与%s对话" % [speaker_name, listener_name]
	return "%s：\n%s" % [heading, "\n".join(transcript_lines)]


func _format_dialogue_special_interaction_result(npc_name: String, payload: Dictionary) -> String:
	var outcome := str(payload.get("outcome", "none"))
	match str(payload.get("special_type", "")):
		"recruitment":
			if outcome == "accept":
				return "守备官成功说服了%s，%s同意入伍。" % [npc_name, npc_name]
			return "守备官尝试说服%s入伍，%s没有同意。" % [npc_name, npc_name]
		"morale_encouragement":
			if outcome == "morale_boost":
				return "守备官成功鼓舞了%s的士气。" % npc_name
			if outcome == "escape":
				return "%s没有被守备官鼓舞，决定逃离驿站。" % npc_name
			return "%s没有受到守备官的鼓舞，继续参战。" % npc_name
		"work_encouragement":
			if outcome == "work_boost":
				return "守备官成功鼓励了%s，%s决定更积极地工作。" % [npc_name, npc_name]
			if outcome == "escape":
				return "%s没有接受守备官的工作鼓励，决定逃离驿站。" % npc_name
			return "%s没有受到守备官的工作鼓励，照常工作。" % npc_name
		"combat_strategy":
			var strategy_label := str(payload.get("strategy_label", "当前策略"))
			if outcome == "change":
				return "守备官成功说服%s将战斗策略改变为“%s”。" % [npc_name, strategy_label]
			return "%s没有改变战斗策略，继续采用“%s”。" % [npc_name, strategy_label]
	return "%s对守备官的特殊交涉作出了回应。" % npc_name


func _format_combat_started_summary(payload: Dictionary) -> String:
	var enemy_text := _format_enemy_roster_summary(payload.get("enemy_roster", []))
	var friendly_text := _format_friendly_roster_summary(payload.get("friendly_roster", []))
	if friendly_text.is_empty():
		friendly_text = "暂无已入伍且持武器的守备者"
	return "敌军来袭：第%d波，%d名敌人逼近驿站，敌军包括%s。我方可战斗人员：%s。" % [
		int(payload.get("wave_number", 0)),
		int(payload.get("enemy_count", 0)),
		enemy_text,
		friendly_text
	]


func _format_combat_ended_summary(payload: Dictionary) -> String:
	var reason := str(payload.get("reason", "enemies_defeated"))
	var outcome := "敌人已经全被消灭"
	if ["enemies_cleared", "gm_clear", "enemy_retreat"].has(reason):
		outcome = "敌人已经撤退或被清空"
	var injured_text := _format_battle_injured_summary(payload.get("injured_npcs", []))
	var unconscious_text := _format_battle_unconscious_summary(payload.get("unconscious_npcs", []))
	var defeated_text := _format_battle_defeated_summary(payload.get("defeated_by_npc", []))
	return "%s，第%d波战斗结束。受伤：%s。昏迷：%s。击退敌人：%s。" % [
		outcome,
		int(payload.get("wave_number", 0)),
		injured_text,
		unconscious_text,
		defeated_text
	]


func _format_enemy_roster_summary(raw_roster: Variant) -> String:
	var roster: Array = raw_roster if raw_roster is Array else []
	if roster.is_empty():
		return "未知敌军"
	var parts: Array[String] = []
	for raw_entry in roster:
		var entry: Dictionary = raw_entry if raw_entry is Dictionary else {}
		if entry.is_empty():
			continue
		var count := int(entry.get("count", 0))
		var name := str(entry.get("name", "敌人"))
		var unit_label := str(entry.get("unit_type_label", entry.get("unit_type", "")))
		if unit_label.is_empty():
			parts.append("%d名%s" % [count, name])
		else:
			parts.append("%d名%s（%s）" % [count, name, unit_label])
	if parts.is_empty():
		return "未知敌军"
	return "、".join(parts)


func _format_friendly_roster_summary(raw_roster: Variant) -> String:
	var roster: Array = raw_roster if raw_roster is Array else []
	var parts: Array[String] = []
	for raw_entry in roster:
		var entry: Dictionary = raw_entry if raw_entry is Dictionary else {}
		if entry.is_empty():
			continue
		parts.append("%s（%s）" % [
			str(entry.get("npc_name", entry.get("npc_id", "未知守备者"))),
			str(entry.get("unit_type_label", entry.get("unit_type", "战斗人员")))
		])
	return "、".join(parts)


func _format_battle_injured_summary(raw_entries: Variant) -> String:
	var entries: Array = raw_entries if raw_entries is Array else []
	if entries.is_empty():
		return "无"
	var parts: Array[String] = []
	for raw_entry in entries:
		var entry: Dictionary = raw_entry if raw_entry is Dictionary else {}
		if entry.is_empty():
			continue
		parts.append("%s受伤%d点" % [
			str(entry.get("npc_name", entry.get("npc_id", "未知NPC"))),
			int(entry.get("damage_taken", 0))
		])
	if parts.is_empty():
		return "无"
	return "、".join(parts)


func _format_battle_unconscious_summary(raw_entries: Variant) -> String:
	var entries: Array = raw_entries if raw_entries is Array else []
	if entries.is_empty():
		return "无"
	var parts: Array[String] = []
	for raw_entry in entries:
		var entry: Dictionary = raw_entry if raw_entry is Dictionary else {}
		if entry.is_empty():
			continue
		parts.append(str(entry.get("npc_name", entry.get("npc_id", "未知NPC"))))
	if parts.is_empty():
		return "无"
	return "、".join(parts)


func _format_battle_defeated_summary(raw_entries: Variant) -> String:
	var entries: Array = raw_entries if raw_entries is Array else []
	if entries.is_empty():
		return "无"
	var parts: Array[String] = []
	for raw_entry in entries:
		var entry: Dictionary = raw_entry if raw_entry is Dictionary else {}
		if entry.is_empty():
			continue
		parts.append("%s击退%d名" % [
			str(entry.get("npc_name", entry.get("npc_id", "未知NPC"))),
			int(entry.get("defeated_count", 0))
		])
	if parts.is_empty():
		return "无"
	return "、".join(parts)


func _format_building_or_plaza_state_summary(payload: Dictionary) -> String:
	var building_snapshot: Dictionary = payload.get("building_snapshot", {})
	var building_name := str(payload.get("building_name", building_snapshot.get("name", "")))
	var changed_fields: Dictionary = payload.get("changed_fields", {})
	if not building_name.is_empty() and not changed_fields.is_empty():
		return _format_external_state_delta_sentence(building_name, changed_fields)
	if not building_name.is_empty():
		return _format_external_state_sentence(building_name, building_snapshot)
	return "广场公告变为：%s。" % str(payload.get("current_notice", ""))


func _format_reference_schedule_summary(
	raw_schedule: Variant,
	advisory_note: String,
	current_state: bool = false,
	update_actor: String = ""
) -> String:
	var schedule := _duplicate_schedule(raw_schedule)
	var parts: Array[String] = []
	for entry in schedule:
		parts.append("%s—%s %s" % [
			str(entry.get("start_time", "--:--")),
			str(entry.get("end_time", "--:--")),
			str(entry.get("content", ""))
		])
	var schedule_text := "暂无安排" if parts.is_empty() else "；".join(parts)
	var normalized_note := advisory_note.strip_edges()
	var heading := "公告牌当前参考日程" if current_state else "公告牌参考日程更新"
	if not update_actor.is_empty():
		heading = "%s更新了参考日程" % update_actor
	if normalized_note.is_empty():
		return "%s：%s。" % [heading, schedule_text]
	return "%s：%s。备注：%s" % [heading, schedule_text, normalized_note]


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


func _format_battle_psychology_decision(decision: String) -> String:
	match decision:
		"morale_boost":
			return "斗志激昂"
		"escape":
			return "产生逃离念头"
		"continue_fighting":
			return "继续参战"
		"avoid_battle":
			return "继续避战"
		_:
			return "继续压住恐惧"


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
	if reason == "building_internal_special_state_changed" and payload.has("changed_special_state"):
		return _format_special_state_sentence(building_name, payload.get("changed_special_state", {}), true)
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
		var internal_parts: Array[String] = ["%s里的工位状态：%s。" % [building_name, _format_workstation_states(internal_state.get("workstations", []))]]
		var internal_special_text := _format_special_state_sentence(building_name, internal_state.get("special_state", {}), false)
		if not internal_special_text.is_empty():
			internal_parts.append(internal_special_text)
		return " ".join(internal_parts)
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
		if snapshot.has("current_notice"):
			var current_notice := str(snapshot.get("current_notice", ""))
			if current_notice.is_empty():
				plaza_parts.append("公告牌目前没有公告。")
			else:
				plaza_parts.append("公告牌写着：%s。" % current_notice)
		if snapshot.has("reference_schedule") or snapshot.has("schedule_advisory_note"):
			var reference_schedule := _duplicate_schedule(snapshot.get("reference_schedule", []))
			var advisory_note := str(snapshot.get("schedule_advisory_note", ""))
			plaza_parts.append(_format_reference_schedule_summary(reference_schedule, advisory_note, true))
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
	var special_text := _format_special_state_sentence(location_name, internal_state.get("special_state", {}), false)
	if not special_text.is_empty():
		parts.append(special_text)
	return " ".join(parts)


func _format_external_state_delta_sentence(building_name: String, changed_fields: Dictionary) -> String:
	if changed_fields.is_empty():
		return "%s状态未变。" % building_name
	var changes: Array[String] = []
	if changed_fields.has("level"):
		changes.append("等级变为%d级" % int(changed_fields.get("level", 1)))
	if changed_fields.has("condition"):
		changes.append(_format_building_condition(str(changed_fields.get("condition", "unknown"))))
	if changed_fields.has("is_enterable"):
		changes.append("现在可进入" if bool(changed_fields.get("is_enterable", false)) else "现在不可进入")
	if changed_fields.has("operational_efficiency"):
		changes.append("运作效率变为%d%%" % int(round(float(changed_fields.get("operational_efficiency", 1.0)) * 100.0)))
	var active_job := str(changed_fields.get("active_job", ""))
	var duration_text := str(changed_fields.get("job_total_duration_text", ""))
	if not duration_text.is_empty():
		var job_label := "修复" if active_job == "repair" else "升级" if active_job == "upgrade" else "作业"
		changes.append("本次%s预计需要%s" % [job_label, duration_text])
	if changes.is_empty():
		return "%s状态发生变化。" % building_name
	return "%s%s。" % [building_name, "，".join(changes)]


func _format_special_state_sentence(building_name: String, raw_state: Variant, is_delta: bool) -> String:
	var special_state: Dictionary = raw_state if raw_state is Dictionary else {}
	var production: Dictionary = special_state.get("production", {}) if special_state.get("production", {}) is Dictionary else {}
	if not production.is_empty():
		if is_delta:
			var changed_parts: Array[String] = []
			if production.has("target_item_id") or production.has("target_name"):
				var changed_target_name := str(production.get("target_name", production.get("target_item_id", "")))
				changed_parts.append("制造目标取消" if changed_target_name.is_empty() else "制造目标变为%s" % changed_target_name)
			if production.has("completed_stages"):
				changed_parts.append("已完成阶段变为%d" % int(production.get("completed_stages", 0)))
			if production.has("total_stages"):
				changed_parts.append("总阶段数变为%d" % int(production.get("total_stages", 0)))
			if production.has("current_stage_index") or production.has("current_stage_name"):
				var changed_stage_index := int(production.get("current_stage_index", 0))
				var changed_stage_name := str(production.get("current_stage_name", ""))
				if changed_stage_index <= 0:
					changed_parts.append("当前没有制造阶段")
				elif changed_stage_name.is_empty():
					changed_parts.append("进入第%d阶段" % changed_stage_index)
				else:
					changed_parts.append("进入第%d阶段“%s”" % [changed_stage_index, changed_stage_name])
			return "%s的%s。" % [building_name, "，".join(changed_parts)] if not changed_parts.is_empty() else ""
		var target_name := str(production.get("target_name", ""))
		var target_item_id := str(production.get("target_item_id", ""))
		if target_name.is_empty() and target_item_id.is_empty():
			return "%s当前没有选择制造目标。" % building_name
		if target_name.is_empty():
			target_name = target_item_id
		var completed := int(production.get("completed_stages", 0))
		var total := int(production.get("total_stages", 0))
		var stage_index := int(production.get("current_stage_index", 0))
		var stage_name := str(production.get("current_stage_name", ""))
		var stage_text := ""
		if stage_index > 0 and not stage_name.is_empty():
			stage_text = "，当前第%d阶段“%s”" % [stage_index, stage_name]
		return "%s正在制造%s，已完成%d/%d阶段%s。" % [building_name, target_name, completed, total, stage_text]
	var horses: Dictionary = special_state.get("horses", {}) if special_state.get("horses", {}) is Dictionary else {}
	if not horses.is_empty():
		if is_delta:
			var horse_parts: Array[String] = []
			if horses.has("total"):
				horse_parts.append("总数%d匹" % int(horses.get("total", 0)))
			if horses.has("adult"):
				horse_parts.append("成年%d匹" % int(horses.get("adult", 0)))
			if horses.has("foal"):
				horse_parts.append("小马%d匹" % int(horses.get("foal", 0)))
			return "%s马厩内马匹数量变为：%s。" % [building_name, "，".join(horse_parts)] if not horse_parts.is_empty() else ""
		return "%s马厩内有%d匹，其中成年%d匹、小马%d匹。" % [
			building_name, int(horses.get("total", 0)), int(horses.get("adult", 0)), int(horses.get("foal", 0))
		]
	return ""


func _format_external_state_sentence(building_name: String, external_state: Dictionary) -> String:
	var level := int(external_state.get("level", 1))
	var condition := str(external_state.get("condition", "unknown"))
	var state_parts: Array[String] = []
	if condition == "intact" and level > 1:
		state_parts.append("等级变为%d级" % level)
	state_parts.append(_format_building_condition(condition))
	if not bool(external_state.get("is_enterable", true)):
		state_parts.append("当前不可进入")
	var operational_efficiency := maxf(0.0, float(external_state.get("operational_efficiency", 1.0)))
	if not is_equal_approx(operational_efficiency, 1.0):
		state_parts.append("运作效率%d%%" % int(round(operational_efficiency * 100.0)))
	var duration_text := str(external_state.get("job_total_duration_text", ""))
	if not duration_text.is_empty():
		var active_job := str(external_state.get("active_job", ""))
		var job_label := "修复" if active_job == "repair" else "升级" if active_job == "upgrade" else "作业"
		state_parts.append("本次%s预计需要%s" % [job_label, duration_text])
	return "%s%s。" % [building_name, "，".join(state_parts)]


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
		return "没有位置"
	var parts: Array[String] = []
	for raw_workstation in raw_workstations:
		if not raw_workstation is Dictionary:
			continue
		var workstation: Dictionary = raw_workstation
		var station_name := str(workstation.get("name", workstation.get("id", workstation.get("type", "位置"))))
		var change := str(workstation.get("change", ""))
		if change == "removed" or str(workstation.get("status", "")) == "removed":
			parts.append("%s已移除" % station_name)
			continue
		var occupied_by := str(workstation.get("occupied_by", ""))
		var reserved_by := str(workstation.get("reserved_by", ""))
		var state_text := "空闲"
		if not occupied_by.is_empty() and occupied_by != "<null>":
			state_text = "被%s占用" % _get_npc_display_name(occupied_by)
		elif not reserved_by.is_empty() and reserved_by != "<null>":
			state_text = "已为%s预留" % _get_npc_display_name(reserved_by)
		if change == "added":
			parts.append("新增%s，当前%s" % [station_name, state_text])
		else:
			parts.append("%s%s" % [station_name, state_text])
	if parts.is_empty():
		return "没有位置"
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
	if ["combat_started", "combat_ended"].has(event_type) and payload.has("wave_id"):
		target_ids.append(str(payload["wave_id"]))
	if ["battle_psychology_result", "low_hp_triggered", "morale_boost_started", "morale_boost_ended"].has(event_type) and payload.has("source_event_id"):
		target_ids.append(str(payload["source_event_id"]))
	if event_type == "attack_made" and payload.has("target_enemy_id"):
		target_ids.append(str(payload["target_enemy_id"]))
	if ["damage_taken", "horse_damaged", "horse_died", "unconscious_started", "healing_started", "healing_completed", "healing_failed"].has(event_type) and payload.has("target_npc_id"):
		target_ids.append(str(payload["target_npc_id"]))
	if ["healing_started", "healing_completed", "healing_failed"].has(event_type) and payload.has("healer_npc_id"):
		target_ids.append(str(payload["healer_npc_id"]))
	if ["merchant_arrived", "merchant_departed", "merchant_trade_completed"].has(event_type) and payload.has("merchant_id"):
		target_ids.append(str(payload["merchant_id"]))
	if event_type == "merchant_trade_completed" and payload.has("resource_id"):
		target_ids.append(str(payload["resource_id"]))
	if ["defense_device_deployed", "defense_device_triggered"].has(event_type):
		for key in ["deployment_id", "device_id", "slot_id", "target_enemy_id"]:
			if payload.has(key):
				target_ids.append(str(payload[key]))
	if ["piety_meteor_cast", "piety_meteor_impact", "piety_meteor_enemy_defeated"].has(event_type) and payload.has("cast_id"):
		target_ids.append(str(payload["cast_id"]))
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
	if (
		bool(state.get("unconscious", false))
		or bool(state.get("escaped", false))
		or str(state.get("behavior_mode", "")) == "escaped"
		or str(state.get("current_location", "")) == "outside_station"
	):
		return false
	return str(state.get("current_action", "")) != "sleep_in_dormitory"


func _events_from_ids(event_ids: Array) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for raw_event_id in event_ids:
		var event_id := str(raw_event_id)
		if _events_by_id.has(event_id):
			events.append(_events_by_id[event_id].duplicate(true))
	return events


func _without_snapshot_ids(current_ids: Array, snapshot_ids: Array) -> Array:
	var snapshot_set := {}
	for raw_id in snapshot_ids:
		snapshot_set[str(raw_id)] = true
	var remaining: Array = []
	for raw_id in current_ids:
		if not snapshot_set.has(str(raw_id)):
			remaining.append(raw_id)
	return remaining


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
	if npc_id == PLAYER_ACTOR_ID:
		return PLAYER_DISPLAY_NAME
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
		return "当前行动"
	if action_system.has_method("get_action_ids") and not action_system.get_action_ids().has(action_id):
		return "当前行动"
	var action: Dictionary = action_system.get_action(action_id)
	var action_name := str(action.get("name", "")).strip_edges()
	return "当前行动" if action_name.is_empty() else action_name


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
