extends SceneTree

const LEADER_ID := "priest_01"
const PRAYER_ID := "gardener_01"
const BUILDING_ID := "chapel"
const LEADER_ACTION_ID := "lead_mass"
const PRAYER_ACTION_ID := "pray_at_chapel"
const ALTAR_ID := "chapel_altar_01"
const PRAYER_SEAT_ID := "chapel_prayer_seat_03"


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
		or str(action_system.get_action(PRAYER_ACTION_ID).get("completion_policy", "")) != "repeat_while_planned"
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
		not is_equal_approx(
			float(generated_after_mass_tick.get(LEADER_ID, 0.0)) - float(generated_before_mass_tick.get(LEADER_ID, 0.0)),
			3.25 / 6.0
		)
		or not is_equal_approx(
			float(generated_after_mass_tick.get(PRAYER_ID, 0.0)) - float(generated_before_mass_tick.get(PRAYER_ID, 0.0)),
			3.25 / 6.0
		)
	):
		_fail("Active leader and attendee did not each contribute 3.25 piety per hour")
		return

	# Natural Mass completion must only change the seated attendee's prayer mode.
	# The leader likewise keeps the altar position as an idle completed hold.
	var prayer_position_before_transition: Vector3 = prayer_node.global_position
	var leader_position_before_transition: Vector3 = leader_node.global_position
	var prayer_attachment_before_transition: Dictionary = prayer_node.debug_get_spatial_attachment_snapshot()
	if not _set_active_action_near_completion(action_system, LEADER_ID):
		_fail("Could not stage natural Mass completion")
		return
	action_system._on_logical_time_tick(1.0, 1.0)
	await process_frame
	await physics_frame
	var prayer_after_mass: Dictionary = action_system.get_runtime_action_snapshot(PRAYER_ID)
	var leader_hold: Dictionary = npc_system.get_formal_workstation_action_snapshot(LEADER_ID)
	if (
		str(prayer_after_mass.get("action_id", "")) != PRAYER_ACTION_ID
		or str(prayer_after_mass.get("prayer_mode", "")) != "personal_prayer"
		or prayer_node.global_position.distance_to(prayer_position_before_transition) > 0.001
		or prayer_node.debug_get_spatial_attachment_snapshot() != prayer_attachment_before_transition
		or str(npc_system.get_npc_state(PRAYER_ID).get("current_workstation_id", "")) != PRAYER_SEAT_ID
		or not _workstation_occupied_by(building_system, PRAYER_SEAT_ID, PRAYER_ID)
		or not action_system.get_runtime_action_snapshot(LEADER_ID).is_empty()
		or str(npc_system.get_npc_state(LEADER_ID).get("current_action", "")) != "idle"
		or leader_node.global_position.distance_to(leader_position_before_transition) > 0.001
		or not bool(leader_hold.get("session", {}).get("completed_in_place_hold", false))
		or str(leader_hold.get("session", {}).get("workstation_id", "")) != ALTAR_ID
		or not _workstation_occupied_by(building_system, ALTAR_ID, LEADER_ID)
	):
		_fail("Natural Mass completion moved the attendee/leader or released a chapel position: %s" % JSON.stringify({
			"prayer_runtime": prayer_after_mass,
			"prayer_state": npc_system.get_npc_state(PRAYER_ID),
			"leader_state": npc_system.get_npc_state(LEADER_ID),
			"leader_hold": leader_hold,
		}))
		return

	# Repeating the same Mass action reuses the altar immediately. Starting it
	# changes the already-seated prayer back to attendance without movement.
	if not action_system.debug_assign_action(LEADER_ID, LEADER_ACTION_ID):
		_fail("Completed Mass could not restart at the same altar")
		return
	var restarted_leader: Dictionary = action_system.get_runtime_action_snapshot(LEADER_ID)
	var prayer_rejoined: Dictionary = action_system.get_runtime_action_snapshot(PRAYER_ID)
	if (
		str(restarted_leader.get("action_id", "")) != LEADER_ACTION_ID
		or action_system.get_pending_action_id(LEADER_ID) != ""
		or leader_node.global_position.distance_to(leader_position_before_transition) > 0.001
		or str(restarted_leader.get("workstation_id", "")) != ALTAR_ID
		or str(prayer_rejoined.get("prayer_mode", "")) != "mass_attendance"
		or prayer_node.global_position.distance_to(prayer_position_before_transition) > 0.001
		or prayer_node.debug_get_spatial_attachment_snapshot() != prayer_attachment_before_transition
	):
		_fail("Same-position Mass restart or prayer-to-attendance transition failed")
		return

	# If the attendee's personal timer expires during Mass while the current plan is
	# still prayer, Mass completion must immediately begin the next prayer cycle in
	# the same seat. This covers a prayer block carrying across an hour boundary.
	var current_hour := int(root.get_node("GameState").current_hour)
	if not daily_plan_system.set_npc_daily_plan(
		PRAYER_ID,
		_make_plan(current_hour, PRAYER_ACTION_ID, "pray", "chapel"),
		false,
		"verify_a5_p5i_repeat_prayer"
	):
		_fail("Could not install the repeatable chapel prayer plan")
		return
	var prayer_plan_claim: Dictionary = daily_plan_system.execute_current_plan_for_npc(PRAYER_ID, false)
	if str(prayer_plan_claim.get("status", "")) != "already_running":
		_fail("Daily plan did not claim the active Mass attendee as its prayer action")
		return
	daily_plan_system.set_auto_execution_enabled(true)
	if (
		not _set_active_action_near_completion(action_system, LEADER_ID)
		or not _set_active_action_near_completion(action_system, PRAYER_ID)
	):
		_fail("Could not stage simultaneous prayer/Mass completion")
		return
	action_system._on_logical_time_tick(1.0, 1.0)
	await process_frame
	await process_frame
	await physics_frame
	var repeated_prayer: Dictionary = action_system.get_runtime_action_snapshot(PRAYER_ID)
	if (
		str(repeated_prayer.get("action_id", "")) != PRAYER_ACTION_ID
		or str(repeated_prayer.get("prayer_mode", "")) != "personal_prayer"
		or float(repeated_prayer.get("elapsed_seconds", -1.0)) > 5.0
		or str(repeated_prayer.get("workstation_id", "")) != PRAYER_SEAT_ID
		or action_system.get_pending_action_id(PRAYER_ID) != ""
		or prayer_node.global_position.distance_to(prayer_position_before_transition) > 0.001
		or prayer_node.debug_get_spatial_attachment_snapshot() != prayer_attachment_before_transition
		or not _workstation_occupied_by(building_system, PRAYER_SEAT_ID, PRAYER_ID)
	):
		_fail("Completed Mass attendee did not repeat planned prayer in the same seat: %s" % JSON.stringify({
			"runtime": repeated_prayer,
			"state": npc_system.get_npc_state(PRAYER_ID),
		}))
		return

	# Once the current plan changes away from prayer, completing the active cycle
	# settles into a seated hold instead of starting another one.
	if not daily_plan_system.set_npc_daily_plan(
		PRAYER_ID,
		_make_plan(current_hour, "idle", "idle", ""),
		false,
		"verify_a5_p5i_stop_repeating_prayer"
	):
		_fail("Could not replace repeatable prayer with idle")
		return
	if not _set_active_action_near_completion(action_system, PRAYER_ID):
		_fail("Could not stage standalone prayer completion")
		return
	action_system._on_logical_time_tick(1.0, 1.0)
	await process_frame
	await physics_frame
	daily_plan_system.set_auto_execution_enabled(false)
	if (
		str(npc_system.get_npc_state(PRAYER_ID).get("current_action", "")) != "idle"
		or str(npc_system.get_npc_state(PRAYER_ID).get("spatial_route_phase", "")) != "completed_workstation_hold"
		or prayer_node.global_position.distance_to(prayer_position_before_transition) > 0.001
		or str(prayer_node.debug_get_character_art_snapshot().get("desired_state", "")) != "seated_idle"
		or not _workstation_occupied_by(building_system, PRAYER_SEAT_ID, PRAYER_ID)
	):
		_fail("Prayer-to-idle completion did not preserve seated position")
		return

	# Daily-plan idle must not tear down the completed seated hold. Replacing that
	# same hour with prayer must then reactivate the exact seat without routing.
	if not daily_plan_system.set_npc_daily_plan(
		PRAYER_ID,
		_make_plan(current_hour, "idle", "idle", ""),
		false,
		"verify_a5_p5i_seated_idle"
	):
		_fail("Could not install the seated-idle chapel plan")
		return
	var seated_idle_plan: Dictionary = daily_plan_system.execute_current_plan_for_npc(PRAYER_ID, true)
	if (
		str(seated_idle_plan.get("status", "")) not in ["started", "already_running"]
		or str(npc_system.get_npc_state(PRAYER_ID).get("current_action", "")) != "idle"
		or str(npc_system.get_npc_state(PRAYER_ID).get("spatial_route_phase", "")) != "completed_workstation_hold"
		or prayer_node.global_position.distance_to(prayer_position_before_transition) > 0.001
		or prayer_node.debug_get_spatial_attachment_snapshot() != prayer_attachment_before_transition
		or str(prayer_node.debug_get_character_art_snapshot().get("desired_state", "")) != "seated_idle"
		or not _workstation_occupied_by(building_system, PRAYER_SEAT_ID, PRAYER_ID)
		or action_system.get_pending_action_id(PRAYER_ID) != ""
	):
		_fail("Daily-plan idle tore down or moved the completed prayer hold: %s" % JSON.stringify({
			"result": seated_idle_plan,
			"state": npc_system.get_npc_state(PRAYER_ID),
			"formal": npc_system.get_formal_workstation_action_snapshot(PRAYER_ID),
		}))
		return
	if not daily_plan_system.set_npc_daily_plan(
		PRAYER_ID,
		_make_plan(current_hour, PRAYER_ACTION_ID, "pray", "chapel"),
		false,
		"verify_a5_p5i_same_seat_prayer"
	):
		_fail("Could not install the same-seat chapel prayer plan")
		return
	var prayer_plan_restart: Dictionary = daily_plan_system.execute_current_plan_for_npc(PRAYER_ID, true)
	var planned_prayer_runtime: Dictionary = action_system.get_runtime_action_snapshot(PRAYER_ID)
	if (
		str(prayer_plan_restart.get("status", "")) != "started"
		or str(planned_prayer_runtime.get("action_id", "")) != PRAYER_ACTION_ID
		or str(planned_prayer_runtime.get("prayer_mode", "")) != "personal_prayer"
		or str(planned_prayer_runtime.get("workstation_id", "")) != PRAYER_SEAT_ID
		or action_system.get_pending_action_id(PRAYER_ID) != ""
		or prayer_node.global_position.distance_to(prayer_position_before_transition) > 0.001
		or prayer_node.debug_get_spatial_attachment_snapshot() != prayer_attachment_before_transition
		or not _workstation_occupied_by(building_system, PRAYER_SEAT_ID, PRAYER_ID)
	):
		_fail("Daily-plan prayer did not reactivate the held chapel seat in place: %s" % JSON.stringify({
			"result": prayer_plan_restart,
			"runtime": planned_prayer_runtime,
			"state": npc_system.get_npc_state(PRAYER_ID),
		}))
		return

	# Restore the leader for the existing cross-hour protection assertions below.
	if not action_system.debug_assign_action(LEADER_ID, LEADER_ACTION_ID):
		_fail("Could not reactivate the in-place chapel pair for boundary verification")
		return

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


func _set_active_action_near_completion(action_system: Node, npc_id: String) -> bool:
	var active_actions: Dictionary = action_system.get("_active_actions")
	if not active_actions.get(npc_id, {}) is Dictionary:
		return false
	var active_action: Dictionary = active_actions.get(npc_id, {})
	if active_action.is_empty():
		return false
	var duration := float(active_action.get("duration_seconds", 3600.0))
	active_action["elapsed_seconds"] = maxf(0.0, duration - 1.0)
	active_actions[npc_id] = active_action
	action_system.set("_active_actions", active_actions)
	return true


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
