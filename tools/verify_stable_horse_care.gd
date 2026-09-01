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
	var horse_system := root.get_node_or_null("Main/Systems/HorseSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	if action_system == null or horse_system == null or npc_system == null or building_system == null or resource_system == null or memory_system == null or time_system == null:
		_fail("Required stable horse-care systems not found")
		return
	time_system.set_paused(false)

	var stable_action: Dictionary = action_system.get_action("work_stable")
	if str(stable_action.get("location_required", "")) != "stable":
		_fail("Stable work action is not bound to stable")
		return
	if str(stable_action.get("skill", "")) != "养马" or str(stable_action.get("stat", "")) != "strength":
		_fail("Stable work should use horsemanship and strength")
		return
	if not (stable_action.get("input_resources", {}) as Dictionary).is_empty() or not (stable_action.get("output_resources", {}) as Dictionary).is_empty():
		_fail("Stable work must not consume grain or output legacy horse_readiness")
		return

	var horse_ids: Array = horse_system.get_horse_ids()
	if horse_ids.size() != 2:
		_fail("Stable should start with exactly two horse entities")
		return
	var first_id := str(horse_ids[0])
	var second_id := str(horse_ids[1])
	var first: Dictionary = horse_system.get_horse_snapshot(first_id)
	var second: Dictionary = horse_system.get_horse_snapshot(second_id)
	if [str(first.get("name", "")), str(second.get("name", ""))] != ["栗风", "灰鬃"] or not bool(first.get("is_adult", false)) or not bool(second.get("is_adult", false)):
		_fail("Initial stable horse entities/names/adult state mismatch")
		return
	if not _assert_stable_counts(building_system, 2, 2, 0):
		return

	var stableman_id := "stableman_01"
	var cook_id := "cook_01"
	var engineer_id := "engineer_01"
	# Formal NavigationAgent avoidance clamps safely around fixtures; an artificial
	# 100 m/s speed can overshoot the short stall approach and orbit forever.
	_set_debug_move_speed(stableman_id, 40.0)

	var base_duration := float(stable_action.get("duration_seconds", 3600.0))
	var stableman_duration_level_1: float = action_system._get_effective_action_duration_seconds(stable_action, stableman_id)
	var cook_duration: float = action_system._get_effective_action_duration_seconds(stable_action, cook_id)
	if not (stableman_duration_level_1 < cook_duration and stableman_duration_level_1 < base_duration):
		_fail("Horsemanship skill and strength did not shorten stable work duration")
		return

	_set_profile_skill_and_strength(npc_system, engineer_id, 75, 3)
	var low_strength_duration: float = action_system._get_effective_action_duration_seconds(stable_action, engineer_id)
	if not stableman_duration_level_1 < low_strength_duration:
		_fail("Strength did not improve stable efficiency when horsemanship skill is comparable")
		return

	if not building_system.upgrade_building("stable"):
		_fail("Failed to start stable upgrade for efficiency verification")
		return
	building_system._on_logical_time_tick(99999.0, 1.0)
	if int(building_system.get_building("stable").get("level", 1)) < 2:
		_fail("Stable upgrade did not complete")
		return
	var stableman_duration_level_2: float = action_system._get_effective_action_duration_seconds(stable_action, stableman_id)
	if not stableman_duration_level_2 < stableman_duration_level_1:
		_fail("Stable level did not improve work efficiency")
		return

	var birth: Dictionary = horse_system.debug_force_birth()
	if not bool(birth.get("ok", false)):
		_fail("Failed to create a foal for caretaker verification")
		return
	birth = horse_system.confirm_pending_foal_name(
		str(birth.get("request_id", "")),
		str(birth.get("default_name", ""))
	)
	if not bool(birth.get("ok", false)):
		_fail("Failed to confirm the caretaker verification foal name")
		return
	var foal_id := str(birth.get("horse_id", ""))
	var foal: Dictionary = horse_system.get_horse_snapshot(foal_id)
	if bool(foal.get("is_adult", true)) or float(foal.get("growth", -1.0)) != 0.0:
		_fail("Forced birth should create a zero-growth foal entity")
		return
	if not _assert_stable_counts(building_system, 3, 2, 1):
		return
	horse_system.debug_advance(600.0)
	if float(horse_system.get_horse_snapshot(foal_id).get("growth", -1.0)) != 0.0:
		_fail("Foal growth must not advance without an active work_stable caretaker")
		return

	var grain_before_work := int(resource_system.get_resource("grain"))
	var legacy_readiness_before := int(resource_system.get_resource("horse_readiness"))
	var events_before := int(memory_system.get_npc_daily_events(stableman_id).size())
	npc_system.debug_enter_location_immediately(stableman_id, "stable")
	npc_system.update_npc_state(stableman_id, {"satiety": 80, "fatigue": 20, "last_action_result": ""})
	if not action_system.debug_assign_work(stableman_id, "stable"):
		_fail("Failed to assign stable work")
		return
	if not await _wait_until_current_action(npc_system, stableman_id, "work_stable"):
		_fail("Stable work did not start: state=%s runtime=%s spatial=%s" % [
			JSON.stringify(npc_system.get_npc_state(stableman_id)),
			JSON.stringify(action_system.get_runtime_action_snapshot(stableman_id)),
			JSON.stringify(npc_system.debug_get_spatial_migration_snapshot(stableman_id))
		])
		return

	horse_system.debug_advance(600.0)
	foal = horse_system.get_horse_snapshot(foal_id)
	first = horse_system.get_horse_snapshot(first_id)
	if float(foal.get("growth", 0.0)) <= 0.0:
		_fail("Active stable work did not advance foal growth through HorseSystem")
		return
	if float(first.get("care_bonus_cap", 0.0)) <= 0.0:
		_fail("Active horsemanship care did not establish a skill-scaled bonus HP cap")
		return
	if int(resource_system.get_resource("grain")) != grain_before_work:
		_fail("Stable work itself must not consume grain")
		return
	if int(resource_system.get_resource("horse_readiness")) != legacy_readiness_before:
		_fail("Stable work must not mutate deprecated horse_readiness inventory")
		return

	action_system._on_logical_time_tick(stableman_duration_level_2 + 1.0, 1.0)
	if not await _wait_until_action_result(npc_system, stableman_id, "completed_work_stable"):
		_fail("Stable work did not complete")
		return
	var work_completed := _find_event(_events_after(memory_system.get_npc_daily_events(stableman_id), events_before), "work_completed")
	var payload: Dictionary = work_completed.get("payload", {})
	if str(payload.get("action_id", "")) != "work_stable":
		_fail("Stable completion event missing from NPC event log")
		return
	if not (payload.get("input_resources", {}) as Dictionary).is_empty() or not (payload.get("output_resources", {}) as Dictionary).is_empty():
		_fail("Stable completion event must not claim aggregate resource input/output")
		return

	resource_system.add_resource("grain", -999999)
	resource_system.add_resource("grain", 2)
	var grain_before_feeding := int(resource_system.get_resource("grain"))
	_set_horse_runtime(horse_system, second_id, {"satiety": 60.0, "feeding": {"active": false, "elapsed_seconds": 0.0, "waiting_for_grain": false}})
	horse_system.debug_advance(60.0)
	second = horse_system.get_horse_snapshot(second_id)
	if not bool((second.get("feeding", {}) as Dictionary).get("active", false)):
		_fail("Hungry horse in the stable did not start its own feeding cycle")
		return
	horse_system.debug_advance(1140.0)
	if int(resource_system.get_resource("grain")) != grain_before_feeding:
		_fail("Horse feeding must not spend grain before the cycle finishes")
		return
	horse_system.debug_advance(60.0)
	second = horse_system.get_horse_snapshot(second_id)
	if int(resource_system.get_resource("grain")) != grain_before_feeding - 1 or bool((second.get("feeding", {}) as Dictionary).get("active", false)):
		_fail("Completed horse feeding cycle did not atomically spend one grain")
		return

	resource_system.add_resource("grain", -999999)
	npc_system.update_npc_state(stableman_id, {"satiety": 80, "fatigue": 20, "last_action_result": ""})
	if not action_system.debug_assign_work(stableman_id, "stable"):
		_fail("Stable caretaker work should still start when grain inventory is empty")
		return
	if not await _wait_until_current_action(npc_system, stableman_id, "work_stable"):
		_fail("Zero-grain stable work did not become active")
		return
	action_system.interrupt_npc_action(stableman_id, "stable_verification_complete")

	print("T0806 stable horse entity care verification passed.")
	quit(0)


func _assert_stable_counts(building_system: Node, total: int, adult: int, foal: int) -> bool:
	var state: Dictionary = building_system.get_building_special_state_section("stable", "horses")
	if int(state.get("total", -1)) != total or int(state.get("adult", -1)) != adult or int(state.get("foal", -1)) != foal:
		_fail("Stable horse special-state count mismatch: %s" % JSON.stringify(state))
		return false
	return true


func _set_profile_skill_and_strength(npc_system: Node, npc_id: String, horsemanship_skill: int, strength: int) -> void:
	var profile: Dictionary = npc_system._profiles.get(npc_id, {}).duplicate(true)
	var skills: Dictionary = profile.get("skills", {}).duplicate(true)
	skills["养马"] = horsemanship_skill
	profile["skills"] = skills
	var stats: Dictionary = profile.get("stats", {}).duplicate(true)
	stats["strength"] = strength
	profile["stats"] = stats
	npc_system._profiles[npc_id] = profile


func _set_horse_runtime(horse_system: Node, horse_id: String, updates: Dictionary) -> void:
	var horse: Dictionary = horse_system._horses.get(horse_id, {}).duplicate(true)
	for key in updates.keys():
		horse[key] = updates[key]
	horse_system._horses[horse_id] = horse


func _wait_until_action_result(npc_system: Node, npc_id: String, expected_result: String) -> bool:
	for _frame in range(1800):
		await process_frame
		if str(npc_system.get_npc_state(npc_id).get("last_action_result", "")) == expected_result:
			return true
	return false


func _wait_until_current_action(npc_system: Node, npc_id: String, expected_action: String) -> bool:
	for _frame in range(1800):
		await process_frame
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
