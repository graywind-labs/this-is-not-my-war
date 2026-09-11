extends SceneTree


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return

	root.add_child(main_scene.instantiate())
	await process_frame
	await physics_frame

	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var crafting_system := root.get_node_or_null("Main/Systems/CraftingSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	if action_system == null or crafting_system == null or npc_system == null or building_system == null or resource_system == null or memory_system == null or time_system == null:
		_fail("Required blacksmith crafting systems not found")
		return
	time_system.set_paused(false)

	var blacksmith_action: Dictionary = action_system.get_action("work_blacksmith")
	if str(blacksmith_action.get("location_required", "")) != "blacksmith":
		_fail("Blacksmith work action is not bound to blacksmith")
		return
	if str(blacksmith_action.get("skill", "")) != "打铁" or str(blacksmith_action.get("stat", "")) != "strength":
		_fail("Blacksmith work should use smithing and strength")
		return
	if not bool(blacksmith_action.get("requires_crafting_target", false)):
		_fail("Blacksmith work must require a selected crafting target")
		return
	if not (blacksmith_action.get("input_resources", {}) as Dictionary).is_empty() or not (blacksmith_action.get("output_resources", {}) as Dictionary).is_empty():
		_fail("Blacksmith action must not retain legacy aggregate input/output resources")
		return

	var blacksmith_id := "blacksmith_01"
	var engineer_id := "engineer_01"
	_set_debug_move_speed(blacksmith_id, 40.0)

	var base_duration := float(blacksmith_action.get("duration_seconds", 3600.0))
	var blacksmith_duration_level_1: float = action_system._get_effective_action_duration_seconds(blacksmith_action, blacksmith_id)
	var engineer_duration: float = action_system._get_effective_action_duration_seconds(blacksmith_action, engineer_id)
	if not (blacksmith_duration_level_1 < engineer_duration and blacksmith_duration_level_1 < base_duration):
		_fail("Smithing skill and strength did not shorten blacksmith work duration")
		return

	if not building_system.upgrade_building("blacksmith"):
		_fail("Failed to start blacksmith upgrade for efficiency verification")
		return
	building_system._on_logical_time_tick(99999.0, 1.0)
	if int(building_system.get_building("blacksmith").get("level", 1)) < 2:
		_fail("Blacksmith upgrade did not complete")
		return
	var blacksmith_duration_level_2: float = action_system._get_effective_action_duration_seconds(blacksmith_action, blacksmith_id)
	if not blacksmith_duration_level_2 < blacksmith_duration_level_1:
		_fail("Blacksmith level did not improve work efficiency")
		return

	crafting_system.set_target("blacksmith", "", true)
	npc_system.debug_enter_location_immediately(blacksmith_id, "blacksmith")
	npc_system.update_npc_state(blacksmith_id, {"satiety": 80, "fatigue": 20, "last_action_result": ""})
	if action_system.debug_assign_work(blacksmith_id, "blacksmith"):
		_fail("Blacksmith work should not start without a crafting target")
		return
	if str(npc_system.get_npc_state(blacksmith_id).get("last_action_result", "")) != "work_failed_crafting_target_missing":
		_fail("Missing blacksmith target did not expose crafting_target_missing")
		return

	var selected: Dictionary = crafting_system.set_target("blacksmith", "craft_iron_helmet", false)
	if not bool(selected.get("ok", false)):
		_fail("Failed to select iron helmet: %s" % JSON.stringify(selected))
		return
	var recipe: Dictionary = crafting_system.get_recipe("craft_iron_helmet")
	if str(recipe.get("output_item_id", "")) != "item_iron_helmet" or (recipe.get("stages", []) as Array).size() != 3:
		_fail("Iron helmet recipe should produce exact inventory in three stages")
		return

	resource_system.add_resource("iron", 10)
	var iron_before := int(resource_system.get_resource("iron"))
	var helmet_before := int(resource_system.get_resource("item_iron_helmet"))
	var legacy_weapons_before := int(resource_system.get_resource("weapons"))
	var legacy_armor_before := int(resource_system.get_resource("armor"))
	var events_before := int(memory_system.get_npc_daily_events(blacksmith_id).size())

	if not await _complete_work_cycle(action_system, npc_system, blacksmith_id, "blacksmith", blacksmith_duration_level_2):
		return
	var first_project: Dictionary = crafting_system.get_project_snapshot("blacksmith")
	if int(first_project.get("completed_stages", -1)) != 1 or int(resource_system.get_resource("iron")) != iron_before - 1:
		_fail("One blacksmith work cycle must complete exactly the first helmet stage and spend one iron")
		return
	if int(resource_system.get_resource("item_iron_helmet")) != helmet_before:
		_fail("An unfinished helmet must not enter inventory")
		return
	var first_event := _find_event(_events_after(memory_system.get_npc_daily_events(blacksmith_id), events_before), "work_completed")
	var first_payload: Dictionary = first_event.get("payload", {})
	if str(first_payload.get("recipe_id", "")) != "craft_iron_helmet" or str(first_payload.get("target_item_id", "")) != "item_iron_helmet":
		_fail("First-stage work event is missing its exact recipe/item identity")
		return
	if int((first_payload.get("completed_stage", {}) as Dictionary).get("index", 0)) != 1 or bool(first_payload.get("product_completed", true)):
		_fail("First-stage work event should report stage 1 without a completed product")
		return
	if int((first_payload.get("input_resources", {}) as Dictionary).get("iron", 0)) != 1 or not (first_payload.get("output_resources", {}) as Dictionary).is_empty():
		_fail("First helmet stage event has incorrect exact material/output data")
		return

	events_before = int(memory_system.get_npc_daily_events(blacksmith_id).size())
	if not await _complete_work_cycle(action_system, npc_system, blacksmith_id, "blacksmith", blacksmith_duration_level_2):
		return
	var second_project: Dictionary = crafting_system.get_project_snapshot("blacksmith")
	if int(second_project.get("completed_stages", -1)) != 2 or int(resource_system.get_resource("iron")) != iron_before - 2:
		_fail("Second helmet stage must spend the second iron without completing the product")
		return
	if int(resource_system.get_resource("item_iron_helmet")) != helmet_before:
		_fail("Helmet must remain unfinished before the labor-only fitting stage")
		return

	events_before = int(memory_system.get_npc_daily_events(blacksmith_id).size())
	if not await _complete_work_cycle(action_system, npc_system, blacksmith_id, "blacksmith", blacksmith_duration_level_2):
		return
	var completed_project: Dictionary = crafting_system.get_project_snapshot("blacksmith")
	if int(completed_project.get("completed_stages", -1)) != 0 or str(completed_project.get("target_recipe_id", "")) != "craft_iron_helmet":
		_fail("Finished helmet should reset stages while retaining the selected target")
		return
	if int(resource_system.get_resource("iron")) != iron_before - 2 or int(resource_system.get_resource("item_iron_helmet")) != helmet_before + 1:
		_fail("Finished helmet did not preserve the two-iron material total and add item_iron_helmet")
		return
	if int(resource_system.get_resource("weapons")) != legacy_weapons_before or int(resource_system.get_resource("armor")) != legacy_armor_before:
		_fail("Blacksmith crafting must not mutate deprecated weapons/armor aggregates")
		return
	var completion_event := _find_event(_events_after(memory_system.get_npc_daily_events(blacksmith_id), events_before), "work_completed")
	var completion_payload: Dictionary = completion_event.get("payload", {})
	if not bool(completion_payload.get("product_completed", false)) or int((completion_payload.get("output_resources", {}) as Dictionary).get("item_iron_helmet", 0)) != 1:
		_fail("Final blacksmith work event is missing exact helmet output")
		return

	resource_system.add_resource("iron", -999999)
	npc_system.update_npc_state(blacksmith_id, {"last_action_result": ""})
	if action_system.debug_assign_work(blacksmith_id, "blacksmith"):
		_fail("Blacksmith work should fail immediately when the current stage material is missing")
		return
	if str(npc_system.get_npc_state(blacksmith_id).get("last_action_result", "")) != "work_failed_insufficient_stage_resources":
		_fail("Missing stage material did not expose insufficient_stage_resources")
		return

	print("T0804 blacksmith staged metal gear verification passed.")
	quit(0)


func _complete_work_cycle(action_system: Node, npc_system: Node, npc_id: String, building_id: String, duration: float) -> bool:
	npc_system.update_npc_state(npc_id, {"satiety": 80, "fatigue": 20, "last_action_result": ""})
	if not action_system.debug_assign_work(npc_id, building_id):
		_fail("Failed to assign %s work" % building_id)
		return false
	if not await _wait_until_current_action(npc_system, npc_id, "work_%s" % building_id):
		_fail("%s work did not start: %s" % [building_id, JSON.stringify(npc_system.debug_get_spatial_migration_snapshot(npc_id))])
		return false
	action_system._on_logical_time_tick(duration + 1.0, 1.0)
	if not await _wait_until_action_result(npc_system, npc_id, "completed_work_%s" % building_id):
		_fail("%s work did not complete" % building_id)
		return false
	return true


func _wait_until_action_result(npc_system: Node, npc_id: String, expected_result: String) -> bool:
	for _frame in range(600):
		await process_frame
		if str(npc_system.get_npc_state(npc_id).get("last_action_result", "")) == expected_result:
			return true
	return false


func _wait_until_current_action(npc_system: Node, npc_id: String, expected_action: String) -> bool:
	for _frame in range(600):
		await create_timer(0.02).timeout
		if str(npc_system.get_npc_state(npc_id).get("current_action", "")) == expected_action:
			return true
	return false


func _events_after(events: Array, start_index: int) -> Array:
	var result: Array = []
	for index in range(start_index, events.size()):
		result.append(events[index])
	return result


func _find_event(events: Array, event_type: String) -> Dictionary:
	for index in range(events.size() - 1, -1, -1):
		var event = events[index]
		if event is Dictionary and str(event.get("type", "")) == event_type:
			return event
	return {}


func _set_debug_move_speed(npc_id: String, speed: float) -> void:
	var npc_root := root.get_node_or_null("Main/WorldRoot/Station/NPCs")
	if npc_root == null:
		return
	for npc_node in npc_root.get_children():
		if str(npc_node.get_meta("npc_id", "")) == npc_id and "move_speed" in npc_node:
			npc_node.move_speed = speed
			return


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
