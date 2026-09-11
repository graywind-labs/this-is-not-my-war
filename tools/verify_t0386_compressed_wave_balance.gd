extends SceneTree


const EXPECTED_WAVE_TIMES := [[1, 23], [3, 8], [4, 4], [5, 12], [6, 18]]
const EXPECTED_INTERVAL_HOURS := [33.0, 20.0, 32.0, 30.0]
const EXPECTED_GLEN_HOURS := [3.573473, 3.573473, 13.160553, 31.801137, 37.727063]
const EXPECTED_OWEN_HOURS := [6.655961, 9.106959, 20.289757, 29.813566, 41.718328]
const GLEN_STAGE_CHECKPOINTS := [4, 4, 15, 37, 44]
const OWEN_WORKED_STAGE_CHECKPOINTS := [8, 11, 25, 37, 52]


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	root.add_child(main_scene.instantiate())
	await process_frame
	await physics_frame

	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var crafting_system := root.get_node_or_null("Main/Systems/CraftingSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	if action_system == null or combat_system == null or crafting_system == null or resource_system == null:
		_fail("T0386 required systems are missing")
		return

	if int(action_system.get_action("work_blacksmith").get("duration_seconds", 0)) != 4800:
		_fail("Blacksmith base stage must be 4800 seconds")
		return
	if int(action_system.get_action("work_workshop").get("duration_seconds", 0)) != 4500:
		_fail("Workshop base stage must be 4500 seconds")
		return

	var trigger_hours: Array[float] = []
	for index in range(EXPECTED_WAVE_TIMES.size()):
		var wave: Dictionary = combat_system.get_wave_config(index + 1)
		var expected: Array = EXPECTED_WAVE_TIMES[index]
		if int(wave.get("trigger_day", 0)) != int(expected[0]) or int(wave.get("trigger_hour", -1)) != int(expected[1]):
			_fail("Wave %d schedule mismatch" % (index + 1))
			return
		trigger_hours.append(float((int(expected[0]) - 1) * 24 + int(expected[1])))
	for index in range(EXPECTED_INTERVAL_HOURS.size()):
		if not is_equal_approx(trigger_hours[index + 1] - trigger_hours[index], EXPECTED_INTERVAL_HOURS[index]):
			_fail("Interwave interval %d mismatch" % (index + 1))
			return

	var project: Dictionary = crafting_system.get_project_snapshot("workshop")
	if (
		str(project.get("target_recipe_id", "")) != "craft_wall_arrow_tower"
		or int(project.get("completed_stages", 0)) != 4
		or int(project.get("total_stages", 0)) != 12
		or str(project.get("current_stage_id", "")) != "reinforce_tower_frame"
	):
		_fail("Initial workshop project is not the confirmed 4/12 arrow tower")
		return
	var initial_projects: Dictionary = crafting_system.debug_get_snapshot().get("initial_projects", {})
	var invested: Dictionary = (initial_projects.get("workshop", {}) as Dictionary).get("invested_resources", {})
	if int(invested.get("wood", 0)) != 4 or int(resource_system.get_resource("wood")) != 8:
		_fail("Initial wood must preserve 8 loose + 4 invested")
		return
	if int(resource_system.get_resource("wood")) + int(invested.get("wood", 0)) != 12:
		_fail("Initial wood endowment invariant is broken")
		return
	var switch_result: Dictionary = crafting_system.set_target("workshop", "craft_bow", false)
	if str(switch_result.get("reason", "")) != "confirmation_required" or int(resource_system.get_resource("wood")) != 8:
		_fail("Switching away from the inherited project must require confirmation without refunding wood")
		return

	for index in range(GLEN_STAGE_CHECKPOINTS.size()):
		var glen_hours := _cumulative_hours(4800.0, GLEN_STAGE_CHECKPOINTS[index])
		var owen_hours := _cumulative_hours(4500.0, OWEN_WORKED_STAGE_CHECKPOINTS[index])
		if absf(glen_hours - EXPECTED_GLEN_HOURS[index]) > 0.00001:
			_fail("Glen cumulative hours mismatch at wave %d: %.6f" % [index + 1, glen_hours])
			return
		if absf(owen_hours - EXPECTED_OWEN_HOURS[index]) > 0.00001:
			_fail("Owen cumulative hours mismatch at wave %d: %.6f" % [index + 1, owen_hours])
			return

	print("T0386 compressed-wave balance verification passed.")
	quit(0)


func _cumulative_hours(base_duration_seconds: float, stage_count: int) -> float:
	var total_seconds := 0.0
	for stage_index in range(stage_count):
		var skill := mini(100, 82 + stage_index)
		var speed_multiplier := 1.0 + float(skill) / 100.0 * 0.5 + 3.0 * 0.025
		total_seconds += base_duration_seconds / speed_multiplier
	return total_seconds / 3600.0


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
