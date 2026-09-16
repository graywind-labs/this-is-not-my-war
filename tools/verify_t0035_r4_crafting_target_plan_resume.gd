extends SceneTree


const CASES := [
	{
		"npc_id": "blacksmith_01",
		"building_id": "blacksmith",
		"action_id": "work_blacksmith",
		"first_recipe_id": "craft_iron_bracers",
		"next_recipe_id": "craft_iron_helmet",
		"summary": "格伦的铁匠铺制造中断了：守备官更改了制造目标。",
	},
	{
		"npc_id": "engineer_01",
		"building_id": "workshop",
		"action_id": "work_workshop",
		"first_recipe_id": "craft_bow",
		"next_recipe_id": "craft_crossbow",
		"summary": "欧文的工械坊制造中断了：守备官更改了制造目标。",
	},
]


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Failed to load Main.tscn")
		return
	root.add_child(packed.instantiate())
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

	time_system.set_current_time(1, 17, 0, 0)
	time_system.set_paused(false)
	resource_system.add_resource("iron", 50)
	resource_system.add_resource("wood", 50)
	for test_case in CASES:
		if not await _verify_case(
			test_case,
			time_system,
			npc_system,
			action_system,
			crafting_system,
			memory_system,
			daily_plan_system
		):
			return

	print("T0035-R4 crafting target plan resume verification passed.")
	quit(0)


func _verify_case(
	test_case: Dictionary,
	time_system: Node,
	npc_system: Node,
	action_system: Node,
	crafting_system: Node,
	memory_system: Node,
	daily_plan_system: Node
) -> bool:
	var npc_id := str(test_case.get("npc_id", ""))
	var building_id := str(test_case.get("building_id", ""))
	var action_id := str(test_case.get("action_id", ""))
	daily_plan_system.set_auto_execution_enabled(false)
	action_system.interrupt_npc_action(npc_id, "verify_target_resume_reset", true)
	npc_system.debug_enter_location_immediately(npc_id, building_id)
	var npc_node := _get_npc_node(npc_system, npc_id)
	if npc_node == null:
		_fail("Could not resolve NPC actor: %s" % npc_id)
		return false
	npc_node.set("move_speed", 80.0)
	npc_system.update_npc_state(npc_id, {
		"fatigue": 0,
		"satiety": 100,
		"current_action": "idle",
		"last_action_result": "verify_target_resume_ready",
	})
	var selected: Dictionary = crafting_system.set_target(
		building_id,
		str(test_case.get("first_recipe_id", "")),
		true
	)
	if not bool(selected.get("ok", false)):
		_fail("Could not select initial recipe for %s: %s" % [building_id, JSON.stringify(selected)])
		return false

	var plan := _make_plan(action_id)
	if not daily_plan_system.set_npc_daily_plan(npc_id, plan, false, "verify_crafting_target_resume"):
		_fail("Could not install crafting plan for %s" % npc_id)
		return false
	daily_plan_system.set_auto_execution_enabled(true)
	var dispatch: Dictionary = daily_plan_system.execute_current_plan_for_npc(npc_id, true)
	if not bool(dispatch.get("ok", false)):
		_fail("Could not dispatch planned crafting for %s: %s" % [npc_id, JSON.stringify(dispatch)])
		return false
	if not await _wait_for_active(action_system, time_system, npc_id, action_id):
		_fail("Initial planned crafting did not become active for %s" % npc_id)
		return false

	var cycle_snapshots_before: Array = action_system.get_active_work_cycle_snapshots(
		building_id,
		[action_id]
	)
	if cycle_snapshots_before.is_empty():
		_fail("Initial active cycle snapshot is missing for %s" % npc_id)
		return false
	var cycle_before: Dictionary = cycle_snapshots_before[0]
	var old_revision := int(cycle_before.get("project_revision", -1))
	var failed_before := _count_events(memory_system.get_npc_daily_events(npc_id), "work_failed")
	var changed: Dictionary = crafting_system.set_target(
		building_id,
		str(test_case.get("next_recipe_id", "")),
		true
	)
	if not bool(changed.get("ok", false)):
		_fail("Could not switch recipe for %s: %s" % [building_id, JSON.stringify(changed)])
		return false
	if not (changed.get("resume_scheduled_npc_ids", []) as Array).has(npc_id):
		_fail("Target switch did not schedule the planned worker to resume: %s" % JSON.stringify(changed))
		return false
	var new_revision := int(changed.get("project_revision", -1))
	if new_revision <= old_revision:
		_fail("Target switch did not advance project revision for %s" % building_id)
		return false
	if not await _wait_for_active(action_system, time_system, npc_id, action_id):
		_fail("Planned crafting did not automatically resume for %s" % npc_id)
		return false

	var resumed_cycles: Array = action_system.get_active_work_cycle_snapshots(
		building_id,
		[action_id]
	)
	if resumed_cycles.is_empty():
		_fail("Resumed active cycle snapshot is missing for %s" % npc_id)
		return false
	var runtime: Dictionary = resumed_cycles[0]
	if (
		str(runtime.get("recipe_id", "")) != str(test_case.get("next_recipe_id", ""))
		or int(runtime.get("project_revision", -1)) != new_revision
	):
		_fail("Resumed cycle did not adopt the new recipe/revision: %s" % JSON.stringify(runtime))
		return false
	if str(daily_plan_system.get_current_plan_item(npc_id).get("action_id", "")) != action_id:
		_fail("Target switch changed the current hourly plan for %s" % npc_id)
		return false
	if (daily_plan_system.get("_reevaluating_npcs") as Dictionary).has(npc_id):
		_fail("Target switch incorrectly started a plan reevaluation for %s" % npc_id)
		return false
	var events: Array = memory_system.get_npc_daily_events(npc_id)
	if _count_events(events, "work_failed") != failed_before + 1:
		_fail("Target switch did not preserve exactly one interruption event for %s" % npc_id)
		return false
	var event := _find_last_event(events, "work_failed")
	var payload: Dictionary = event.get("payload", {}) if event.get("payload", {}) is Dictionary else {}
	if (
		str(payload.get("interruption_reason", "")) != "crafting_target_changed"
		or str(event.get("summary", "")) != str(test_case.get("summary", ""))
	):
		_fail("Target-switch interruption event changed unexpectedly: %s" % JSON.stringify(event))
		return false
	return true


func _make_plan(action_id: String) -> Array:
	var plan: Array = []
	for hour in range(24):
		plan.append({
			"hour": hour,
			"action_id": action_id if hour == 17 else "idle",
			"reason": "verify target-switch continuation",
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
	npc_id: String,
	action_id: String,
	max_frames: int = 1800
) -> bool:
	for _frame in range(max_frames):
		time_system.set_paused(false)
		await physics_frame
		var runtime: Dictionary = action_system.get_runtime_action_snapshot(npc_id)
		if str(runtime.get("phase", "")) == "active" and str(runtime.get("action_id", "")) == action_id:
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
