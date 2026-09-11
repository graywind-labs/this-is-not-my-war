extends SceneTree

const PILOT_ID := "dormitory_bed"
const NPC_ID := "veteran_deputy_01"
const BUILDING_ID := "dormitory"
const BED_WORKSTATION_ID := "dormitory_bed_01"

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
	_npc = root.get_node_or_null("Main/WorldRoot/Station/NPCs/VeteranDeputy01") as CharacterBody3D
	var event_bus := root.get_node_or_null("EventBus")
	if npc_system == null or _building_system == null or controller == null or _npc == null or event_bus == null:
		_fail("A2b-P3 runtime dependencies unavailable")
		return
	if time_system != null and time_system.has_method("set_paused"):
		time_system.set_paused(false)
	_npc.move_speed = 5.0
	if event_bus.has_signal("building_state_changed"):
		event_bus.building_state_changed.connect(_on_building_state_changed)

	var registry: Dictionary = npc_system.debug_get_formal_navigation_pilots_snapshot()
	var registered_ids: Array = registry.get("registered_pilot_ids", [])
	for required_id in ["glen", "clinic_doctor", "clinic_bed", PILOT_ID]:
		if required_id not in registered_ids:
			_fail("Data-driven pilot registry is missing %s: %s" % [required_id, registry])
			return

	var bed_definition := _find_workstation(_building_system.get_building(BUILDING_ID), BED_WORKSTATION_ID)
	if str(bed_definition.get("assigned_npc_id", "")) != NPC_ID:
		_fail("BuildingSystem does not assign Ada to dormitory_bed_01: %s" % bed_definition)
		return

	_bed_commit_observed = false
	_attachment_inactive_when_bed_committed = false
	var start_result: Dictionary = npc_system.debug_run_formal_navigation_pilot(PILOT_ID)
	if (
		not bool(start_result.get("ok", false))
		or str(start_result.get("pilot_id", "")) != PILOT_ID
		or str(start_result.get("workstation_id", "")) != BED_WORKSTATION_ID
		or str(start_result.get("expected_workstation_id", "")) != BED_WORKSTATION_ID
		or str(start_result.get("arrival_mode", "")) != "mount_after_arrival"
		or str(start_result.get("occupant_pose", "")) != "sleeping_supine"
	):
		_fail("Dormitory pilot did not select Ada's assigned bed: %s" % start_result)
		return
	if not await _wait_for_phase(npc_system, "occupant_attached", BED_WORKSTATION_ID):
		var failed_route: Dictionary = controller.get_building_spatial_route(BUILDING_ID, BED_WORKSTATION_ID)
		var failed_map: RID = controller.get_production_navigation_map_rid()
		var failed_path := NavigationServer3D.map_get_path(
			failed_map,
			_npc.global_position,
			failed_route.get("interior_target_position", Vector3.ZERO),
			true
		)
		_fail("Ada did not reach and attach to her assigned dormitory bed; direct path=%s snapshot=%s" % [failed_path, npc_system.debug_get_dormitory_navigation_pilot_snapshot()])
		return
	await process_frame
	var route: Dictionary = controller.get_building_spatial_route(BUILDING_ID, BED_WORKSTATION_ID)
	var snapshot: Dictionary = npc_system.debug_get_dormitory_navigation_pilot_snapshot()
	var attachment: Dictionary = snapshot.get("attachment", {})
	var expected_anchor: Vector3 = route.get("occupant_anchor_position", Vector3.ZERO)
	var state: Dictionary = npc_system.get_npc_state(NPC_ID)
	if (
		not _bed_commit_observed
		or not _attachment_inactive_when_bed_committed
		or not bool(attachment.get("active", false))
		or str(attachment.get("pose", "")) != "sleeping_supine"
		or not bool(attachment.get("body_collision_disabled", false))
		or not bool(attachment.get("interaction_enabled", false))
		or _npc.global_position.distance_to(expected_anchor) > 0.001
		or str(snapshot.get("logical_location_id", "")) != BUILDING_ID
		or str(snapshot.get("physical_location_phase", "")) != "occupant_anchor"
		or str(state.get("current_action", "")) != "idle"
	):
		_fail("Dormitory commit / attachment / no-sleep-action contract failed: %s" % snapshot)
		return
	if not _workstation_owned_by(BED_WORKSTATION_ID, NPC_ID):
		_fail("Ada's assigned bed was not occupied after physical attachment")
		return

	npc_system.debug_stop_formal_navigation_pilot(PILOT_ID, "stop_verified")
	await process_frame
	if not _workstation_is_clear(BED_WORKSTATION_ID) or bool(_npc.debug_get_spatial_attachment_snapshot().get("active", false)):
		_fail("Explicit stop left a dormitory bed claim or attachment")
		return
	if bool(_npc.debug_get_spatial_attachment_snapshot().get("body_collision_disabled", false)):
		_fail("Explicit stop did not restore Ada's CharacterBody collision")
		return

	var failure_result: Dictionary = npc_system.debug_run_formal_navigation_pilot(PILOT_ID)
	if not bool(failure_result.get("ok", false)):
		_fail("Dormitory unreachable-path pilot did not start: %s" % failure_result)
		return
	await physics_frame
	if not _npc.request_motion(Vector3(900.0, _npc.global_position.y, 60.0), "forced_dormitory_unreachable"):
		_fail("Could not inject an unreachable dormitory target")
		return
	if not await _wait_for_phase(npc_system, "navigation_failed", "", 720):
		_fail("Unreachable dormitory target did not settle")
		return
	if not _workstation_is_clear(BED_WORKSTATION_ID) or bool(_npc.debug_get_spatial_attachment_snapshot().get("active", false)):
		_fail("Unreachable dormitory target left a reservation or attachment")
		return
	npc_system.debug_stop_formal_navigation_pilot(PILOT_ID, "unreachable_verified")

	var supersede_result: Dictionary = npc_system.debug_run_formal_navigation_pilot(PILOT_ID)
	if not bool(supersede_result.get("ok", false)) or not await _wait_for_phase(npc_system, "occupant_attached", BED_WORKSTATION_ID):
		_fail("Dormitory supersession-path pilot did not reach Ada's bed")
		return
	var glen_result: Dictionary = npc_system.debug_run_formal_navigation_pilot("glen")
	await process_frame
	if (
		not bool(glen_result.get("ok", false))
		or not _workstation_is_clear(BED_WORKSTATION_ID)
		or bool(_npc.debug_get_spatial_attachment_snapshot().get("active", false))
		or bool(npc_system.debug_get_dormitory_navigation_pilot_snapshot().get("active", false))
	):
		_fail("Data-driven pilot supersession did not atomically restore Ada: %s" % registry)
		return
	npc_system.debug_stop_all_formal_navigation_pilots("supersession_verified")

	var unavailable_result: Dictionary = npc_system.debug_run_formal_navigation_pilot(PILOT_ID)
	if not bool(unavailable_result.get("ok", false)) or not await _wait_for_phase(npc_system, "occupant_attached", BED_WORKSTATION_ID):
		_fail("Dormitory building-unavailable pilot did not reach Ada's bed")
		return
	var dormitory_before_damage: Dictionary = _building_system.get_building(BUILDING_ID)
	var max_hp := int(dormitory_before_damage.get("max_hp", 120))
	_building_system.debug_damage_building(BUILDING_ID, max_hp)
	await process_frame
	if (
		bool(npc_system.debug_get_dormitory_navigation_pilot_snapshot().get("active", false))
		or not _workstation_is_clear(BED_WORKSTATION_ID)
		or bool(_npc.debug_get_spatial_attachment_snapshot().get("active", false))
	):
		_fail("Building unavailability did not clear Ada's formal pilot")
		return
	_building_system.restore_building_hp(BUILDING_ID, max_hp)
	await process_frame

	var unconscious_result: Dictionary = npc_system.debug_run_formal_navigation_pilot(PILOT_ID)
	if not bool(unconscious_result.get("ok", false)) or not await _wait_for_phase(npc_system, "occupant_attached", BED_WORKSTATION_ID):
		_fail("Dormitory unconscious-path pilot did not reach Ada's bed")
		return
	var before_damage: Dictionary = npc_system.get_npc_state(NPC_ID)
	var damage_result: Dictionary = npc_system.debug_damage_npc(NPC_ID, int(before_damage.get("max_hp", 100)))
	await process_frame
	var after_damage: Dictionary = npc_system.get_npc_state(NPC_ID)
	if (
		not bool(damage_result.get("unconscious", false))
		or bool(npc_system.debug_get_dormitory_navigation_pilot_snapshot().get("active", false))
		or not _workstation_is_clear(BED_WORKSTATION_ID)
		or bool(_npc.debug_get_spatial_attachment_snapshot().get("active", false))
		or _npc.is_navigation_motion_enabled()
		or str(after_damage.get("current_action", "")) != "unconscious"
	):
		_fail("Unconscious interruption did not atomically clear Ada's dormitory pilot")
		return

	await process_frame
	print("T0129C A2b-P3 dormitory formal navigation verification passed: %s" % JSON.stringify({
		"pilot_registry_size": registered_ids.size(),
		"assigned_bed": BED_WORKSTATION_ID,
		"commit_before_attachment": _attachment_inactive_when_bed_committed,
		"occupant_pose": str(attachment.get("pose", "")),
		"stop_cleanup": true,
		"unreachable_cleanup": true,
		"supersession_cleanup": true,
		"building_unavailable_cleanup": true,
		"unconscious_cleanup": true
	}))
	quit(0)


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
