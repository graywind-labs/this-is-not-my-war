extends SceneTree


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		push_error("Failed to load Main.tscn")
		quit(1)
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	if action_system == null or npc_system == null or building_system == null or resource_system == null or memory_system == null:
		push_error("Required systems not found")
		quit(1)
		return

	var stable_action: Dictionary = action_system.get_action("work_stable")
	if str(stable_action.get("location_required", "")) != "stable":
		push_error("Stable work action is not bound to stable")
		quit(1)
		return
	if str(stable_action.get("skill", "")) != "养马":
		push_error("Stable work should use horsemanship skill")
		quit(1)
		return
	if str(stable_action.get("stat", "")) != "strength":
		push_error("Stable work should use strength as its attribute")
		quit(1)
		return
	if int(stable_action.get("input_resources", {}).get("grain", 0)) != 1:
		push_error("Stable work should consume 1 grain")
		quit(1)
		return
	if int(stable_action.get("output_resources", {}).get("horse_readiness", 0)) != 1:
		push_error("Stable work should output 1 base horse readiness")
		quit(1)
		return

	var stableman_id := "stableman_01"
	var cook_id := "cook_01"
	var blacksmith_id := "blacksmith_01"
	var engineer_id := "engineer_01"
	var priest_id := "priest_01"
	_set_debug_move_speed(stableman_id, 100.0)

	var base_duration := float(stable_action.get("duration_seconds", 3600.0))
	var stableman_duration_level_1: float = action_system._get_effective_action_duration_seconds(stable_action, stableman_id)
	var cook_duration: float = action_system._get_effective_action_duration_seconds(stable_action, cook_id)
	if not (stableman_duration_level_1 < cook_duration and stableman_duration_level_1 < base_duration):
		push_error("Horsemanship skill and strength did not shorten stable work duration")
		quit(1)
		return

	_set_profile_skill_and_strength(npc_system, engineer_id, 75, 3)
	var low_strength_duration: float = action_system._get_effective_action_duration_seconds(stable_action, engineer_id)
	if not stableman_duration_level_1 < low_strength_duration:
		push_error("Strength did not improve stable efficiency when horsemanship skill is comparable")
		quit(1)
		return

	var stableman_level_1_output := int(action_system._get_work_output_resources(stable_action, stableman_id).get("horse_readiness", 0))
	var cook_level_1_output := int(action_system._get_work_output_resources(stable_action, cook_id).get("horse_readiness", 0))
	if not stableman_level_1_output > cook_level_1_output:
		push_error("Horsemanship skill should increase horse readiness output")
		quit(1)
		return

	var priest_output := int(action_system._get_work_output_resources(stable_action, priest_id).get("horse_readiness", 0))
	if not stableman_level_1_output > priest_output:
		push_error("Stableman should out-produce low horsemanship workers at the stable")
		quit(1)
		return

	if not building_system.upgrade_building("stable"):
		push_error("Failed to start stable upgrade for output verification")
		quit(1)
		return
	building_system._on_logical_time_tick(99999.0, 1.0)
	var stable_after_upgrade: Dictionary = building_system.get_building("stable")
	if int(stable_after_upgrade.get("level", 1)) < 2:
		push_error("Stable upgrade did not complete")
		quit(1)
		return
	var stableman_level_2_output := int(action_system._get_work_output_resources(stable_action, stableman_id).get("horse_readiness", 0))
	if not stableman_level_2_output > stableman_level_1_output:
		push_error("Stable level should increase horse readiness output")
		quit(1)
		return
	var stableman_duration_level_2: float = action_system._get_effective_action_duration_seconds(stable_action, stableman_id)
	if not stableman_duration_level_2 < stableman_duration_level_1:
		push_error("Stable level did not improve work efficiency")
		quit(1)
		return

	resource_system.add_resource("grain", 10)
	resource_system.add_resource("horse_readiness", -9999)
	var grain_before := int(resource_system.get_resource("grain"))
	var readiness_before := int(resource_system.get_resource("horse_readiness"))
	var events_before := int(memory_system.get_npc_daily_events(stableman_id).size())

	npc_system.debug_enter_location_immediately(stableman_id, "stable")
	npc_system.update_npc_state(stableman_id, {"satiety": 80, "fatigue": 20, "last_action_result": ""})
	if not action_system.debug_assign_work(stableman_id, "stable"):
		push_error("Failed to assign stable work")
		quit(1)
		return
	if not await _wait_until_current_action(npc_system, stableman_id, "work_stable"):
		push_error("Stable work did not start")
		quit(1)
		return

	action_system._on_logical_time_tick(stableman_duration_level_2 + 1.0, 1.0)
	if not await _wait_until_action_result(npc_system, stableman_id, "completed_work_stable"):
		push_error("Stable work did not complete")
		quit(1)
		return
	if int(resource_system.get_resource("grain")) != grain_before - 1:
		push_error("Stable work did not consume exactly 1 grain")
		quit(1)
		return
	if int(resource_system.get_resource("horse_readiness")) != readiness_before + stableman_level_2_output:
		push_error("Stable work did not add scaled horse readiness")
		quit(1)
		return

	var work_completed := _find_event(_events_after(memory_system.get_npc_daily_events(stableman_id), events_before), "work_completed")
	if work_completed.is_empty() or str(work_completed.get("payload", {}).get("action_id", "")) != "work_stable":
		push_error("Stable completion event missing from NPC event log")
		quit(1)
		return
	if int(work_completed.get("payload", {}).get("input_resources", {}).get("grain", 0)) != 1:
		push_error("Stable completion event missing grain input")
		quit(1)
		return
	if int(work_completed.get("payload", {}).get("output_resources", {}).get("horse_readiness", 0)) != stableman_level_2_output:
		push_error("Stable completion event missing scaled horse readiness output")
		quit(1)
		return

	resource_system.add_resource("grain", -9999)
	npc_system.update_npc_state(stableman_id, {"last_action_result": ""})
	if action_system.debug_assign_work(stableman_id, "stable"):
		push_error("Stable work should fail immediately when grain is missing")
		quit(1)
		return
	var state_after_failure: Dictionary = npc_system.get_npc_state(stableman_id)
	if str(state_after_failure.get("last_action_result", "")) != "work_failed_no_resources":
		push_error("Missing grain did not set work_failed_no_resources")
		quit(1)
		return

	print("T0806 stable horse care verification passed.")
	quit(0)


func _set_profile_skill_and_strength(npc_system: Node, npc_id: String, horsemanship_skill: int, strength: int) -> void:
	var profile: Dictionary = npc_system._profiles.get(npc_id, {}).duplicate(true)
	var skills: Dictionary = profile.get("skills", {}).duplicate(true)
	skills["养马"] = horsemanship_skill
	profile["skills"] = skills
	var stats: Dictionary = profile.get("stats", {}).duplicate(true)
	stats["strength"] = strength
	profile["stats"] = stats
	npc_system._profiles[npc_id] = profile


func _wait_until_action_result(npc_system: Node, npc_id: String, expected_result: String) -> bool:
	for frame in range(600):
		await process_frame
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		if str(state.get("last_action_result", "")) == expected_result:
			return true
	return false


func _wait_until_current_action(npc_system: Node, npc_id: String, expected_action: String) -> bool:
	for frame in range(600):
		await process_frame
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		if str(state.get("current_action", "")) == expected_action:
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
