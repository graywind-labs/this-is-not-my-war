extends SceneTree

const NPC_ID := "doctor_01"
const BUILDING_ID := "clinic"
const DOCTOR_WORKSTATION_ID := "doctor_desk_01"
const BED_WORKSTATION_ID := "treatment_bed_01"

var _building_system: Node
var _npc: CharacterBody3D
var _bed_commit_observed := false
var _attachment_inactive_when_bed_committed := false


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
	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	_npc = root.get_node_or_null("Main/WorldRoot/Station/NPCs/Doctor01") as CharacterBody3D
	var event_bus := root.get_node_or_null("EventBus")
	if npc_system == null or _building_system == null or controller == null or _npc == null or event_bus == null:
		_fail("A2b-P2 runtime dependencies unavailable")
		return
	if time_system != null and time_system.has_method("set_paused"):
		time_system.set_paused(false)
	_npc.move_speed = 5.0
	if event_bus.has_signal("building_state_changed"):
		event_bus.building_state_changed.connect(_on_building_state_changed)

	var doctor_result: Dictionary = npc_system.debug_run_clinic_navigation_pilot("doctor")
	if (
		not bool(doctor_result.get("ok", false))
		or str(doctor_result.get("workstation_id", "")) != DOCTOR_WORKSTATION_ID
		or str(doctor_result.get("arrival_mode", "")) != "mount_after_arrival"
		or str(doctor_result.get("occupant_pose", "")) != "seated_study"
	):
		_fail("Clinic doctor pilot did not start on the first doctor station: %s" % doctor_result)
		return
	if not await _wait_for_phase(npc_system, "occupant_attached", DOCTOR_WORKSTATION_ID):
		_fail("Lina did not reach the clinic doctor station: %s" % npc_system.debug_get_clinic_navigation_pilot_snapshot())
		return
	var doctor_snapshot: Dictionary = npc_system.debug_get_clinic_navigation_pilot_snapshot()
	var doctor_attachment: Dictionary = doctor_snapshot.get("attachment", {})
	if (
		not bool(doctor_attachment.get("active", false))
		or not bool(doctor_attachment.get("body_collision_disabled", false))
		or str(doctor_attachment.get("pose", "")) != "seated_study"
		or str(doctor_snapshot.get("logical_location_id", "")) != BUILDING_ID
	):
		_fail("Seated-study doctor station did not mount correctly or lost clinic authority: %s" % doctor_snapshot)
		return
	if not _workstation_owned_by(DOCTOR_WORKSTATION_ID, NPC_ID):
		_fail("Doctor station was not committed after physical arrival")
		return
	npc_system.debug_stop_clinic_navigation_pilot("doctor_verified")
	await process_frame
	if not _workstation_is_clear(DOCTOR_WORKSTATION_ID):
		_fail("Doctor pilot cleanup left a ghost doctor-station claim")
		return

	_bed_commit_observed = false
	_attachment_inactive_when_bed_committed = false
	var bed_result: Dictionary = npc_system.debug_run_clinic_navigation_pilot("bed")
	if (
		not bool(bed_result.get("ok", false))
		or str(bed_result.get("workstation_id", "")) != BED_WORKSTATION_ID
		or str(bed_result.get("arrival_mode", "")) != "mount_after_arrival"
	):
		_fail("Clinic bed pilot did not start on the first patient bed: %s" % bed_result)
		return
	if not await _wait_for_phase(npc_system, "occupant_attached", BED_WORKSTATION_ID):
		_fail("Lina did not complete bed-side arrival and occupant attachment: %s" % npc_system.debug_get_clinic_navigation_pilot_snapshot())
		return
	await process_frame
	var bed_route: Dictionary = controller.get_building_spatial_route(BUILDING_ID, BED_WORKSTATION_ID)
	var bed_snapshot: Dictionary = npc_system.debug_get_clinic_navigation_pilot_snapshot()
	var bed_attachment: Dictionary = bed_snapshot.get("attachment", {})
	var expected_anchor: Vector3 = bed_route.get("occupant_anchor_position", Vector3.ZERO)
	if (
		not _bed_commit_observed
		or not _attachment_inactive_when_bed_committed
		or not bool(bed_attachment.get("active", false))
		or str(bed_attachment.get("pose", "")) != "lying_supine"
		or not bool(bed_attachment.get("body_collision_disabled", false))
		or not bool(bed_attachment.get("interaction_enabled", false))
		or _npc.global_position.distance_to(expected_anchor) > 0.001
		or str(bed_snapshot.get("physical_location_phase", "")) != "occupant_anchor"
	):
		_fail("Bed transaction did not preserve commit-before-attachment semantics: %s" % bed_snapshot)
		return
	if not _workstation_owned_by(BED_WORKSTATION_ID, NPC_ID):
		_fail("Patient bed was not occupied after attachment")
		return
	npc_system.debug_stop_clinic_navigation_pilot("bed_verified")
	await process_frame
	if not _workstation_is_clear(BED_WORKSTATION_ID):
		_fail("Bed pilot cleanup left a ghost claim")
		return
	var detached: Dictionary = _npc.debug_get_spatial_attachment_snapshot()
	if bool(detached.get("active", false)) or bool(detached.get("body_collision_disabled", false)):
		_fail("Bed cleanup did not restore the CharacterBody collision: %s" % detached)
		return

	var failure_result: Dictionary = npc_system.debug_run_clinic_navigation_pilot("bed")
	if not bool(failure_result.get("ok", false)):
		_fail("Clinic failure-path pilot did not start: %s" % failure_result)
		return
	await physics_frame
	if not _npc.request_motion(Vector3(900.0, _npc.global_position.y, 60.0), "forced_clinic_unreachable"):
		_fail("Could not inject an unreachable clinic target")
		return
	if not await _wait_for_phase(npc_system, "navigation_failed", "", 720):
		_fail("Unreachable clinic target did not settle")
		return
	if not _workstation_is_clear(BED_WORKSTATION_ID) or bool(_npc.debug_get_spatial_attachment_snapshot().get("active", false)):
		_fail("Unreachable clinic target left a reservation or attachment")
		return
	npc_system.debug_stop_clinic_navigation_pilot("unreachable_verified")

	var unconscious_result: Dictionary = npc_system.debug_run_clinic_navigation_pilot("bed")
	if not bool(unconscious_result.get("ok", false)):
		_fail("Clinic unconscious-path pilot did not start: %s" % unconscious_result)
		return
	if not await _wait_for_phase(npc_system, "occupant_attached", BED_WORKSTATION_ID):
		_fail("Clinic unconscious-path pilot did not reach the bed")
		return
	var before_damage: Dictionary = npc_system.get_npc_state(NPC_ID)
	var damage_result: Dictionary = npc_system.debug_damage_npc(NPC_ID, int(before_damage.get("max_hp", 100)))
	await process_frame
	var after_damage: Dictionary = npc_system.get_npc_state(NPC_ID)
	if (
		not bool(damage_result.get("unconscious", false))
		or bool(npc_system.debug_get_clinic_navigation_pilot_snapshot().get("active", false))
		or not _workstation_is_clear(BED_WORKSTATION_ID)
		or bool(_npc.debug_get_spatial_attachment_snapshot().get("active", false))
		or _npc.is_navigation_motion_enabled()
		or str(after_damage.get("current_action", "")) != "unconscious"
	):
		_fail("Unconscious interruption did not atomically clear the clinic pilot: %s" % npc_system.debug_get_clinic_navigation_pilot_snapshot())
		return

	await process_frame
	await process_frame
	print("T0129C A2b-P2 clinic formal navigation verification passed: %s" % JSON.stringify({
		"doctor_station": DOCTOR_WORKSTATION_ID,
		"bed": BED_WORKSTATION_ID,
		"commit_before_attachment": _attachment_inactive_when_bed_committed,
		"occupant_pose": str(bed_attachment.get("pose", "")),
		"unreachable_cleanup": true,
		"unconscious_cleanup": true
	}))
	quit(0)


func _wait_for_phase(npc_system: Node, phase: String, workstation_id: String, frame_limit: int = 1800) -> bool:
	for _frame in range(frame_limit):
		await physics_frame
		var state: Dictionary = npc_system.get_npc_state(NPC_ID)
		if str(state.get("spatial_route_phase", "")) != phase:
			continue
		if workstation_id.is_empty() or str(state.get("current_workstation_id", "")) == workstation_id:
			return true
	return false


func _on_building_state_changed(changed_building_id: String) -> void:
	if changed_building_id != BUILDING_ID or _building_system == null or _npc == null:
		return
	if not _workstation_owned_by(BED_WORKSTATION_ID, NPC_ID):
		return
	_bed_commit_observed = true
	_attachment_inactive_when_bed_committed = not bool(_npc.debug_get_spatial_attachment_snapshot().get("active", false))


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
