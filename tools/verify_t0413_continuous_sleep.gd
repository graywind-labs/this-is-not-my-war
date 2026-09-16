extends SceneTree


const NPC_ID := "veteran_deputy_01"
const ACTION_ID := "sleep_in_dormitory"
const BUILDING_ID := "dormitory"
const BED_ID := "dormitory_bed_01"


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn unavailable")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var needs_system := root.get_node_or_null("Main/Systems/NPCNeedsSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var npc_node := _get_npc_node(npc_system)
	if [action_system, needs_system, npc_system, building_system, daily_plan_system, memory_system, time_system, npc_node].has(null):
		_fail("T0413 runtime dependencies unavailable")
		return
	time_system.set_paused(true)
	needs_system.restore_game_save_snapshot({})

	var sleep_profile: Dictionary = needs_system.get_profile("sleep")
	var sleep_action: Dictionary = action_system.get_action(ACTION_ID)
	if absf(float(sleep_profile.get("fatigue_per_hour", 0.0)) + 12.5) > 0.0001:
		_fail("Sleep fatigue recovery is not the 8-hour -12.5/hour baseline")
		return
	if (
		str(sleep_action.get("completion_policy", "")) != "continuous_until_plan_changes"
		or int(sleep_action.get("duration_seconds", 0)) != 28800
	):
		_fail("Sleep action is not configured as an 8-hour continuous plan action")
		return

	npc_system.update_npc_state(NPC_ID, {"fatigue": 100, "satiety": 100})
	var seven_hour_result: Dictionary = needs_system.debug_advance_profile(NPC_ID, "sleep", 7.0 * 3600.0)
	if (
		int(npc_system.get_npc_state(NPC_ID).get("fatigue", -1)) != 13
		or int(seven_hour_result.get("applied_deltas", {}).get("fatigue", 0)) != -87
	):
		_fail("Seven hours of sleep did not preserve the slower recovery curve")
		return
	var eighth_hour_result: Dictionary = needs_system.debug_advance_profile(NPC_ID, "sleep", 3600.0)
	if (
		int(npc_system.get_npc_state(NPC_ID).get("fatigue", -1)) != 0
		or int(eighth_hour_result.get("applied_deltas", {}).get("fatigue", 0)) != -13
	):
		_fail("Eight hours of sleep did not clear full fatigue exactly: %s" % JSON.stringify({
			"state": npc_system.get_npc_state(NPC_ID),
			"result": eighth_hour_result
		}))
		return
	var zero_fatigue_result: Dictionary = needs_system.debug_advance_profile(NPC_ID, "sleep", 3600.0)
	if (
		int(npc_system.get_npc_state(NPC_ID).get("fatigue", -1)) != 0
		or (zero_fatigue_result.get("applied_deltas", {}) as Dictionary).has("fatigue")
	):
		_fail("Sleeping at zero fatigue produced an ineffective fatigue delta")
		return

	var plan := _make_plan()
	if not daily_plan_system.set_npc_daily_plan(NPC_ID, plan, false, "verify_t0413"):
		_fail("Could not install the T0413 sleep-to-idle plan")
		return
	daily_plan_system.set_auto_execution_enabled(true)
	time_system.set_current_time(1, 6, 59, 0)
	time_system.set_paused(false)
	var sleep_started: Dictionary = action_system.stage_npc_sleep_for_tutorial(NPC_ID)
	if not bool(sleep_started.get("ok", false)):
		_fail("Could not stage authoritative bed sleep: %s" % JSON.stringify(sleep_started))
		return
	var sleep_end_count_before := _count_event(memory_system.get_npc_daily_events(NPC_ID), "sleep_ended")
	var runtime: Dictionary = action_system.get_runtime_action_snapshot(NPC_ID)
	action_system.call("_advance_active_action", NPC_ID, float(runtime.get("duration_seconds", 28800.0)) + 60.0)
	if not _is_still_sleeping(action_system, npc_system, building_system, npc_node):
		_fail("Nominal duration or zero fatigue woke the NPC")
		return
	var post_duration_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	var post_duration_profile_id := str(
		needs_system.call("_resolve_profile_id", NPC_ID, post_duration_state)
	)
	var post_duration_effective_seconds := float(
		needs_system.call(
			"_get_effective_activity_seconds",
			NPC_ID,
			post_duration_state,
			3600.0
		)
	)
	var post_duration_needs_result: Dictionary = needs_system.call(
		"_apply_profile",
		NPC_ID,
		post_duration_profile_id,
		post_duration_effective_seconds
	)
	if (
		int(npc_system.get_npc_state(NPC_ID).get("fatigue", -1)) != 0
		or (post_duration_needs_result.get("applied_deltas", {}) as Dictionary).has("fatigue")
	):
		_fail("Post-duration continuous sleep fell back to idle fatigue gain")
		return
	if _count_event(memory_system.get_npc_daily_events(NPC_ID), "sleep_ended") != sleep_end_count_before:
		_fail("Continuous sleep wrote a false sleep_ended event")
		return

	if not time_system.debug_advance_game_seconds(60.0):
		_fail("Could not cross into the next sleep plan hour")
		return
	await process_frame
	await physics_frame
	if not _is_still_sleeping(action_system, npc_system, building_system, npc_node):
		_fail("A same-sleep plan boundary woke or remounted the NPC")
		return

	time_system.set_current_time(1, 7, 59, 0)
	if not time_system.debug_advance_game_seconds(60.0):
		_fail("Could not cross into the non-sleep plan hour")
		return
	await process_frame
	await physics_frame
	var final_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	if (
		str(action_system.get_runtime_action_id(NPC_ID)) == ACTION_ID
		or str(final_state.get("current_action", "")) != "idle"
		or not _bed_is_clear(building_system)
		or bool(npc_node.debug_get_spatial_attachment_snapshot().get("active", false))
		or _count_event(memory_system.get_npc_daily_events(NPC_ID), "sleep_ended") != sleep_end_count_before + 1
	):
		_fail("The next non-sleep plan phase did not wake the NPC exactly once: %s" % JSON.stringify({
			"runtime": action_system.get_runtime_action_snapshot(NPC_ID),
			"state": final_state,
			"bed": _get_bed(building_system),
			"attachment": npc_node.debug_get_spatial_attachment_snapshot(),
			"sleep_ended_before": sleep_end_count_before,
			"sleep_ended_after": _count_event(memory_system.get_npc_daily_events(NPC_ID), "sleep_ended"),
			"plan_item": daily_plan_system.get_current_plan_item(NPC_ID)
		}))
		return

	print("T0413 continuous sleep verification passed")
	quit(0)


func _make_plan() -> Array:
	var plan: Array = []
	for hour in range(24):
		plan.append({
			"hour": hour,
			"action_id": ACTION_ID if hour in [6, 7] else "idle",
			"reason": "T0413 continuous sleep verification",
			"priority": 50,
			"target": {}
		})
	return plan


func _is_still_sleeping(action_system: Node, npc_system: Node, building_system: Node, npc_node: Node) -> bool:
	var state: Dictionary = npc_system.get_npc_state(NPC_ID)
	var bed := _get_bed(building_system)
	return (
		str(action_system.get_runtime_action_id(NPC_ID)) == ACTION_ID
		and str(state.get("current_action", "")) == ACTION_ID
		and bool(npc_system.is_npc_sleeping(NPC_ID))
		and str(bed.get("occupied_by", "")) == NPC_ID
		and bool(npc_node.debug_get_spatial_attachment_snapshot().get("active", false))
		and str(npc_node.debug_get_spatial_attachment_snapshot().get("pose", "")) == "sleeping_supine"
	)


func _get_npc_node(npc_system: Node) -> Node:
	if npc_system == null:
		return null
	var node_paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(node_paths.get(NPC_ID, NodePath("")))


func _get_bed(building_system: Node) -> Dictionary:
	for raw_workstation in building_system.get_building(BUILDING_ID).get("workstations", []):
		if raw_workstation is Dictionary and str(raw_workstation.get("id", "")) == BED_ID:
			return raw_workstation
	return {}


func _bed_is_clear(building_system: Node) -> bool:
	var bed := _get_bed(building_system)
	var occupied_by: Variant = bed.get("occupied_by")
	var reserved_by: Variant = bed.get("reserved_by")
	return (
		(occupied_by == null or str(occupied_by).is_empty())
		and (reserved_by == null or str(reserved_by).is_empty())
	)


func _count_event(events: Array, event_type: String) -> int:
	var count := 0
	for raw_event in events:
		if raw_event is Dictionary and str((raw_event as Dictionary).get("type", "")) == event_type:
			count += 1
	return count


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
