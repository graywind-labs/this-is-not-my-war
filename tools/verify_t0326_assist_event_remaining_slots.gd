extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const REPAIR_BUILDING_ID := "back_gate"
const UPGRADE_BUILDING_ID := "front_gate"
const FIRST_HELPER_ID := "engineer_01"
const SECOND_HELPER_ID := "doctor_01"
const HEALING_TARGET_ID := "cook_01"

var _failures: PackedStringArray = []
var _main: Node
var _action_system: Node
var _building_system: Node
var _memory_system: Node
var _npc_system: Node
var _resource_system: Node
var _time_system: Node


func _initialize() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	_main = MAIN_SCENE.instantiate()
	var startup := _main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(_main)
	for _frame in range(6):
		await process_frame
		await physics_frame

	_action_system = root.get_node_or_null("Main/Systems/ActionSystem")
	_building_system = root.get_node_or_null("Main/Systems/BuildingSystem")
	_memory_system = root.get_node_or_null("Main/Systems/MemorySystem")
	_npc_system = root.get_node_or_null("Main/Systems/NPCSystem")
	_resource_system = root.get_node_or_null("Main/Systems/ResourceSystem")
	_time_system = root.get_node_or_null("Main/Systems/TimeSystem")
	_check(
		_action_system != null
		and _building_system != null
		and _memory_system != null
		and _npc_system != null
		and _resource_system != null
		and _time_system != null,
		"T0326 required systems missing"
	)
	if not _failures.is_empty():
		_finish()
		return

	_time_system.set_time_scale(0.0)
	_resource_system.add_resource("stone", 100)
	_resource_system.add_resource("money", 100)
	if not await _verify_building_assist_event("repair", REPAIR_BUILDING_ID):
		_finish()
		return
	if not await _verify_building_assist_event("upgrade", UPGRADE_BUILDING_ID):
		_finish()
		return
	if not await _verify_healing_assist_event():
		_finish()
		return
	_finish()


func _verify_building_assist_event(service_kind: String, building_id: String) -> bool:
	_interrupt_helper(FIRST_HELPER_ID, "t0326_prepare_%s" % service_kind)
	_interrupt_helper(SECOND_HELPER_ID, "t0326_prepare_%s" % service_kind)
	if service_kind == "repair":
		if not _building_system.debug_damage_building(building_id, 40):
			_fail("Could not damage %s for repair event" % building_id)
			return false
		if not _building_system.repair_building(building_id):
			_fail("Could not start repair for %s" % building_id)
			return false
	else:
		if not _building_system.upgrade_building(building_id):
			_fail("Could not start upgrade for %s" % building_id)
			return false

	var assigned_first: bool = (
		_action_system.debug_assign_repair_assist(FIRST_HELPER_ID, building_id, true)
		if service_kind == "repair"
		else _action_system.debug_assign_upgrade_assist(FIRST_HELPER_ID, building_id, true)
	)
	var assigned_second: bool = (
		_action_system.debug_assign_repair_assist(SECOND_HELPER_ID, building_id, true)
		if service_kind == "repair"
		else _action_system.debug_assign_upgrade_assist(SECOND_HELPER_ID, building_id, true)
	)
	_check(assigned_first and assigned_second, "Could not reserve two %s assist slots" % service_kind)
	if not _failures.is_empty():
		return false

	var capacity: Dictionary = _npc_system.get_formal_building_exterior_capacity_snapshot(
		building_id,
		service_kind
	)
	var expected_remaining := int(capacity.get("total_slots", 0)) - 2
	_check(
		int(capacity.get("committed_slots", -1)) == 2
		and int(capacity.get("remaining_slots", -1)) == expected_remaining,
		"%s capacity did not include both active and in-transit reservations: %s" % [
			service_kind,
			JSON.stringify(capacity),
		]
	)
	_snap_to_exterior_service_slot(FIRST_HELPER_ID)
	var event_type := "%s_assist_started" % service_kind
	var expected_result := "assist_%s_started_%s" % [service_kind, building_id]
	if not await _wait_for_action_result(FIRST_HELPER_ID, expected_result):
		_fail("%s helper did not commit after reaching the reserved slot" % service_kind)
		return false
	var event := _find_latest_event(event_type)
	var payload: Dictionary = event.get("payload", {}) if event.get("payload", {}) is Dictionary else {}
	_check(
		int(payload.get("remaining_helper_slots", -1)) == expected_remaining,
		"%s event remaining slots mismatch: %s" % [service_kind, JSON.stringify(event)]
	)
	_check(
		str(event.get("summary", "")).contains("还有%d人可以参与协助" % expected_remaining),
		"%s event summary omitted remaining slots: %s" % [service_kind, str(event.get("summary", ""))]
	)

	_interrupt_helper(FIRST_HELPER_ID, "t0326_%s_done" % service_kind)
	_interrupt_helper(SECOND_HELPER_ID, "t0326_%s_done" % service_kind)
	_building_system._on_logical_time_tick(99999.0, 1.0)
	await process_frame
	return _failures.is_empty()


func _verify_healing_assist_event() -> bool:
	_interrupt_helper(FIRST_HELPER_ID, "t0326_prepare_healing")
	_interrupt_helper(SECOND_HELPER_ID, "t0326_prepare_healing")
	_npc_system.debug_enter_location_immediately(HEALING_TARGET_ID, "plaza")
	_npc_system.debug_enter_location_immediately(FIRST_HELPER_ID, "plaza")
	_npc_system.debug_enter_location_immediately(SECOND_HELPER_ID, "plaza")
	var damage: Dictionary = _npc_system.debug_damage_npc(HEALING_TARGET_ID, 999, "local_public")
	_check(bool(damage.get("ok", false)), "Could not prepare unconscious healing target")
	if not _failures.is_empty():
		return false
	var first_assigned: bool = _action_system.debug_assign_heal_assist(
		FIRST_HELPER_ID,
		HEALING_TARGET_ID,
		true
	)
	var second_assigned: bool = _action_system.debug_assign_heal_assist(
		SECOND_HELPER_ID,
		HEALING_TARGET_ID,
		true
	)
	_check(first_assigned and second_assigned, "Could not reserve two healing commitments")
	if not _failures.is_empty():
		return false
	_snap_to_healing_approach(FIRST_HELPER_ID)
	if not await _wait_for_action_result(
		FIRST_HELPER_ID,
		"assist_heal_started_%s" % HEALING_TARGET_ID
	):
		_fail("First healer did not commit after reaching the target")
		return false
	var event := _find_latest_event("healing_started")
	var payload: Dictionary = event.get("payload", {}) if event.get("payload", {}) is Dictionary else {}
	_check(
		int(payload.get("remaining_helper_slots", -1)) == 0,
		"Healing event ignored the second in-transit commitment: %s" % JSON.stringify(event)
	)
	_check(
		str(event.get("summary", "")).contains("还有0人可以参与协助"),
		"Healing event summary omitted the exhausted helper capacity: %s" % str(event.get("summary", ""))
	)
	return _failures.is_empty()


func _snap_to_exterior_service_slot(npc_id: String) -> void:
	var snapshot: Dictionary = _npc_system.get_formal_workstation_action_snapshot(npc_id)
	var session: Dictionary = snapshot.get("session", {}) if snapshot.get("session", {}) is Dictionary else {}
	var target_position: Variant = session.get("service_target_position")
	var npc_node := _npc_system.get_node_or_null(_npc_system._npc_nodes.get(npc_id, NodePath())) as Node3D
	if npc_node != null and target_position is Vector3:
		npc_node.global_position = target_position


func _snap_to_healing_approach(npc_id: String) -> void:
	var snapshot: Dictionary = _npc_system.get_formal_healing_approach_snapshot(npc_id)
	var session: Dictionary = snapshot.get("session", {}) if snapshot.get("session", {}) is Dictionary else {}
	var target_position: Variant = session.get("healing_approach_position")
	var npc_node := _npc_system.get_node_or_null(_npc_system._npc_nodes.get(npc_id, NodePath())) as Node3D
	if npc_node != null and target_position is Vector3:
		npc_node.global_position = target_position


func _wait_for_action_result(npc_id: String, expected: String) -> bool:
	for _frame in range(360):
		await physics_frame
		if str(_npc_system.get_npc_state(npc_id).get("last_action_result", "")) == expected:
			return true
	return false


func _find_latest_event(event_type: String) -> Dictionary:
	var events: Array = _memory_system.get_all_events()
	for index in range(events.size() - 1, -1, -1):
		var event: Variant = events[index]
		if event is Dictionary and str((event as Dictionary).get("type", "")) == event_type:
			return (event as Dictionary).duplicate(true)
	return {}


func _interrupt_helper(npc_id: String, reason: String) -> void:
	_action_system.interrupt_npc_action(npc_id, reason, true)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0326 assist event remaining-slot verification passed.")
		quit(0)
		return
	quit(1)
