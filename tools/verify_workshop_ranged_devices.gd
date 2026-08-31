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
	if action_system == null or crafting_system == null or npc_system == null or building_system == null or resource_system == null or memory_system == null:
		_fail("Required workshop crafting systems not found")
		return

	var workshop_action: Dictionary = action_system.get_action("work_workshop")
	if str(workshop_action.get("location_required", "")) != "workshop":
		_fail("Workshop work action is not bound to workshop")
		return
	if str(workshop_action.get("skill", "")) != "工程" or str(workshop_action.get("stat", "")) != "intelligence":
		_fail("Workshop work should use engineering and intelligence")
		return
	if not bool(workshop_action.get("requires_crafting_target", false)):
		_fail("Workshop work must require a selected crafting target")
		return
	if not (workshop_action.get("input_resources", {}) as Dictionary).is_empty() or not (workshop_action.get("output_resources", {}) as Dictionary).is_empty():
		_fail("Workshop action must not retain legacy aggregate input/output resources")
		return

	var expected_catalog := {
		"craft_bow": ["item_bow", 3],
		"craft_crossbow": ["item_crossbow", 5],
		"craft_wall_ballista": ["item_wall_ballista", 9],
		"craft_wall_arrow_tower": ["item_wall_arrow_tower", 12],
	}
	for recipe_id in expected_catalog.keys():
		var expected: Array = expected_catalog[recipe_id]
		var recipe: Dictionary = crafting_system.get_recipe(str(recipe_id))
		if str(recipe.get("building_id", "")) != "workshop" or str(recipe.get("output_item_id", "")) != str(expected[0]) or (recipe.get("stages", []) as Array).size() != int(expected[1]):
			_fail("Workshop recipe catalog mismatch for %s" % recipe_id)
			return
	var engineer_id := "engineer_01"
	var blacksmith_id := "blacksmith_01"
	# A5-P5c routes workshop work through the real diagonal doorway. Keep the
	# production speed so this balance regression cannot orbit the narrow target
	# at an artificial 100 m/s.
	_set_debug_move_speed(engineer_id, 5.0)

	var base_duration := float(workshop_action.get("duration_seconds", 3600.0))
	var engineer_duration_level_1: float = action_system._get_effective_action_duration_seconds(workshop_action, engineer_id)
	var blacksmith_duration: float = action_system._get_effective_action_duration_seconds(workshop_action, blacksmith_id)
	if not (engineer_duration_level_1 < blacksmith_duration and engineer_duration_level_1 < base_duration):
		_fail("Engineering skill and intelligence did not shorten workshop work duration")
		return

	_set_profile_skill_and_intelligence(npc_system, blacksmith_id, 82, 4)
	var low_int_duration: float = action_system._get_effective_action_duration_seconds(workshop_action, blacksmith_id)
	if not engineer_duration_level_1 < low_int_duration:
		_fail("Intelligence did not improve workshop efficiency when engineering skill is comparable")
		return

	if not building_system.upgrade_building("workshop"):
		_fail("Failed to start workshop upgrade for efficiency verification")
		return
	building_system._on_logical_time_tick(99999.0, 1.0)
	if int(building_system.get_building("workshop").get("level", 1)) < 2:
		_fail("Workshop upgrade did not complete")
		return
	var engineer_duration_level_2: float = action_system._get_effective_action_duration_seconds(workshop_action, engineer_id)
	if not engineer_duration_level_2 < engineer_duration_level_1:
		_fail("Workshop level did not improve work efficiency")
		return

	crafting_system.set_target("workshop", "", true)
	npc_system.debug_enter_location_immediately(engineer_id, "workshop")
	npc_system.update_npc_state(engineer_id, {"satiety": 80, "fatigue": 20, "last_action_result": ""})
	if action_system.debug_assign_work(engineer_id, "workshop"):
		_fail("Workshop work should not start without a crafting target")
		return
	if str(npc_system.get_npc_state(engineer_id).get("last_action_result", "")) != "work_failed_crafting_target_missing":
		_fail("Missing workshop target did not expose crafting_target_missing")
		return

	resource_system.add_resource("wood", 30)
	resource_system.add_resource("iron", 10)
	var legacy_weapons_before := int(resource_system.get_resource("weapons"))
	var legacy_devices_before := int(resource_system.get_resource("defense_devices"))
	var bow_before := int(resource_system.get_resource("item_bow"))
	var wood_before_bow := int(resource_system.get_resource("wood"))
	var selected: Dictionary = crafting_system.set_target("workshop", "craft_bow", false)
	if not bool(selected.get("ok", false)):
		_fail("Failed to select bow recipe: %s" % JSON.stringify(selected))
		return

	var events_before := int(memory_system.get_npc_daily_events(engineer_id).size())
	if not await _complete_work_cycle(action_system, npc_system, engineer_id, engineer_duration_level_2):
		return
	var first_project: Dictionary = crafting_system.get_project_snapshot("workshop")
	if int(first_project.get("completed_stages", -1)) != 1 or int(resource_system.get_resource("wood")) != wood_before_bow - 1:
		_fail("One workshop work cycle must complete exactly one bow stage")
		return
	if int(resource_system.get_resource("item_bow")) != bow_before:
		_fail("Unfinished bow must not enter inventory")
		return
	var first_event := _find_event(_events_after(memory_system.get_npc_daily_events(engineer_id), events_before), "work_completed")
	var first_payload: Dictionary = first_event.get("payload", {})
	if str(first_payload.get("recipe_id", "")) != "craft_bow" or str(first_payload.get("target_item_id", "")) != "item_bow" or bool(first_payload.get("product_completed", true)):
		_fail("Workshop first-stage event has incorrect exact recipe/item state")
		return

	events_before = int(memory_system.get_npc_daily_events(engineer_id).size())
	if not await _complete_work_cycle(action_system, npc_system, engineer_id, engineer_duration_level_2):
		return
	if int(resource_system.get_resource("wood")) != wood_before_bow - 2 or int(resource_system.get_resource("item_bow")) != bow_before:
		_fail("Second bow stage should spend the second wood without completing the product")
		return
	events_before = int(memory_system.get_npc_daily_events(engineer_id).size())
	if not await _complete_work_cycle(action_system, npc_system, engineer_id, engineer_duration_level_2):
		return
	if int(resource_system.get_resource("wood")) != wood_before_bow - 2 or int(resource_system.get_resource("item_bow")) != bow_before + 1:
		_fail("Labor-only bow finishing stage did not add item_bow")
		return
	var bow_event := _find_event(_events_after(memory_system.get_npc_daily_events(engineer_id), events_before), "work_completed")
	var bow_payload: Dictionary = bow_event.get("payload", {})
	if not bool(bow_payload.get("product_completed", false)) or int((bow_payload.get("output_resources", {}) as Dictionary).get("item_bow", 0)) != 1:
		_fail("Final bow work event is missing exact item_bow output")
		return

	var ballista_before := int(resource_system.get_resource("item_wall_ballista"))
	var wood_before_ballista := int(resource_system.get_resource("wood"))
	var iron_before_ballista := int(resource_system.get_resource("iron"))
	selected = crafting_system.set_target("workshop", "craft_wall_ballista", false)
	if not bool(selected.get("ok", false)):
		_fail("Failed to select ballista recipe: %s" % JSON.stringify(selected))
		return
	for _stage in range(9):
		var project: Dictionary = crafting_system.get_project_snapshot("workshop")
		var stage_result: Dictionary = crafting_system.complete_stage("workshop", int(project.get("project_revision", -1)), engineer_id)
		if not bool(stage_result.get("ok", false)):
			_fail("Ballista stage completion failed: %s" % JSON.stringify(stage_result))
			return
	if int(resource_system.get_resource("item_wall_ballista")) != ballista_before + 1:
		_fail("Completed device did not enter item_wall_ballista inventory")
		return
	if int(resource_system.get_resource("wood")) != wood_before_ballista - 6 or int(resource_system.get_resource("iron")) != iron_before_ballista - 2:
		_fail("Ballista stages did not spend their exact six-wood/two-iron recipe")
		return
	if int(resource_system.get_resource("weapons")) != legacy_weapons_before or int(resource_system.get_resource("defense_devices")) != legacy_devices_before:
		_fail("Workshop crafting must not mutate deprecated weapons/device aggregates")
		return

	crafting_system.set_target("workshop", "craft_bow", false)
	resource_system.add_resource("wood", -999999)
	npc_system.update_npc_state(engineer_id, {"last_action_result": ""})
	if action_system.debug_assign_work(engineer_id, "workshop"):
		_fail("Workshop work should fail immediately when the selected stage material is missing")
		return
	if str(npc_system.get_npc_state(engineer_id).get("last_action_result", "")) != "work_failed_insufficient_stage_resources":
		_fail("Missing workshop stage material did not expose insufficient_stage_resources")
		return

	print("T0805 workshop staged ranged weapons and defense devices verification passed.")
	quit(0)


func _complete_work_cycle(action_system: Node, npc_system: Node, npc_id: String, duration: float) -> bool:
	npc_system.update_npc_state(npc_id, {"satiety": 80, "fatigue": 20, "last_action_result": ""})
	if not action_system.debug_assign_work(npc_id, "workshop"):
		_fail("Failed to assign workshop work")
		return false
	if not await _wait_until_current_action(npc_system, npc_id, "work_workshop"):
		_fail("Workshop work did not start")
		return false
	action_system._on_logical_time_tick(duration + 1.0, 1.0)
	if not await _wait_until_action_result(npc_system, npc_id, "completed_work_workshop"):
		_fail("Workshop work did not complete")
		return false
	return true


func _set_profile_skill_and_intelligence(npc_system: Node, npc_id: String, engineering_skill: int, intelligence: int) -> void:
	var profile: Dictionary = npc_system._profiles.get(npc_id, {}).duplicate(true)
	var skills: Dictionary = profile.get("skills", {}).duplicate(true)
	skills["工程"] = engineering_skill
	profile["skills"] = skills
	var stats: Dictionary = profile.get("stats", {}).duplicate(true)
	stats["intelligence"] = intelligence
	profile["stats"] = stats
	npc_system._profiles[npc_id] = profile


func _wait_until_action_result(npc_system: Node, npc_id: String, expected_result: String) -> bool:
	for _frame in range(600):
		await process_frame
		if str(npc_system.get_npc_state(npc_id).get("last_action_result", "")) == expected_result:
			return true
	return false


func _wait_until_current_action(npc_system: Node, npc_id: String, expected_action: String) -> bool:
	for _frame in range(1800):
		await physics_frame
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
