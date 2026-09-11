extends SceneTree

const PILOT_ID := "dining_seat"
const NPC_ID := "cook_01"
const BUILDING_ID := "dining_hall"
const FIRST_SEAT_ID := "dining_seat_01"
const SECOND_SEAT_ID := "dining_seat_02"
const BLOCKER_NPC_ID := "stableman_01"

var _building_system: Node
var _npc: CharacterBody3D
var _expected_commit_seat_id := ""
var _seat_commit_observed := false
var _attachment_inactive_when_seat_committed := false


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Main.tscn unavailable")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	_building_system = root.get_node_or_null("Main/Systems/BuildingSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var event_bus := root.get_node_or_null("EventBus")
	_npc = root.get_node_or_null("Main/WorldRoot/Station/NPCs/Cook01") as CharacterBody3D
	if npc_system == null or _building_system == null or _npc == null or event_bus == null:
		_fail("A2b-P4 runtime dependencies unavailable")
		return
	if time_system != null and time_system.has_method("set_paused"):
		time_system.set_paused(false)
	_npc.move_speed = 12.0
	if event_bus.has_signal("building_state_changed"):
		event_bus.building_state_changed.connect(_on_building_state_changed)

	var registry: Dictionary = npc_system.debug_get_formal_navigation_pilots_snapshot()
	var registered_ids: Array = registry.get("registered_pilot_ids", [])
	for required_id in ["glen", "clinic_doctor", "clinic_bed", "dormitory_bed", PILOT_ID]:
		if required_id not in registered_ids:
			_fail("Data-driven pilot registry is missing %s: %s" % [required_id, registry])
			return

	_expected_commit_seat_id = FIRST_SEAT_ID
	_seat_commit_observed = false
	_attachment_inactive_when_seat_committed = false
	var start_result: Dictionary = npc_system.debug_run_formal_navigation_pilot(PILOT_ID)
	if not _validate_start_result(start_result, FIRST_SEAT_ID):
		_fail("Dining pilot did not select the first free seat: %s" % start_result)
		return
	if not await _wait_for_phase(npc_system, "occupant_attached", FIRST_SEAT_ID):
		_fail("Bruno did not reach and attach to the first dining seat: %s" % npc_system.debug_get_dining_navigation_pilot_snapshot())
		return
	await process_frame
	var first_snapshot: Dictionary = npc_system.debug_get_dining_navigation_pilot_snapshot()
	var first_attachment: Dictionary = first_snapshot.get("attachment", {})
	var first_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	if (
		not _seat_commit_observed
		or not _attachment_inactive_when_seat_committed
		or not bool(first_attachment.get("active", false))
		or str(first_attachment.get("pose", "")) != "sitting"
		or not bool(first_attachment.get("body_collision_disabled", false))
		or not bool(first_attachment.get("interaction_enabled", false))
		or str(first_snapshot.get("logical_location_id", "")) != BUILDING_ID
		or str(first_snapshot.get("physical_location_phase", "")) != "occupant_anchor"
		or str(first_state.get("current_action", "")) != "idle"
		or not _workstation_owned_by(FIRST_SEAT_ID, NPC_ID)
	):
		_fail("Dining commit / sitting attachment / no-eating-action contract failed: %s" % first_snapshot)
		return

	npc_system.debug_stop_formal_navigation_pilot(PILOT_ID, "stop_verified")
	await process_frame
	if not _workstation_is_clear(FIRST_SEAT_ID) or bool(_npc.debug_get_spatial_attachment_snapshot().get("active", false)):
		_fail("Explicit stop left a dining-seat claim or attachment")
		return

	var blocker_reservation: Dictionary = _building_system.reserve_workstation(BUILDING_ID, BLOCKER_NPC_ID, "dining_seat")
	if str(blocker_reservation.get("workstation_id", "")) != FIRST_SEAT_ID:
		_fail("Could not reserve dining_seat_01 for first-free selection test: %s" % blocker_reservation)
		return
	var blocker_commit: Dictionary = _building_system.commit_workstation_reservation(BUILDING_ID, BLOCKER_NPC_ID, FIRST_SEAT_ID, "dining_seat")
	if not bool(blocker_commit.get("ok", false)):
		_fail("Could not occupy dining_seat_01 for first-free selection test: %s" % blocker_commit)
		return
	_expected_commit_seat_id = SECOND_SEAT_ID
	var second_start: Dictionary = npc_system.debug_run_formal_navigation_pilot(PILOT_ID)
	if not _validate_start_result(second_start, SECOND_SEAT_ID):
		_fail("Dining pilot did not skip occupied seat 01 and select seat 02: %s" % second_start)
		return
	if not await _wait_for_phase(npc_system, "occupant_attached", SECOND_SEAT_ID):
		_fail("Bruno did not attach to the second free dining seat")
		return
	npc_system.debug_stop_formal_navigation_pilot(PILOT_ID, "first_free_verified")
	await process_frame
	if not _workstation_owned_by(FIRST_SEAT_ID, BLOCKER_NPC_ID) or not _workstation_is_clear(SECOND_SEAT_ID):
		_fail("Pilot cleanup altered another NPC's seat or left seat 02 occupied")
		return
	_building_system.release_workstation(BUILDING_ID, BLOCKER_NPC_ID, FIRST_SEAT_ID)

	_expected_commit_seat_id = FIRST_SEAT_ID
	var failure_start: Dictionary = npc_system.debug_run_formal_navigation_pilot(PILOT_ID)
	if not bool(failure_start.get("ok", false)):
		_fail("Dining unreachable-path pilot did not start: %s" % failure_start)
		return
	await physics_frame
	if not _npc.request_motion(Vector3(900.0, _npc.global_position.y, 60.0), "forced_dining_unreachable"):
		_fail("Could not inject an unreachable dining target")
		return
	if not await _wait_for_phase(npc_system, "navigation_failed", "", 720):
		_fail("Unreachable dining target did not settle")
		return
	if not _workstation_is_clear(FIRST_SEAT_ID) or bool(_npc.debug_get_spatial_attachment_snapshot().get("active", false)):
		_fail("Unreachable dining target left a reservation or attachment")
		return
	npc_system.debug_stop_formal_navigation_pilot(PILOT_ID, "unreachable_verified")

	var supersede_start: Dictionary = npc_system.debug_run_formal_navigation_pilot(PILOT_ID)
	if not bool(supersede_start.get("ok", false)) or not await _wait_for_phase(npc_system, "occupant_attached", FIRST_SEAT_ID):
		_fail("Dining supersession pilot did not reach seat 01")
		return
	var glen_result: Dictionary = npc_system.debug_run_formal_navigation_pilot("glen")
	await process_frame
	if (
		not bool(glen_result.get("ok", false))
		or not _workstation_is_clear(FIRST_SEAT_ID)
		or bool(_npc.debug_get_spatial_attachment_snapshot().get("active", false))
		or bool(npc_system.debug_get_dining_navigation_pilot_snapshot().get("active", false))
	):
		_fail("Data-driven pilot supersession did not atomically restore Bruno")
		return
	npc_system.debug_stop_all_formal_navigation_pilots("supersession_verified")

	var unavailable_start: Dictionary = npc_system.debug_run_formal_navigation_pilot(PILOT_ID)
	if not bool(unavailable_start.get("ok", false)) or not await _wait_for_phase(npc_system, "occupant_attached", FIRST_SEAT_ID):
		_fail("Dining building-unavailable pilot did not reach seat 01")
		return
	var dining_before_damage: Dictionary = _building_system.get_building(BUILDING_ID)
	var max_hp := int(dining_before_damage.get("max_hp", 110))
	_building_system.debug_damage_building(BUILDING_ID, max_hp)
	await process_frame
	if (
		bool(npc_system.debug_get_dining_navigation_pilot_snapshot().get("active", false))
		or not _workstation_is_clear(FIRST_SEAT_ID)
		or bool(_npc.debug_get_spatial_attachment_snapshot().get("active", false))
	):
		_fail("Building unavailability did not clear Bruno's dining pilot")
		return
	_building_system.restore_building_hp(BUILDING_ID, max_hp)
	await process_frame

	var unconscious_start: Dictionary = npc_system.debug_run_formal_navigation_pilot(PILOT_ID)
	if not bool(unconscious_start.get("ok", false)) or not await _wait_for_phase(npc_system, "occupant_attached", FIRST_SEAT_ID):
		_fail("Dining unconscious-path pilot did not reach seat 01")
		return
	var before_damage: Dictionary = npc_system.get_npc_state(NPC_ID)
	var damage_result: Dictionary = npc_system.debug_damage_npc(NPC_ID, int(before_damage.get("max_hp", 100)))
	await process_frame
	var after_damage: Dictionary = npc_system.get_npc_state(NPC_ID)
	if (
		not bool(damage_result.get("unconscious", false))
		or bool(npc_system.debug_get_dining_navigation_pilot_snapshot().get("active", false))
		or not _workstation_is_clear(FIRST_SEAT_ID)
		or bool(_npc.debug_get_spatial_attachment_snapshot().get("active", false))
		or _npc.is_navigation_motion_enabled()
		or str(after_damage.get("current_action", "")) != "unconscious"
	):
		_fail("Unconscious interruption did not atomically clear Bruno's dining pilot")
		return

	print("T0129C A2b-P4 dining formal navigation verification passed: %s" % JSON.stringify({
		"pilot_registry_size": registered_ids.size(),
		"first_free_seat": FIRST_SEAT_ID,
		"occupied_first_selects": SECOND_SEAT_ID,
		"commit_before_attachment": _attachment_inactive_when_seat_committed,
		"occupant_pose": "sitting",
		"stop_cleanup": true,
		"unreachable_cleanup": true,
		"supersession_cleanup": true,
		"building_unavailable_cleanup": true,
		"unconscious_cleanup": true
	}))
	quit(0)


func _validate_start_result(result: Dictionary, expected_seat_id: String) -> bool:
	return (
		bool(result.get("ok", false))
		and str(result.get("pilot_id", "")) == PILOT_ID
		and str(result.get("workstation_id", "")) == expected_seat_id
		and str(result.get("workstation_type", "")) == "dining_seat"
		and str(result.get("expected_workstation_id", "")) == ""
		and str(result.get("arrival_mode", "")) == "mount_after_arrival"
		and str(result.get("occupant_pose", "")) == "sitting"
	)


func _wait_for_phase(npc_system: Node, phase: String, workstation_id: String, frame_limit: int = 1800) -> bool:
	for _frame in range(frame_limit):
		await physics_frame
		var state: Dictionary = npc_system.get_npc_state(NPC_ID)
		if str(state.get("spatial_route_phase", "")) == "navigation_failed" and phase != "navigation_failed":
			return false
		if str(state.get("spatial_route_phase", "")) != phase:
			continue
		if workstation_id.is_empty() or str(state.get("current_workstation_id", "")) == workstation_id:
			return true
	return false


func _on_building_state_changed(changed_building_id: String) -> void:
	if changed_building_id != BUILDING_ID or _building_system == null or _npc == null:
		return
	if _expected_commit_seat_id.is_empty() or not _workstation_owned_by(_expected_commit_seat_id, NPC_ID):
		return
	_seat_commit_observed = true
	_attachment_inactive_when_seat_committed = not bool(_npc.debug_get_spatial_attachment_snapshot().get("active", false))


func _workstation_owned_by(workstation_id: String, npc_id: String) -> bool:
	var workstation := _find_workstation(_building_system.get_building(BUILDING_ID), workstation_id)
	return str(workstation.get("occupied_by", "")) == npc_id and _clean_nullable_id(workstation.get("reserved_by", "")).is_empty()


func _workstation_is_clear(workstation_id: String) -> bool:
	var workstation := _find_workstation(_building_system.get_building(BUILDING_ID), workstation_id)
	return _clean_nullable_id(workstation.get("occupied_by", "")).is_empty() and _clean_nullable_id(workstation.get("reserved_by", "")).is_empty()


func _find_workstation(building: Dictionary, workstation_id: String) -> Dictionary:
	for raw_workstation in building.get("workstations", []):
		if raw_workstation is Dictionary and str((raw_workstation as Dictionary).get("id", "")) == workstation_id:
			return (raw_workstation as Dictionary).duplicate(true)
	return {}


func _clean_nullable_id(value: Variant) -> String:
	return "" if value == null else str(value).strip_edges()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
