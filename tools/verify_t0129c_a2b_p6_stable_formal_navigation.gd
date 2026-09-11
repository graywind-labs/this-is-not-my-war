extends SceneTree

const PILOT_ID := "stable_care"
const NPC_ID := "stableman_01"
const BUILDING_ID := "stable"
const FIRST_STALL_ID := "stall_01"
const SECOND_STALL_ID := "stall_02"
const BLOCKER_NPC_ID := "doctor_01"

var _building_system: Node
var _formal_layout_root: Node
var _npc: CharacterBody3D
var _expected_commit_stall_id := ""
var _stall_commit_observed := false
var _attachment_inactive_when_stall_committed := false
var _commit_horse_clearance := 0.0


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
	var layout_controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	_formal_layout_root = root.get_node_or_null("Main/WorldRoot/FormalStationLayout")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var event_bus := root.get_node_or_null("EventBus")
	_npc = root.get_node_or_null("Main/WorldRoot/Station/NPCs/Stableman01") as CharacterBody3D
	if npc_system == null or _building_system == null or layout_controller == null or _formal_layout_root == null or _npc == null or event_bus == null:
		_fail("A2b-P6 runtime dependencies unavailable")
		return
	if time_system != null and time_system.has_method("set_paused"):
		time_system.set_paused(false)
	_npc.move_speed = 12.0
	if event_bus.has_signal("building_state_changed"):
		event_bus.building_state_changed.connect(_on_building_state_changed)

	var registry: Dictionary = npc_system.debug_get_formal_navigation_pilots_snapshot()
	var registered_ids: Array = registry.get("registered_pilot_ids", [])
	for required_id in ["glen", "clinic_doctor", "clinic_bed", "dormitory_bed", "dining_seat", "chapel_prayer_seat", PILOT_ID]:
		if required_id not in registered_ids:
			_fail("Data-driven pilot registry is missing %s: %s" % [required_id, registry])
			return

	_expected_commit_stall_id = FIRST_STALL_ID
	_reset_commit_observation()
	var start_result: Dictionary = npc_system.debug_run_formal_navigation_pilot(PILOT_ID)
	if not _validate_start_result(start_result, FIRST_STALL_ID):
		_fail("Stable pilot did not select the first free care position: %s" % start_result)
		return
	if not await _wait_for_phase(npc_system, "workstation_arrived", FIRST_STALL_ID):
		_fail("Toma did not reach the first stable care position: %s" % npc_system.debug_get_stable_navigation_pilot_snapshot())
		return
	await process_frame
	var first_snapshot: Dictionary = npc_system.debug_get_stable_navigation_pilot_snapshot()
	var first_attachment: Dictionary = first_snapshot.get("attachment", {})
	var first_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	if (
		not _stall_commit_observed
		or not _attachment_inactive_when_stall_committed
		or _commit_horse_clearance < 1.5
		or bool(first_attachment.get("active", false))
		or bool(first_attachment.get("body_collision_disabled", false))
		or str(first_snapshot.get("logical_location_id", "")) != BUILDING_ID
		or str(first_snapshot.get("physical_location_phase", "")) != "workstation"
		or str(first_state.get("current_action", "")) != "idle"
		or not _workstation_owned_by(FIRST_STALL_ID, NPC_ID)
	):
		_fail("Stable commit / horse-clearance / no-work-action contract failed (commit=%s, no_attachment=%s, clearance=%.3f): %s" % [
			_stall_commit_observed,
			_attachment_inactive_when_stall_committed,
			_commit_horse_clearance,
			first_snapshot
		])
		return

	npc_system.debug_stop_formal_navigation_pilot(PILOT_ID, "stop_verified")
	await process_frame
	if not _workstation_is_clear(FIRST_STALL_ID) or bool(_npc.debug_get_spatial_attachment_snapshot().get("active", false)):
		_fail("Explicit stop left a stable care-position claim or attachment")
		return

	var blocker_reservation: Dictionary = _building_system.reserve_workstation(BUILDING_ID, BLOCKER_NPC_ID, "horse_care")
	if str(blocker_reservation.get("workstation_id", "")) != FIRST_STALL_ID:
		_fail("Could not reserve stall_01 for first-free selection test: %s" % blocker_reservation)
		return
	var blocker_commit: Dictionary = _building_system.commit_workstation_reservation(BUILDING_ID, BLOCKER_NPC_ID, FIRST_STALL_ID, "horse_care")
	if not bool(blocker_commit.get("ok", false)):
		_fail("Could not occupy stall_01 for first-free selection test: %s" % blocker_commit)
		return
	_expected_commit_stall_id = SECOND_STALL_ID
	_reset_commit_observation()
	var second_start: Dictionary = npc_system.debug_run_formal_navigation_pilot(PILOT_ID)
	if not _validate_start_result(second_start, SECOND_STALL_ID):
		_fail("Stable pilot did not skip occupied stall 01 and select stall 02: %s" % second_start)
		return
	if not await _wait_for_phase(npc_system, "workstation_arrived", SECOND_STALL_ID):
		_fail("Toma did not reach the second free stable care position")
		return
	if not _stall_commit_observed or _commit_horse_clearance < 1.5:
		_fail("Second stable care position did not preserve horse clearance")
		return
	npc_system.debug_stop_formal_navigation_pilot(PILOT_ID, "first_free_verified")
	await process_frame
	if not _workstation_owned_by(FIRST_STALL_ID, BLOCKER_NPC_ID) or not _workstation_is_clear(SECOND_STALL_ID):
		_fail("Pilot cleanup altered another NPC's stall or left stall 02 occupied")
		return
	_building_system.release_workstation(BUILDING_ID, BLOCKER_NPC_ID, FIRST_STALL_ID)

	_expected_commit_stall_id = FIRST_STALL_ID
	var failure_start: Dictionary = npc_system.debug_run_formal_navigation_pilot(PILOT_ID)
	if not bool(failure_start.get("ok", false)):
		_fail("Stable unreachable-path pilot did not start: %s" % failure_start)
		return
	await physics_frame
	if not _npc.request_motion(Vector3(900.0, _npc.global_position.y, 60.0), "forced_stable_unreachable"):
		_fail("Could not inject an unreachable stable target")
		return
	if not await _wait_for_phase(npc_system, "navigation_failed", "", 720):
		_fail("Unreachable stable target did not settle")
		return
	if not _workstation_is_clear(FIRST_STALL_ID) or bool(_npc.debug_get_spatial_attachment_snapshot().get("active", false)):
		_fail("Unreachable stable target left a reservation or attachment")
		return
	npc_system.debug_stop_formal_navigation_pilot(PILOT_ID, "unreachable_verified")

	var supersede_start: Dictionary = npc_system.debug_run_formal_navigation_pilot(PILOT_ID)
	if not bool(supersede_start.get("ok", false)) or not await _wait_for_phase(npc_system, "workstation_arrived", FIRST_STALL_ID):
		_fail("Stable supersession pilot did not reach stall 01")
		return
	var glen_result: Dictionary = npc_system.debug_run_formal_navigation_pilot("glen")
	await process_frame
	if (
		not bool(glen_result.get("ok", false))
		or not _workstation_is_clear(FIRST_STALL_ID)
		or bool(_npc.debug_get_spatial_attachment_snapshot().get("active", false))
		or bool(npc_system.debug_get_stable_navigation_pilot_snapshot().get("active", false))
	):
		_fail("Data-driven pilot supersession did not atomically restore Toma")
		return
	npc_system.debug_stop_all_formal_navigation_pilots("supersession_verified")

	var unavailable_start: Dictionary = npc_system.debug_run_formal_navigation_pilot(PILOT_ID)
	if not bool(unavailable_start.get("ok", false)) or not await _wait_for_phase(npc_system, "workstation_arrived", FIRST_STALL_ID):
		_fail("Stable building-unavailable pilot did not reach stall 01")
		return
	var stable_before_damage: Dictionary = _building_system.get_building(BUILDING_ID)
	var max_hp := int(stable_before_damage.get("max_hp", 110))
	_building_system.debug_damage_building(BUILDING_ID, max_hp)
	await process_frame
	if bool(npc_system.debug_get_stable_navigation_pilot_snapshot().get("active", false)) or not _workstation_is_clear(FIRST_STALL_ID):
		_fail("Building unavailability did not clear Toma's stable pilot")
		return
	_building_system.restore_building_hp(BUILDING_ID, max_hp)
	await process_frame

	var unconscious_start: Dictionary = npc_system.debug_run_formal_navigation_pilot(PILOT_ID)
	if not bool(unconscious_start.get("ok", false)) or not await _wait_for_phase(npc_system, "workstation_arrived", FIRST_STALL_ID):
		_fail("Stable unconscious-path pilot did not reach stall 01")
		return
	var before_damage: Dictionary = npc_system.get_npc_state(NPC_ID)
	var damage_result: Dictionary = npc_system.debug_damage_npc(NPC_ID, int(before_damage.get("max_hp", 100)))
	await process_frame
	var after_damage: Dictionary = npc_system.get_npc_state(NPC_ID)
	if (
		not bool(damage_result.get("unconscious", false))
		or bool(npc_system.debug_get_stable_navigation_pilot_snapshot().get("active", false))
		or not _workstation_is_clear(FIRST_STALL_ID)
		or _npc.is_navigation_motion_enabled()
		or str(after_damage.get("current_action", "")) != "unconscious"
	):
		_fail("Unconscious interruption did not atomically clear Toma's stable pilot")
		return

	print("T0129C A2b-P6 stable formal navigation verification passed: %s" % JSON.stringify({
		"pilot_registry_size": registered_ids.size(),
		"first_free_stall": FIRST_STALL_ID,
		"occupied_first_selects": SECOND_STALL_ID,
		"arrival_mode": "stand",
		"minimum_observed_horse_clearance": _commit_horse_clearance,
		"work_action_started": false,
		"stop_cleanup": true,
		"unreachable_cleanup": true,
		"supersession_cleanup": true,
		"building_unavailable_cleanup": true,
		"unconscious_cleanup": true
	}))
	quit(0)


func _validate_start_result(result: Dictionary, expected_stall_id: String) -> bool:
	return (
		bool(result.get("ok", false))
		and str(result.get("pilot_id", "")) == PILOT_ID
		and str(result.get("workstation_id", "")) == expected_stall_id
		and str(result.get("workstation_type", "")) == "horse_care"
		and str(result.get("expected_workstation_id", "")) == ""
		and str(result.get("arrival_mode", "")) == "stand"
		and str(result.get("occupant_pose", "")) == ""
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


func _reset_commit_observation() -> void:
	_stall_commit_observed = false
	_attachment_inactive_when_stall_committed = false
	_commit_horse_clearance = 0.0


func _on_building_state_changed(changed_building_id: String) -> void:
	if changed_building_id != BUILDING_ID or _building_system == null or _npc == null:
		return
	if _expected_commit_stall_id.is_empty() or not _workstation_owned_by(_expected_commit_stall_id, NPC_ID):
		return
	_stall_commit_observed = true
	_attachment_inactive_when_stall_committed = not bool(_npc.debug_get_spatial_attachment_snapshot().get("active", false))
	var horse_anchor := _find_horse_anchor(_expected_commit_stall_id)
	if horse_anchor != null:
		var delta := _npc.global_position - horse_anchor.global_position
		delta.y = 0.0
		_commit_horse_clearance = delta.length()


func _find_horse_anchor(workstation_id: String) -> Marker3D:
	for raw_node in _formal_layout_root.find_children("*", "Marker3D", true, false):
		var marker := raw_node as Marker3D
		if marker != null and str(marker.get_meta("building_id", "")) == BUILDING_ID and str(marker.get_meta("horse_anchor_id", "")) == workstation_id:
			return marker
	return null


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
