extends SceneTree


const NPC_ID := "blacksmith_01"


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
	var crafting_system := root.get_node_or_null("Main/Systems/CraftingSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	if [time_system, npc_system, action_system, resource_system, crafting_system, memory_system, daily_plan_system].has(null):
		_fail("Required systems not found")
		return

	daily_plan_system.set_auto_execution_enabled(false)
	time_system.set_current_time(1, 13, 0, 0)
	time_system.set_paused(false)
	resource_system.add_resource("iron", 20)
	var target_result: Dictionary = crafting_system.set_target(
		"blacksmith",
		"craft_iron_bracers",
		true
	)
	if not bool(target_result.get("ok", false)):
		_fail("Could not set blacksmith target: %s" % JSON.stringify(target_result))
		return

	var npc_node := _get_npc_node(npc_system, NPC_ID)
	if npc_node == null:
		_fail("Could not resolve blacksmith actor node")
		return
	npc_node.set("move_speed", 80.0)
	npc_system.update_npc_state(NPC_ID, {
		"fatigue": 0,
		"satiety": 100,
		"current_action": "idle",
		"last_action_result": "verify_plan_hour_stop_ready",
	})

	var plan := _make_plan()
	plan[13] = {
		"hour": 13,
		"action_id": "work_blacksmith",
		"reason": "verify crafting before shift end",
		"priority": 50,
		"target": {},
	}
	if not daily_plan_system.set_npc_daily_plan(
		NPC_ID,
		plan,
		false,
		"verify_plan_hour_crafting_stop"
	):
		_fail("Could not install plan-hour crafting test plan")
		return
	var dispatch: Dictionary = daily_plan_system.execute_current_plan_for_npc(NPC_ID, true)
	if not bool(dispatch.get("ok", false)):
		_fail("Could not dispatch blacksmith work: %s" % JSON.stringify(dispatch))
		return
	if not await _wait_for_active(action_system, time_system, "work_blacksmith"):
		_fail("Blacksmith work did not become active")
		return

	var events_before: Array = memory_system.get_npc_daily_events(NPC_ID)
	var stopped_before := _count_events(events_before, "work_stopped")
	var failed_before := _count_events(events_before, "work_failed")
	time_system.set_current_time(1, 13, 59, 50)
	daily_plan_system.set_auto_execution_enabled(true)
	if not time_system.debug_advance_game_seconds(10.0):
		_fail("Could not advance across the plan hour boundary")
		return
	for _index in range(4):
		await process_frame

	var events_after: Array = memory_system.get_npc_daily_events(NPC_ID)
	if _count_events(events_after, "work_stopped") != stopped_before + 1:
		_fail("Plan-hour crafting stop did not create exactly one work_stopped event")
		return
	if _count_events(events_after, "work_failed") != failed_before:
		_fail("Plan-hour crafting stop was still recorded as work_failed")
		return
	var event := _find_last_event(events_after, "work_stopped")
	var payload: Dictionary = event.get("payload", {}) if event.get("payload", {}) is Dictionary else {}
	if str(payload.get("action_id", "")) != "work_blacksmith":
		_fail("work_stopped payload lost action_id: %s" % JSON.stringify(payload))
		return
	if str(payload.get("reason", "")) != "当前计划时段结束":
		_fail("work_stopped payload has the wrong narrative reason: %s" % JSON.stringify(payload))
		return
	if str(payload.get("interruption_reason", "")) != "plan_hour_changed":
		_fail("work_stopped payload lost the authoritative interruption reason: %s" % JSON.stringify(payload))
		return
	for field in ["building_id", "workstation_id"]:
		if str(payload.get(field, "")).is_empty():
			_fail("work_stopped payload is missing %s: %s" % [field, JSON.stringify(payload)])
			return
	if str(event.get("summary", "")) != "格伦因当前计划时段结束而停止制造。":
		_fail("Unexpected event-log summary: %s" % str(event.get("summary", "")))
		return

	# Non-schedule interruptions remain failures, but now retain their real cause.
	daily_plan_system.set_auto_execution_enabled(false)
	if not action_system.debug_assign_work(NPC_ID, "blacksmith"):
		_fail("Could not restart blacksmith work for ordinary-interruption coverage")
		return
	if not await _wait_for_active(action_system, time_system, "work_blacksmith"):
		_fail("Restarted blacksmith work did not become active")
		return
	var failed_before_manual_stop := _count_events(
		memory_system.get_npc_daily_events(NPC_ID),
		"work_failed"
	)
	if not action_system.interrupt_npc_action(NPC_ID, "verify_manual_interruption"):
		_fail("Could not interrupt restarted blacksmith work")
		return
	var events_after_manual_stop: Array = memory_system.get_npc_daily_events(NPC_ID)
	if _count_events(events_after_manual_stop, "work_failed") != failed_before_manual_stop + 1:
		_fail("Ordinary work interruption no longer creates work_failed")
		return
	var failed_event := _find_last_event(events_after_manual_stop, "work_failed")
	var failed_payload: Dictionary = (
		failed_event.get("payload", {})
		if failed_event.get("payload", {}) is Dictionary
		else {}
	)
	if str(failed_payload.get("interruption_reason", "")) != "verify_manual_interruption":
		_fail("Ordinary work interruption lost its real cause: %s" % JSON.stringify(failed_payload))
		return

	# A guard-officer target change is still a failure, but its visible reason must be explicit.
	if not action_system.debug_assign_work(NPC_ID, "blacksmith"):
		_fail("Could not restart blacksmith work for target-switch coverage")
		return
	if not await _wait_for_active(action_system, time_system, "work_blacksmith"):
		_fail("Target-switch coverage did not become active")
		return
	var target_switch_failed_before := _count_events(
		memory_system.get_npc_daily_events(NPC_ID),
		"work_failed"
	)
	var target_switch: Dictionary = crafting_system.set_target(
		"blacksmith",
		"craft_iron_helmet",
		true
	)
	if not bool(target_switch.get("ok", false)):
		_fail("Could not switch the active blacksmith target: %s" % JSON.stringify(target_switch))
		return
	var events_after_target_switch: Array = memory_system.get_npc_daily_events(NPC_ID)
	if _count_events(events_after_target_switch, "work_failed") != target_switch_failed_before + 1:
		_fail("Target switch did not create exactly one work_failed event")
		return
	var target_switch_event := _find_last_event(events_after_target_switch, "work_failed")
	var target_switch_payload: Dictionary = (
		target_switch_event.get("payload", {})
		if target_switch_event.get("payload", {}) is Dictionary
		else {}
	)
	if (
		str(target_switch_payload.get("reason", "")) != "守备官更改了制造目标"
		or str(target_switch_payload.get("interruption_reason", "")) != "crafting_target_changed"
		or str(target_switch_event.get("summary", ""))
		!= "格伦的铁匠铺制造中断了：守备官更改了制造目标。"
	):
		_fail("Target-switch failure did not expose its cause: %s" % JSON.stringify(target_switch_event))
		return

	print("T1505-P6R45 plan-hour crafting stop event verification passed.")
	quit(0)


func _make_plan() -> Array:
	var plan: Array = []
	for hour in range(24):
		plan.append({
			"hour": hour,
			"action_id": "idle",
			"reason": "verify inactive hour",
			"priority": 50,
			"target": {},
		})
	return plan


func _get_npc_node(npc_system: Node, npc_id: String) -> Node:
	var node_paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(node_paths.get(npc_id, NodePath("")))


func _wait_for_active(
	action_system: Node,
	time_system: Node,
	action_id: String,
	max_frames: int = 1800
) -> bool:
	for _frame in range(max_frames):
		time_system.set_paused(false)
		await physics_frame
		var runtime: Dictionary = action_system.get_runtime_action_snapshot(NPC_ID)
		if (
			str(runtime.get("phase", "")) == "active"
			and str(runtime.get("action_id", "")) == action_id
		):
			return true
	return false


func _count_events(events: Array, event_type: String) -> int:
	var count := 0
	for raw_event in events:
		if raw_event is Dictionary and str((raw_event as Dictionary).get("type", "")) == event_type:
			count += 1
	return count


func _find_last_event(events: Array, event_type: String) -> Dictionary:
	for index in range(events.size() - 1, -1, -1):
		var raw_event: Variant = events[index]
		if raw_event is Dictionary and str((raw_event as Dictionary).get("type", "")) == event_type:
			return (raw_event as Dictionary).duplicate(true)
	return {}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
