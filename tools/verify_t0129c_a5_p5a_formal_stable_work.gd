extends SceneTree

const NPC_ID := "stableman_01"
const BUILDING_ID := "stable"
const ACTION_ID := "work_stable"
const FIRST_STALL_ID := "stall_01"

var _failed := false


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Main.tscn unavailable")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var horse_system := root.get_node_or_null("Main/Systems/HorseSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var toma := root.get_node_or_null("Main/WorldRoot/Station/NPCs/Stableman01") as CharacterBody3D
	if [action_system, npc_system, building_system, horse_system, daily_plan_system, time_system, toma].has(null):
		_fail("A5-P5a runtime dependencies unavailable")
		return
	time_system.set_paused(false)
	time_system.set_current_time(1, 7, 2, 0)
	daily_plan_system.set_auto_execution_enabled(true)
	toma.set("move_speed", 40.0)

	var action: Dictionary = action_system.get_action(ACTION_ID)
	if not bool(action.get("formal_spatial_route", false)):
		_fail("work_stable is not configured for formal spatial authority")
		return
	var initial_art: Dictionary = toma.debug_get_character_art_snapshot()
	if not bool(initial_art.get("ready", false)) or str(initial_art.get("appearance_id", "")) != "toma_stableman_chibi_v1":
		_fail("Toma formal low-poly character view is unavailable: %s" % JSON.stringify(initial_art))
		return

	var plan: Array = []
	for hour in range(24):
		plan.append({
			"hour": hour,
			"action_id": ACTION_ID,
			"reason": "A5-P5a formal stable work verification",
			"source": "verify_t0129c_a5_p5a"
		})
	if not daily_plan_system.set_npc_daily_plan(NPC_ID, plan, false, "verify_t0129c_a5_p5a"):
		_fail("Could not install Toma's repeatable stable plan")
		return
	npc_system.update_npc_state(NPC_ID, {
		"fatigue": 0,
		"satiety": 100,
		"current_action": "idle",
		"last_action_result": "verify_a5_p5a_ready"
	})

	var horse_ids: Array[String] = horse_system.get_horse_ids()
	if horse_ids.is_empty():
		_fail("Stable has no horse for caretaker-authority verification")
		return
	var horse_id := str(horse_ids[0])
	var care_before_route := float(horse_system.get_horse_snapshot(horse_id).get("care_bonus_hp", 0.0))
	var dispatch: Dictionary = daily_plan_system.execute_current_plan_for_npc(NPC_ID, true)
	if not bool(dispatch.get("ok", false)):
		_fail("Toma's formal stable action did not dispatch: %s" % JSON.stringify(dispatch))
		return
	var pending_runtime: Dictionary = action_system.get_runtime_action_snapshot(NPC_ID)
	if str(pending_runtime.get("phase", "")) != "pending" or not _workstation_reserved_by(building_system, FIRST_STALL_ID, NPC_ID):
		_fail("Formal stable route did not begin as a reservation-only pending transaction: runtime=%s stable=%s" % [
			JSON.stringify(pending_runtime),
			JSON.stringify(building_system.get_building(BUILDING_ID).get("workstations", []))
		])
		return
	horse_system._on_logical_time_tick(600.0, 1.0)
	var care_before_arrival := float(horse_system.get_horse_snapshot(horse_id).get("care_bonus_hp", 0.0))
	if not is_equal_approx(care_before_arrival, care_before_route):
		_fail("HorseSystem counted Toma's labor before physical workstation arrival")
		return

	if not await _wait_for_active_work(action_system, time_system):
		_fail("Toma did not reach the reserved stable care position: %s" % JSON.stringify(npc_system.debug_get_spatial_migration_snapshot(NPC_ID)))
		return
	await create_timer(0.18).timeout
	var active_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	var active_spatial: Dictionary = npc_system.debug_get_spatial_migration_snapshot(NPC_ID)
	var active_art: Dictionary = toma.debug_get_character_art_snapshot()
	if (
		str(active_state.get("current_action", "")) != ACTION_ID
		or str(active_state.get("current_location", "")) != BUILDING_ID
		or str(active_spatial.get("physical_location_phase", "")) != "workstation"
		or str(active_spatial.get("current_workstation_id", "")) != FIRST_STALL_ID
		or not _workstation_occupied_by(building_system, FIRST_STALL_ID, NPC_ID)
	):
		_fail("Arrival did not atomically commit logical location and stable occupancy")
		return
	if (
		str(active_art.get("desired_state", "")) != "work"
		or float(active_art.get("work_cycle_length", 0.0)) <= 0.0
		or int(active_art.get("work_clip_loop_mode", 0)) == 0
		or bool(active_art.get("hammer_visible", true))
	):
		_fail("Toma's hammer-free stable work loop is not visible: %s" % JSON.stringify(active_art))
		return

	horse_system._on_logical_time_tick(600.0, 1.0)
	var care_while_active := float(horse_system.get_horse_snapshot(horse_id).get("care_bonus_hp", 0.0))
	if care_while_active <= care_before_arrival:
		_fail("HorseSystem did not consume the physically active work_stable cycle")
		return

	var first_runtime: Dictionary = action_system.get_runtime_action_snapshot(NPC_ID)
	var first_session: Dictionary = npc_system.get_formal_workstation_action_snapshot(NPC_ID).get("session", {})
	var first_position: Vector3 = toma.global_position
	action_system._on_logical_time_tick(float(first_runtime.get("duration_seconds", 3600.0)) + 1.0, 1.0)
	for _frame in range(5):
		await process_frame
	var repeated_runtime: Dictionary = action_system.get_runtime_action_snapshot(NPC_ID)
	var repeated_session: Dictionary = npc_system.get_formal_workstation_action_snapshot(NPC_ID).get("session", {})
	if (
		str(repeated_runtime.get("phase", "")) != "active"
		or str(repeated_runtime.get("workstation_id", "")) != FIRST_STALL_ID
		or int(repeated_session.get("started_at_msec", -1)) != int(first_session.get("started_at_msec", -2))
		or toma.global_position.distance_to(first_position) > 0.1
		or not _workstation_occupied_by(building_system, FIRST_STALL_ID, NPC_ID)
	):
		_fail("Repeatable work requested a second slot or replayed the door route: %s" % JSON.stringify(repeated_runtime))
		return

	if not action_system.interrupt_npc_action(NPC_ID, "verify_formal_stable_stop", true):
		_fail("Could not interrupt the formal stable cycle")
		return
	await process_frame
	if (
		bool(npc_system.get_formal_workstation_action_snapshot(NPC_ID).get("active", true))
		or not _workstation_is_clear(building_system, FIRST_STALL_ID)
		or str(npc_system.get_npc_state(NPC_ID).get("physical_location_phase", "")) != "formal_location_interior"
	):
		_fail("Interruption did not release the care position while retaining formal authority")
		return

	print("T0129C A5-P5a formal stable work verification passed")
	quit(0)


func _wait_for_active_work(action_system: Node, time_system: Node, max_frames: int = 1800) -> bool:
	for _frame in range(max_frames):
		time_system.set_paused(false)
		await physics_frame
		var runtime: Dictionary = action_system.get_runtime_action_snapshot(NPC_ID)
		if str(runtime.get("phase", "")) == "active" and str(runtime.get("action_id", "")) == ACTION_ID:
			return true
	return false


func _workstation_reserved_by(building_system: Node, workstation_id: String, npc_id: String) -> bool:
	for raw_workstation in building_system.get_building(BUILDING_ID).get("workstations", []):
		var workstation: Dictionary = raw_workstation
		if str(workstation.get("id", "")) == workstation_id:
			var occupied_by: Variant = workstation.get("occupied_by")
			return str(workstation.get("reserved_by", "")) == npc_id and (occupied_by == null or str(occupied_by).is_empty())
	return false


func _workstation_occupied_by(building_system: Node, workstation_id: String, npc_id: String) -> bool:
	for raw_workstation in building_system.get_building(BUILDING_ID).get("workstations", []):
		var workstation: Dictionary = raw_workstation
		if str(workstation.get("id", "")) == workstation_id:
			var reserved_by: Variant = workstation.get("reserved_by")
			return str(workstation.get("occupied_by", "")) == npc_id and (reserved_by == null or str(reserved_by).is_empty())
	return false


func _workstation_is_clear(building_system: Node, workstation_id: String) -> bool:
	for raw_workstation in building_system.get_building(BUILDING_ID).get("workstations", []):
		var workstation: Dictionary = raw_workstation
		if str(workstation.get("id", "")) == workstation_id:
			var occupied_by: Variant = workstation.get("occupied_by")
			var reserved_by: Variant = workstation.get("reserved_by")
			return (occupied_by == null or str(occupied_by).is_empty()) and (reserved_by == null or str(reserved_by).is_empty())
	return false


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	quit(1)
