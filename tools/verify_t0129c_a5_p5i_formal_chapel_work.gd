extends SceneTree

const LEADER_ID := "priest_01"
const PRAYER_ID := "gardener_01"
const BUILDING_ID := "chapel"
const LEADER_ACTION_ID := "lead_mass"
const PRAYER_ACTION_ID := "pray_at_chapel"
const ALTAR_ID := "chapel_altar_01"
const PRAYER_SEAT_ID := "chapel_prayer_seat_01"


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn unavailable")
		return
	var main := packed.instantiate()
	var startup_plan_system := main.get_node_or_null("Systems/DailyPlanSystem")
	if startup_plan_system != null:
		startup_plan_system.set_auto_execution_enabled(false)
	root.add_child(main)
	await process_frame
	await physics_frame

	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var piety_system := root.get_node_or_null("Main/Systems/PietySystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var gm_panel := root.get_node_or_null("Main/UI/GMPanel")
	var gm_window := root.get_node_or_null("Main/UI/GMPanel/GMWindow") as Control
	var prayer_button := gm_window.find_child("FormalChapelPrayerButton", true, false) as Button if gm_window != null else null
	var leader_button := gm_window.find_child("FormalChapelLeaderButton", true, false) as Button if gm_window != null else null
	var leader_node := _get_npc_node(npc_system, LEADER_ID) if npc_system != null else null
	var prayer_node := _get_npc_node(npc_system, PRAYER_ID) if npc_system != null else null
	if [action_system, npc_system, building_system, memory_system, piety_system, daily_plan_system, time_system, gm_panel, gm_window, prayer_button, leader_button, leader_node, prayer_node].has(null):
		_fail("A5-P5i runtime dependencies unavailable")
		return

	time_system.set_current_time(1, 8, 2, 0)
	time_system.set_paused(false)
	leader_node.set("move_speed", 5.0)
	prayer_node.set("move_speed", 5.0)
	for npc_id in [LEADER_ID, PRAYER_ID]:
		action_system.interrupt_npc_action(npc_id, "verify_a5_p5i_setup", true)
		npc_system.update_npc_state(npc_id, {
			"fatigue": 0,
			"satiety": 100,
			"current_action": "idle",
			"last_action_result": "verify_a5_p5i_ready"
		})
	piety_system.debug_set_piety(0.0)

	if (
		not bool(action_system.get_action(PRAYER_ACTION_ID).get("formal_spatial_route", false))
		or not bool(action_system.get_action(LEADER_ACTION_ID).get("formal_spatial_route", false))
		or _count_workstations(building_system, "chapel_altar") != 1
		or _count_workstations(building_system, "chapel_prayer_seat") != 10
	):
		_fail("Formal chapel action/capacity contract is incomplete")
		return

	gm_window.visible = true
	prayer_button.pressed.emit()
	await process_frame
	if (
		gm_window.visible
		or str(action_system.get_runtime_action_snapshot(PRAYER_ID).get("phase", "")) != "pending"
		or not _workstation_reserved_by(building_system, PRAYER_SEAT_ID, PRAYER_ID)
		or not prayer_node.visible
		or absf(prayer_node.global_position.x) > 80.0
		or absf(prayer_node.global_position.z) > 100.0
	):
		_fail("Prayer GM entry did not start a reservation-only formal route")
		return
	action_system._on_logical_time_tick(3600.0, 1.0)
	if not is_zero_approx(float(piety_system.get_piety_snapshot().get("current_piety", -1.0))):
		_fail("Prayer produced piety before the actor reached the prayer seat")
		return

	if not await _wait_for_active(action_system, time_system, PRAYER_ID, PRAYER_ACTION_ID):
		_fail("Ivo did not physically reach a chapel prayer seat")
		return
	await physics_frame
	var initial_prayer_runtime: Dictionary = action_system.get_runtime_action_snapshot(PRAYER_ID)
	var initial_prayer_state: Dictionary = npc_system.get_npc_state(PRAYER_ID)
	var initial_prayer_art: Dictionary = prayer_node.debug_get_character_art_snapshot()
	if (
		str(initial_prayer_runtime.get("prayer_mode", "")) != "personal_prayer"
		or str(initial_prayer_state.get("current_workstation_id", "")) != PRAYER_SEAT_ID
		or str(initial_prayer_state.get("physical_location_phase", "")) != "occupant_anchor"
		or not _workstation_occupied_by(building_system, PRAYER_SEAT_ID, PRAYER_ID)
		or str(initial_prayer_art.get("appearance_id", "")) != "ivo_gardener_chibi_v1"
		or str(initial_prayer_art.get("desired_state", "")) != "seated_prayer"
		or int(initial_prayer_art.get("seated_prayer_clip_loop_mode", 0)) == 0
		or bool(initial_prayer_art.get("garden_hoe_visible", true))
		or float((initial_prayer_art.get("presentation_pose_offset", Vector3.ZERO) as Vector3).y) >= -0.5
	):
		_fail("Prayer seat attachment or seated prayer presentation is incomplete: %s" % JSON.stringify({"runtime": initial_prayer_runtime, "state": initial_prayer_state, "art": initial_prayer_art}))
		return

	gm_window.visible = true
	leader_button.pressed.emit()
	await process_frame
	if (
		gm_window.visible
		or str(action_system.get_runtime_action_snapshot(LEADER_ID).get("phase", "")) != "pending"
		or not _workstation_reserved_by(building_system, ALTAR_ID, LEADER_ID)
	):
		_fail("Mass-leader GM entry did not reserve the altar while travelling")
		return
	var generation_before_leader_route: Dictionary = piety_system.get_piety_snapshot().get("generated_by_npc", {})
	action_system._on_logical_time_tick(600.0, 1.0)
	var generation_during_leader_route: Dictionary = piety_system.get_piety_snapshot().get("generated_by_npc", {})
	if (
		float(generation_during_leader_route.get(PRAYER_ID, 0.0)) <= float(generation_before_leader_route.get(PRAYER_ID, 0.0))
		or not is_equal_approx(float(generation_during_leader_route.get(LEADER_ID, 0.0)), 0.0)
	):
		_fail("Only the already-seated prayer actor should produce piety while the leader is travelling")
		return

	if not await _wait_for_active(action_system, time_system, LEADER_ID, LEADER_ACTION_ID):
		_fail("Marcel did not physically reach the chapel altar")
		return
	await physics_frame
	var leader_state: Dictionary = npc_system.get_npc_state(LEADER_ID)
	var leader_art: Dictionary = leader_node.debug_get_character_art_snapshot()
	var prayer_during_mass: Dictionary = action_system.get_runtime_action_snapshot(PRAYER_ID)
	if (
		str(leader_state.get("current_workstation_id", "")) != ALTAR_ID
		or str(leader_state.get("physical_location_phase", "")) != "workstation"
		or not _workstation_occupied_by(building_system, ALTAR_ID, LEADER_ID)
		or str(leader_art.get("appearance_id", "")) != "marcel_priest_chibi_v1"
		or str(leader_art.get("desired_state", "")) != "mass_leader"
		or str(leader_art.get("current_clip", "")) != "Ranged_Magic_Spellcasting_Long"
		or int(leader_art.get("mass_leader_clip_loop_mode", 0)) == 0
		or not bool(leader_art.get("wooden_cross_visible", false))
		or str(prayer_during_mass.get("prayer_mode", "")) != "mass_attendance"
		or str(npc_system.get_npc_state(PRAYER_ID).get("current_workstation_id", "")) != PRAYER_SEAT_ID
	):
		_fail("Altar arrival did not start visible Mass and convert the seated prayer in place")
		return

	var generated_before_mass_tick: Dictionary = piety_system.get_piety_snapshot().get("generated_by_npc", {})
	action_system._on_logical_time_tick(600.0, 1.0)
	var generated_after_mass_tick: Dictionary = piety_system.get_piety_snapshot().get("generated_by_npc", {})
	if (
		float(generated_after_mass_tick.get(LEADER_ID, 0.0)) <= float(generated_before_mass_tick.get(LEADER_ID, 0.0))
		or float(generated_after_mass_tick.get(PRAYER_ID, 0.0)) <= float(generated_before_mass_tick.get(PRAYER_ID, 0.0))
	):
		_fail("Active leader and attendee did not both contribute authoritative piety")
		return

	var current_hour := int(root.get_node("GameState").current_hour)
	daily_plan_system.set_npc_daily_plan(LEADER_ID, _make_plan(current_hour, "idle", "idle", ""), false, "verify_a5_p5i_boundary")
	daily_plan_system.set_npc_daily_plan(PRAYER_ID, _make_plan(current_hour, "work_garden", "work", "garden"), false, "verify_a5_p5i_boundary")
	var leader_boundary: Dictionary = daily_plan_system.execute_current_plan_for_npc(LEADER_ID, true, false, true)
	var prayer_boundary: Dictionary = daily_plan_system.execute_current_plan_for_npc(PRAYER_ID, true, false, true)
	if (
		str(leader_boundary.get("status", "")) != "deferred_until_mass_completed"
		or str(prayer_boundary.get("status", "")) != "deferred_until_mass_completed"
		or not action_system.is_npc_committed_to_active_mass(LEADER_ID)
		or not action_system.is_npc_committed_to_active_mass(PRAYER_ID)
	):
		_fail("Hour-boundary plans did not preserve the formal Mass pair")
		return

	var prayer_elapsed_before_stop := float(action_system.get_runtime_action_snapshot(PRAYER_ID).get("elapsed_seconds", -1.0))
	var resumed_count_before := _count_event(memory_system.get_npc_daily_events(PRAYER_ID), "prayer_resumed_alone")
	action_system.interrupt_npc_action(LEADER_ID, "verify_a5_p5i_leader_stopped", true)
	await process_frame
	await physics_frame
	var resumed_prayer: Dictionary = action_system.get_runtime_action_snapshot(PRAYER_ID)
	if (
		str(resumed_prayer.get("phase", "")) != "active"
		or str(resumed_prayer.get("prayer_mode", "")) != "personal_prayer"
		or absf(float(resumed_prayer.get("elapsed_seconds", -2.0)) - prayer_elapsed_before_stop) > 5.0
		or str(resumed_prayer.get("workstation_id", "")) != PRAYER_SEAT_ID
		or str(npc_system.get_npc_state(PRAYER_ID).get("physical_location_phase", "")) != "occupant_anchor"
		or _count_event(memory_system.get_npc_daily_events(PRAYER_ID), "prayer_resumed_alone") != resumed_count_before + 1
	):
		_fail("Leader exit did not restore the same seated prayer session in place: %s" % JSON.stringify({
			"runtime": resumed_prayer,
			"state": npc_system.get_npc_state(PRAYER_ID),
			"elapsed_before": prayer_elapsed_before_stop,
			"resumed_before": resumed_count_before,
			"resumed_after": _count_event(memory_system.get_npc_daily_events(PRAYER_ID), "prayer_resumed_alone")
		}))
		return

	gm_panel._stop_formal_chapel_work()
	await process_frame
	await physics_frame
	if (
		bool(npc_system.get_formal_workstation_action_snapshot(LEADER_ID).get("active", true))
		or bool(npc_system.get_formal_workstation_action_snapshot(PRAYER_ID).get("active", true))
		or not _workstation_is_clear(building_system, ALTAR_ID)
		or not _workstation_is_clear(building_system, PRAYER_SEAT_ID)
		or str(npc_system.get_npc_state(PRAYER_ID).get("physical_location_phase", "")) != "formal_location_interior"
	):
		_fail("GM chapel stop did not clear both formal sessions and workstations")
		return

	print("T0129C A5-P5i formal chapel work verification passed")
	quit(0)


func _get_npc_node(npc_system: Node, npc_id: String) -> Node:
	var node_paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(node_paths.get(npc_id, NodePath("")))


func _wait_for_active(action_system: Node, time_system: Node, npc_id: String, action_id: String, max_frames: int = 1800) -> bool:
	for _frame in range(max_frames):
		time_system.set_paused(false)
		await physics_frame
		var runtime: Dictionary = action_system.get_runtime_action_snapshot(npc_id)
		if str(runtime.get("phase", "")) == "active" and str(runtime.get("action_id", "")) == action_id:
			return true
	return false


func _make_plan(current_hour: int, action_id: String, action_kind: String, location_id: String) -> Array:
	var result: Array = []
	for hour in range(24):
		result.append({
			"hour": hour,
			"action_kind": action_kind if hour == current_hour else "idle",
			"action_id": action_id if hour == current_hour else "idle",
			"location_id": location_id if hour == current_hour else "",
			"target_id": "",
			"priority": 60,
			"reason": "A5-P5i formal chapel verification",
			"dialogue_goal": "",
			"source": "verify_a5_p5i"
		})
	return result


func _count_workstations(building_system: Node, workstation_type: String) -> int:
	var count := 0
	for raw_workstation in building_system.get_building(BUILDING_ID).get("workstations", []):
		if raw_workstation is Dictionary and str(raw_workstation.get("type", "")) == workstation_type:
			count += 1
	return count


func _count_event(events: Array, event_type: String) -> int:
	var count := 0
	for raw_event in events:
		if raw_event is Dictionary and str(raw_event.get("type", "")) == event_type:
			count += 1
	return count


func _workstation_reserved_by(building_system: Node, workstation_id: String, npc_id: String) -> bool:
	var workstation := _get_workstation(building_system, workstation_id)
	var occupied_by: Variant = workstation.get("occupied_by")
	return str(workstation.get("reserved_by", "")) == npc_id and (occupied_by == null or str(occupied_by).is_empty())


func _workstation_occupied_by(building_system: Node, workstation_id: String, npc_id: String) -> bool:
	var workstation := _get_workstation(building_system, workstation_id)
	var reserved_by: Variant = workstation.get("reserved_by")
	return str(workstation.get("occupied_by", "")) == npc_id and (reserved_by == null or str(reserved_by).is_empty())


func _workstation_is_clear(building_system: Node, workstation_id: String) -> bool:
	var workstation := _get_workstation(building_system, workstation_id)
	var occupied_by: Variant = workstation.get("occupied_by")
	var reserved_by: Variant = workstation.get("reserved_by")
	return (occupied_by == null or str(occupied_by).is_empty()) and (reserved_by == null or str(reserved_by).is_empty())


func _get_workstation(building_system: Node, workstation_id: String) -> Dictionary:
	for raw_workstation in building_system.get_building(BUILDING_ID).get("workstations", []):
		if raw_workstation is Dictionary and str(raw_workstation.get("id", "")) == workstation_id:
			return raw_workstation
	return {}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
