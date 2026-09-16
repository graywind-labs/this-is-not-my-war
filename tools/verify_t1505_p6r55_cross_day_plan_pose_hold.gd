extends SceneTree


const SLEEPER_ID := "doctor_01"
const PRAYER_ID := "gardener_01"
const WORKER_ID := "stableman_01"
const ACTIONS := {
	SLEEPER_ID: "sleep_in_dormitory",
	PRAYER_ID: "pray_at_chapel",
	WORKER_ID: "work_stable",
}


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
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	if [action_system, npc_system, building_system, daily_plan_system, time_system].has(null):
		_fail("Cross-day planning dependencies unavailable")
		return

	time_system.set_current_time(1, 8, 0, 0)
	time_system.set_paused(false)
	daily_plan_system.set_auto_execution_enabled(false)
	for npc_id in ACTIONS.keys():
		action_system.interrupt_npc_action(npc_id, "verify_p6r48_setup", true)
		var npc_node := _get_npc_node(npc_system, npc_id)
		if npc_node == null:
			_fail("NPC node unavailable: %s" % npc_id)
			return
		npc_node.set("move_speed", 12.0)
		npc_system.update_npc_state(npc_id, {
			"fatigue": 60,
			"satiety": 100,
			"current_action": "idle",
			"last_action_result": "verify_p6r48_ready",
		})

	for npc_id in ACTIONS.keys():
		if not action_system.debug_assign_action(npc_id, str(ACTIONS[npc_id])):
			_fail("Could not assign setup action: %s" % npc_id)
			return
		if not await _wait_for_active(action_system, time_system, npc_id, str(ACTIONS[npc_id])):
			_fail("Formal actor did not reach the workstation: %s %s" % [npc_id, JSON.stringify({
				"runtime": action_system.get_runtime_action_snapshot(npc_id),
				"spatial": npc_system.debug_get_spatial_migration_snapshot(npc_id),
			})])
			return
	await process_frame
	await physics_frame

	var baselines := {}
	for npc_id in ACTIONS.keys():
		var node := _get_npc_node(npc_system, npc_id)
		var runtime: Dictionary = action_system.get_runtime_action_snapshot(npc_id)
		var formal: Dictionary = npc_system.get_formal_workstation_action_snapshot(npc_id)
		baselines[npc_id] = {
			"position": node.global_position,
			"attachment": node.debug_get_spatial_attachment_snapshot(),
			"art": node.debug_get_character_art_snapshot(),
			"runtime": runtime,
			"formal": formal,
			"state": npc_system.get_npc_state(npc_id),
		}

	time_system.set_paused(true)
	for npc_id in ACTIONS.keys():
		var preparation: Dictionary = daily_plan_system.begin_new_day_planning_for_npc(npc_id, "day_started")
		if not bool(preparation.get("ok", false)):
			_fail("Could not begin in-place planning: %s" % JSON.stringify(preparation))
			return
	await process_frame

	# Even a direct action tick must remain inert while the cross-day planning gate
	# has paused gameplay. No action, workstation, pose or coordinate may change.
	action_system._on_logical_time_tick(1800.0, 1.0)
	for npc_id in ACTIONS.keys():
		var baseline: Dictionary = baselines[npc_id]
		var node := _get_npc_node(npc_system, npc_id)
		var runtime: Dictionary = action_system.get_runtime_action_snapshot(npc_id)
		var formal: Dictionary = npc_system.get_formal_workstation_action_snapshot(npc_id)
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		if (
			str(state.get("current_action", "")) != str(ACTIONS[npc_id])
			or str(state.get("last_action_result", "")) != "daily_plan_pending_in_place"
			or node.global_position.distance_to(baseline.get("position", Vector3.ZERO)) > 0.001
			or node.debug_get_spatial_attachment_snapshot() != baseline.get("attachment", {})
			or str(runtime.get("phase", "")) != "active"
			or str(runtime.get("action_id", "")) != str(ACTIONS[npc_id])
			or absf(float(runtime.get("elapsed_seconds", -1.0)) - float(baseline.get("runtime", {}).get("elapsed_seconds", -2.0))) > 0.001
			or float(state.get("fatigue", -1.0)) != float(baseline.get("state", {}).get("fatigue", -2.0))
			or float(state.get("satiety", -1.0)) != float(baseline.get("state", {}).get("satiety", -2.0))
			or float(state.get("hp", -1.0)) != float(baseline.get("state", {}).get("hp", -2.0))
			or str(formal.get("session", {}).get("workstation_id", "")) != str(baseline.get("formal", {}).get("session", {}).get("workstation_id", ""))
			or not _workstation_occupied_by(building_system, str(formal.get("session", {}).get("workstation_id", "")), npc_id)
		):
			_fail("Cross-day planning changed an active actor: %s" % JSON.stringify({
				"npc_id": npc_id,
				"state": state,
				"runtime": runtime,
				"formal": formal,
			}))
			return

	var sleeper_art: Dictionary = _get_npc_node(npc_system, SLEEPER_ID).debug_get_character_art_snapshot()
	var prayer_art: Dictionary = _get_npc_node(npc_system, PRAYER_ID).debug_get_character_art_snapshot()
	if (
		str(sleeper_art.get("desired_state", "")) != "sleeping"
		or str(prayer_art.get("desired_state", "")) != "seated_prayer"
	):
		_fail("Planning did not preserve the lying/seated presentation")
		return

	# Installing the same new-day actions must adopt the exact runtime transactions.
	var current_hour := int(root.get_node("GameState").current_hour)
	for npc_id in ACTIONS.keys():
		if not daily_plan_system.set_npc_daily_plan(
			npc_id,
			_make_plan(current_hour, str(ACTIONS[npc_id])),
			false,
			"verify_p6r48_same_action"
		):
			_fail("Could not install same-action new-day plan: %s" % npc_id)
			return
	var same_results: Dictionary = daily_plan_system.execute_current_plan_for_all(true)
	for npc_id in ACTIONS.keys():
		var baseline: Dictionary = baselines[npc_id]
		var runtime: Dictionary = action_system.get_runtime_action_snapshot(npc_id)
		var node := _get_npc_node(npc_system, npc_id)
		if (
			not bool(same_results.get(npc_id, {}).get("ok", false))
			or str(runtime.get("action_id", "")) != str(ACTIONS[npc_id])
			or absf(float(runtime.get("elapsed_seconds", -1.0)) - float(baseline.get("runtime", {}).get("elapsed_seconds", -2.0))) > 0.001
			or action_system.get_pending_action_id(npc_id) != ""
			or node.global_position.distance_to(baseline.get("position", Vector3.ZERO)) > 0.001
			or node.debug_get_spatial_attachment_snapshot() != baseline.get("attachment", {})
		):
			_fail("Same new-day action did not adopt the in-place runtime: %s" % JSON.stringify({
				"npc_id": npc_id,
				"result": same_results.get(npc_id, {}),
				"runtime": runtime,
			}))
			return

	# A genuinely different plan still releases the old workstation exactly when
	# that replacement is dispatched, rather than during planning.
	var worker_position_before_replace: Vector3 = _get_npc_node(npc_system, WORKER_ID).global_position
	daily_plan_system.begin_new_day_planning_for_npc(WORKER_ID, "day_started")
	daily_plan_system.set_npc_daily_plan(
		WORKER_ID,
		_make_plan(current_hour, "idle"),
		false,
		"verify_p6r48_replacement"
	)
	var replacement: Dictionary = daily_plan_system.execute_current_plan_for_npc(WORKER_ID, true)
	await process_frame
	if (
		not bool(replacement.get("ok", false))
		or str(npc_system.get_npc_state(WORKER_ID).get("current_action", "")) != "idle"
		or not str(npc_system.get_npc_state(WORKER_ID).get("current_workstation_id", "")).is_empty()
		or not action_system.get_runtime_action_snapshot(WORKER_ID).is_empty()
		or bool(npc_system.get_formal_workstation_action_snapshot(WORKER_ID).get("active", false))
		or _get_npc_node(npc_system, WORKER_ID).global_position.distance_to(worker_position_before_replace) > 0.25
	):
		_fail("Different new-day action did not release the old post cleanly: %s" % JSON.stringify({
			"result": replacement,
			"state": npc_system.get_npc_state(WORKER_ID),
		}))
		return

	print("T1505-P6R55 cross-day planning pose hold verification passed")
	quit(0)


func _wait_for_active(action_system: Node, time_system: Node, npc_id: String, action_id: String, max_frames: int = 2400) -> bool:
	for _frame in range(max_frames):
		time_system.set_paused(false)
		await physics_frame
		var runtime: Dictionary = action_system.get_runtime_action_snapshot(npc_id)
		if str(runtime.get("phase", "")) == "active" and str(runtime.get("action_id", "")) == action_id:
			return true
	return false


func _make_plan(current_hour: int, action_id: String) -> Array:
	var plan: Array = []
	for hour in range(24):
		plan.append({
			"hour": hour,
			"action_id": action_id if hour == current_hour else "idle",
			"reason": "Verify cross-day in-place planning",
			"source": "verify_p6r48",
		})
	return plan


func _get_npc_node(npc_system: Node, npc_id: String) -> Node:
	var node_paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(node_paths.get(npc_id, NodePath("")))


func _workstation_occupied_by(building_system: Node, workstation_id: String, npc_id: String) -> bool:
	if workstation_id.is_empty():
		return false
	for building_id in ["dormitory", "chapel", "stable"]:
		var building: Dictionary = building_system.get_building(building_id)
		for raw_station in building.get("workstations", []):
			if raw_station is Dictionary and str(raw_station.get("id", "")) == workstation_id:
				return str(raw_station.get("occupied_by", "")) == npc_id
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
