extends SceneTree

const NPC_ID := "blacksmith_01"
const BUILDING_ID := "blacksmith"
const WORKSTATION_ID := "forge_01"


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
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	var npc := root.get_node_or_null("Main/WorldRoot/Station/NPCs/Blacksmith01") as CharacterBody3D
	if npc_system == null or building_system == null or controller == null or npc == null:
		_fail("A2b-P1 runtime dependencies unavailable")
		return
	if npc.get_node_or_null("BodyCollision") == null or npc.get_node_or_null("InteractionArea/InteractionCollision") == null:
		_fail("NPC root is missing separated body / interaction collisions")
		return
	var body_snapshot: Dictionary = npc.debug_get_motion_snapshot()
	if (
		int(body_snapshot.get("body_collision_layer", 0)) != 2
		or int(body_snapshot.get("body_collision_mask", 0)) != 3
		or int(body_snapshot.get("interaction_collision_layer", 0)) != 4
	):
		_fail("NPC collision layers do not match physics_navigation_v1: %s" % body_snapshot)
		return
	npc.move_speed = 24.0

	var start_result: Dictionary = npc_system.debug_run_glen_blacksmith_navigation_pilot()
	if not bool(start_result.get("ok", false)) or str(start_result.get("workstation_id", "")) != WORKSTATION_ID:
		_fail("Formal navigation pilot did not start: %s" % start_result)
		return
	var nav_snapshot: Dictionary = controller.debug_get_production_navigation_snapshot()
	if not bool(nav_snapshot.get("enabled", false)):
		_fail("Formal production navigation was not enabled for pilot")
		return

	var saw_outdoor_before_entry := false
	var saw_entry_commit_before_workstation := false
	var arrived := false
	for _frame in range(720):
		await physics_frame
		var state: Dictionary = npc_system.get_npc_state(NPC_ID)
		var phase := str(state.get("spatial_route_phase", ""))
		var location_id := str(state.get("current_location", ""))
		if phase in ["approaching_door", "crossing_entry"] and location_id == "plaza":
			saw_outdoor_before_entry = true
		if location_id == BUILDING_ID and str(state.get("current_workstation_id", "")).is_empty():
			saw_entry_commit_before_workstation = true
		if (
			phase == "workstation_arrived"
			and location_id == BUILDING_ID
			and str(state.get("current_workstation_id", "")) == WORKSTATION_ID
		):
			arrived = true
			break
	if not saw_outdoor_before_entry or not saw_entry_commit_before_workstation or not arrived:
		_fail("Pilot did not preserve door / workstation transaction phases: %s" % npc_system.debug_get_glen_blacksmith_navigation_pilot_snapshot())
		return
	var workstation := _find_workstation(building_system.get_building(BUILDING_ID), WORKSTATION_ID)
	if str(workstation.get("occupied_by", "")) != NPC_ID or not _clean_nullable_id(workstation.get("reserved_by", "")).is_empty():
		_fail("Workstation was not atomically committed after physical arrival: %s" % workstation)
		return

	var completed_snapshot: Dictionary = npc_system.debug_get_glen_blacksmith_navigation_pilot_snapshot()
	var motion: Dictionary = completed_snapshot.get("motion", {})
	if (
		str(motion.get("state", "")) != "arrived"
		or int(motion.get("avoidance_callback_count", 0)) <= 0
		or float(motion.get("minimum_target_distance", 99.0)) > 0.3
	):
		_fail("NavigationAgent runtime evidence is incomplete: %s" % motion)
		return

	var stop_result: Dictionary = npc_system.debug_stop_glen_blacksmith_navigation_pilot("verification_complete")
	if not bool(stop_result.get("ok", false)):
		_fail("Pilot stop failed: %s" % stop_result)
		return
	workstation = _find_workstation(building_system.get_building(BUILDING_ID), WORKSTATION_ID)
	if not _clean_nullable_id(workstation.get("occupied_by", "")).is_empty() or not _clean_nullable_id(workstation.get("reserved_by", "")).is_empty():
		_fail("Pilot cleanup left a ghost workstation claim: %s" % workstation)
		return
	if npc.is_navigation_motion_enabled():
		_fail("Pilot cleanup did not restore legacy-compatible motion mode")
		return

	var failure_start: Dictionary = npc_system.debug_run_glen_blacksmith_navigation_pilot()
	if not bool(failure_start.get("ok", false)):
		_fail("Failure-path pilot did not start: %s" % failure_start)
		return
	await physics_frame
	if not npc.request_motion(Vector3(900.0, npc.global_position.y, 60.0), "forced_unreachable"):
		_fail("Could not inject an unreachable formal target")
		return
	var failure_settled := false
	for _frame in range(720):
		await physics_frame
		var failure_state: Dictionary = npc_system.get_npc_state(NPC_ID)
		if str(failure_state.get("spatial_route_phase", "")) == "navigation_failed":
			failure_settled = true
			break
	if not failure_settled:
		_fail("Unreachable target did not settle as a bounded navigation failure: %s" % npc_system.debug_get_glen_blacksmith_navigation_pilot_snapshot())
		return
	workstation = _find_workstation(building_system.get_building(BUILDING_ID), WORKSTATION_ID)
	if not _clean_nullable_id(workstation.get("occupied_by", "")).is_empty() or not _clean_nullable_id(workstation.get("reserved_by", "")).is_empty():
		_fail("Unreachable target left a ghost workstation reservation: %s" % workstation)
		return
	npc_system.debug_stop_glen_blacksmith_navigation_pilot("failure_verified")
	await process_frame
	await process_frame

	print("T0129C A2b-P1 Glen formal navigation verification passed: %s" % JSON.stringify({
		"body_layer": int(body_snapshot.get("body_collision_layer", 0)),
		"interaction_layer": int(body_snapshot.get("interaction_collision_layer", 0)),
		"location_committed_after_door": saw_entry_commit_before_workstation,
		"unreachable_cleanup": failure_settled,
		"workstation_id": WORKSTATION_ID,
		"avoidance_callbacks": int(motion.get("avoidance_callback_count", 0)),
		"minimum_target_distance": float(motion.get("minimum_target_distance", 0.0))
	}))
	quit(0)


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
