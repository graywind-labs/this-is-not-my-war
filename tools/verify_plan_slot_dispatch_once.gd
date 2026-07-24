extends SceneTree


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Failed to load Main.tscn")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	if [time_system, npc_system, action_system, resource_system, memory_system, daily_plan_system].has(null):
		_fail("Plan-slot dispatch verification requires all scene systems")
		return

	const NPC_ID := "veteran_deputy_01"
	time_system.set_current_time(1, 8, 0, 0)
	daily_plan_system.set_auto_execution_enabled(true)
	resource_system.add_resource("meal", 8)
	if not npc_system.debug_enter_location_immediately(NPC_ID, "dining_hall"):
		_fail("Could not place plan actor in dining hall")
		return
	npc_system.update_npc_state(NPC_ID, {
		"satiety": 0,
		"current_action": "idle",
		"last_action_result": "verify_plan_slot_ready"
	})
	var plan := _make_eat_plan()
	if not daily_plan_system.set_npc_daily_plan(NPC_ID, plan, false, "verify_plan_slot"):
		_fail("Could not install short-action plan")
		return
	var first_version := int(daily_plan_system.call("_get_plan_version", NPC_ID))
	var eat_started_before := _count_events(memory_system.get_npc_daily_events(NPC_ID), "eat_started")

	var first_execute: Dictionary = daily_plan_system.execute_current_plan_for_npc(NPC_ID, true)
	if not bool(first_execute.get("ok", false)):
		_fail("Initial plan slot did not dispatch: %s" % str(first_execute))
		return
	if str(action_system.get_runtime_action_id(NPC_ID)) != "eat_at_dining_hall":
		_fail("Initial short action is not active")
		return
	action_system._on_logical_time_tick(1200.0, 1.0)
	for _index in range(3):
		await process_frame

	# Completion occurs 40 minutes before the hour changes. DailyPlanSystem receives
	# npc_state_changed synchronously, but this exact day/hour/plan_version slot is
	# already consumed and must remain idle instead of immediately eating again.
	var first_completed_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	if str(first_completed_state.get("last_action_result", "")) != "completed_eat":
		_fail("Short action did not complete before the hour boundary: %s" % str(first_completed_state))
		return
	if (
		str(first_completed_state.get("current_action", "")) != "idle"
		or not str(action_system.get_runtime_action_id(NPC_ID)).is_empty()
	):
		_fail("Completed plan slot was immediately re-dispatched in the same hour")
		return
	var started_after_completion := _count_events(memory_system.get_npc_daily_events(NPC_ID), "eat_started")
	if started_after_completion != eat_started_before + 1:
		_fail("Same slot created more than one eat_started event after automatic completion handling")
		return

	var explicit_same_slot: Dictionary = daily_plan_system.execute_current_plan_for_npc(NPC_ID, false)
	await process_frame
	if not str(action_system.get_runtime_action_id(NPC_ID)).is_empty():
		_fail("Explicit execute re-dispatched an already completed day/hour/plan_version slot: %s" % str(explicit_same_slot))
		return
	daily_plan_system.execute_current_plan_for_all(true)
	await process_frame
	if not str(action_system.get_runtime_action_id(NPC_ID)).is_empty():
		_fail("Forced batch execution re-dispatched an already completed plan slot")
		return
	if _count_events(memory_system.get_npc_daily_events(NPC_ID), "eat_started") != started_after_completion:
		_fail("Repeated same-slot execution wrote duplicate eat_started events")
		return
	if int(daily_plan_system.call("_get_plan_version", NPC_ID)) != first_version:
		_fail("Same-slot completion unexpectedly changed plan_version")
		return

	# A new hour is a new slot even when the plan_version is unchanged.
	time_system.set_current_time(1, 9, 0, 0)
	npc_system.update_npc_state(NPC_ID, {"satiety": 0})
	var next_hour_execute: Dictionary = daily_plan_system.execute_current_plan_for_npc(NPC_ID, false)
	if not bool(next_hour_execute.get("ok", false)):
		_fail("Unchanged plan_version did not dispatch in the next hour: %s" % str(next_hour_execute))
		return
	if str(action_system.get_runtime_action_id(NPC_ID)) != "eat_at_dining_hall":
		_fail("Next-hour slot did not start the short action")
		return
	if _count_events(memory_system.get_npc_daily_events(NPC_ID), "eat_started") != started_after_completion + 1:
		_fail("Next-hour slot did not create exactly one new eat_started event")
		return
	action_system._on_logical_time_tick(1200.0, 1.0)
	for _index in range(3):
		await process_frame
	if not str(action_system.get_runtime_action_id(NPC_ID)).is_empty():
		_fail("Next-hour completed slot was re-dispatched within hour 9")
		return
	var started_after_next_hour := _count_events(memory_system.get_npc_daily_events(NPC_ID), "eat_started")

	# Replacing the plan increments plan_version, so the same day/hour is executable
	# once under the new version. Its slot must then again be consumed exactly once.
	npc_system.update_npc_state(NPC_ID, {"satiety": 0})
	if not daily_plan_system.set_npc_daily_plan(NPC_ID, plan, false, "verify_new_plan_version"):
		_fail("Could not install replacement plan version")
		return
	var second_version := int(daily_plan_system.call("_get_plan_version", NPC_ID))
	if second_version <= first_version:
		_fail("Replacing the plan did not increment plan_version")
		return
	var new_version_execute: Dictionary = daily_plan_system.execute_current_plan_for_npc(NPC_ID, false)
	if not bool(new_version_execute.get("ok", false)):
		_fail("New plan_version did not dispatch in the same day/hour: %s" % str(new_version_execute))
		return
	if str(action_system.get_runtime_action_id(NPC_ID)) != "eat_at_dining_hall":
		_fail("New plan_version did not start the short action")
		return
	if _count_events(memory_system.get_npc_daily_events(NPC_ID), "eat_started") != started_after_next_hour + 1:
		_fail("New plan_version did not create exactly one new eat_started event")
		return
	action_system._on_logical_time_tick(1200.0, 1.0)
	for _index in range(3):
		await process_frame
	if not str(action_system.get_runtime_action_id(NPC_ID)).is_empty():
		_fail("New-version completed slot was re-dispatched more than once")
		return
	if _count_events(memory_system.get_npc_daily_events(NPC_ID), "eat_started") != started_after_next_hour + 1:
		_fail("New-version slot wrote duplicate eat_started events after completion")
		return

	print("T0025 plan slot single-dispatch verification passed.")
	quit(0)


func _make_eat_plan() -> Array:
	var plan: Array = []
	for hour in range(24):
		plan.append({
			"hour": hour,
			"action_id": "eat_at_dining_hall",
			"reason": "T0025 short action slot verification",
			"priority": 50,
			"target": {}
		})
	return plan


func _count_events(events: Array, event_type: String) -> int:
	var count := 0
	for raw_event in events:
		if raw_event is Dictionary and str((raw_event as Dictionary).get("type", "")) == event_type:
			count += 1
	return count


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
