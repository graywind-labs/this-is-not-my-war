extends SceneTree


const MAIN_PATH := "res://scenes/main/Main.tscn"
const ACTOR_ROOT_PATH := "Main/WorldRoot/FormalStationLayout/FormalEnemies"
const DIRECT_TARGETS := ["front_gate", "warehouse", "main_hall"]
const FORBIDDEN_ROAD_STAGES := ["reveal", "approach_mid", "contact", "gate_turn", "north_junction", "plaza_junction"]

var _failed := false


func _init() -> void:
	var main_scene := load(MAIN_PATH) as PackedScene
	if main_scene == null:
		_fail("Main.tscn unavailable")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame
	await physics_frame
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	if combat_system == null or building_system == null:
		_fail("A4-P5 runtime dependencies unavailable")
		return

	var start: Dictionary = combat_system.debug_run_formal_first_wave_slice()
	await physics_frame
	var actor_root := root.get_node_or_null(ACTOR_ROOT_PATH)
	if not bool(start.get("ok", false)) or int(start.get("spawned_count", 0)) != 8 or actor_root == null:
		_fail("Formal first wave did not start: %s" % start)
		return
	var actor_count := 0
	for child in actor_root.get_children():
		if not child is ActorMotionBody or not child.name.begins_with("FormalWaveEnemyFoot"):
			continue
		actor_count += 1
		var actor := child as ActorMotionBody
		actor.configure_profile("enemy_foot", {
			"profile": {"base_speed": 12.0, "acceleration": 28.0},
			"navigation_agent": {"target_desired_distance": 0.5, "path_desired_distance": 0.55},
			"stuck_recovery": {"fail_after_seconds": 20.0}
		})
		actor.navigation_agent.max_speed = 15.0
		if actor.get_node_or_null("BodyCollision") == null or actor.get_node_or_null("NavigationAgent3D") == null:
			_fail("Formal actor lacks collision/navigation: %s" % actor.name)
			return
	if actor_count != 8 or combat_system.get_active_enemy_count() != 8:
		_fail("First wave is not eight independent actors: %s / %s" % [actor_count, combat_system.debug_get_formal_first_wave_slice_snapshot()])
		return
	var initial_snapshot: Dictionary = combat_system.debug_get_formal_first_wave_slice_snapshot()
	for raw_slice in initial_snapshot.get("slices", []):
		var initial_slice := raw_slice as Dictionary
		if (
			initial_slice.get("target_sequence", []) != DIRECT_TARGETS
			or bool(initial_slice.get("roads_affect_navigation", true))
			or str(initial_slice.get("target_stage_id", "")) != "front_gate"
			or initial_slice.get("completed_stage_ids", []) != ["spawn"]
		):
			_fail("First wave did not start with direct road-independent targeting: %s" % initial_slice)
			return
	var initial_slices := initial_snapshot.get("slices", []) as Array
	if not initial_slices.is_empty() and str((initial_slices[0] as Dictionary).get("movement_model", "")) == "dynamic_combat_pressure":
		var compatibility_stop: Dictionary = combat_system.debug_stop_formal_first_wave_slice("p5_replaced_by_p7")
		await process_frame
		if not bool(compatibility_stop.get("ok", false)) or combat_system.get_active_enemy_count() != 0:
			_fail("P5 compatibility cleanup failed: %s" % compatibility_stop)
			return
		print("T0129C A4-P5 historical entry now delegates to P7 dynamic pressure: 8 solid actors")
		quit(0)
		return

	var gate_hp_before := int(building_system.get_building("front_gate").get("hp", -1))
	var early_step: Dictionary = combat_system.debug_step_enemy_ai(60.0)
	if int(building_system.get_building("front_gate").get("hp", -2)) != gate_hp_before or not (early_step.get("attacks", []) as Array).is_empty():
		_fail("Enemies attacked before physical gate arrival: %s" % early_step)
		return
	if not await _wait_for_any_stage(combat_system, "front_gate", 2400):
		_fail("No enemy physically reached front gate: %s" % combat_system.debug_get_formal_first_wave_slice_snapshot())
		return
	var gate_arrival: Dictionary = combat_system.debug_get_formal_first_wave_slice_snapshot()
	if int(gate_arrival.get("navigation_failure_count", -1)) != 0 or float(gate_arrival.get("minimum_pair_distance", 0.0)) < 0.78 or int(gate_arrival.get("avoidance_callback_count", 0)) <= 0:
		_fail("First-wave avoidance/collision contract failed: %s" % gate_arrival)
		return

	var gate_attack := _commit_first_damage(combat_system, building_system, "front_gate", gate_hp_before)
	if int(building_system.get_building("front_gate").get("hp", -1)) >= gate_hp_before:
		_fail("Arrived enemies did not attack gate: %s" % gate_attack)
		return
	var victim := _find_slice_at_stage(gate_arrival, "front_gate")
	var victim_id := str(victim.get("enemy_id", ""))
	var victim_position: Vector3 = victim.get("world_position", Vector3.ZERO)
	var defeat: Dictionary = combat_system.apply_enemy_area_damage(victim_position, 0.2, 1000.0, {"max_targets": 1, "source_type": "verification"})
	await process_frame
	if int(defeat.get("defeated_count", 0)) != 1 or combat_system.get_active_enemy_count() != 7 or combat_system.get_enemy(victim_id).size() != 0:
		_fail("Independent enemy defeat cleanup failed: %s" % defeat)
		return

	building_system.debug_damage_building("front_gate", 9999)
	combat_system.debug_step_enemy_ai(60.0)
	var warehouse_hp_before := int(building_system.get_building("warehouse").get("hp", -1))
	if not await _wait_for_any_stage(combat_system, "warehouse", 900):
		_fail("No surviving enemy reached warehouse: %s" % combat_system.debug_get_formal_first_wave_slice_snapshot())
		return
	var warehouse_arrival: Dictionary = combat_system.debug_get_formal_first_wave_slice_snapshot()
	for raw_slice in warehouse_arrival.get("slices", []):
		var warehouse_slice := raw_slice as Dictionary
		if bool(warehouse_slice.get("warehouse_combat_authority_committed", false)) and str(warehouse_slice.get("current_stage_id", "")) != "warehouse":
			_fail("Warehouse attack authority was committed without physical arrival: %s" % warehouse_slice)
			return
	if int(building_system.get_building("warehouse").get("hp", -2)) > warehouse_hp_before:
		_fail("Warehouse HP increased unexpectedly")
		return

	var warehouse_attack := _commit_first_damage(combat_system, building_system, "warehouse", warehouse_hp_before)
	if int(building_system.get_building("warehouse").get("hp", -1)) >= warehouse_hp_before:
		_fail("Arrived enemies did not attack warehouse: %s" % warehouse_attack)
		return
	building_system.debug_damage_building("warehouse", 9999)
	combat_system.debug_step_enemy_ai(60.0)
	if not await _wait_for_all_stage(combat_system, "main_hall", 1200):
		_fail("Surviving enemies did not reach main hall: %s" % combat_system.debug_get_formal_first_wave_slice_snapshot())
		return
	var hall_arrival: Dictionary = combat_system.debug_get_formal_first_wave_slice_snapshot()
	var hall_slot_positions: Array[Vector3] = []
	for raw_slice in hall_arrival.get("slices", []):
		var slice := raw_slice as Dictionary
		var completed_ids := slice.get("completed_stage_ids", []) as Array
		for forbidden_stage in FORBIDDEN_ROAD_STAGES:
			if forbidden_stage in completed_ids:
				_fail("An enemy was still forced through a presentation-road stage: %s" % slice)
				return
		if str(slice.get("current_stage_id", "")) != "main_hall" or not bool(slice.get("attack_unlocked", false)):
			_fail("An enemy did not physically occupy a main-hall attack slot: %s" % slice)
			return
		if bool(slice.get("main_hall_combat_authority_committed", false)) and str(slice.get("current_stage_id", "")) != "main_hall":
			_fail("Main-hall attack authority was committed without physical arrival: %s" % slice)
			return
		hall_slot_positions.append(slice.get("attack_slot_position", Vector3.ZERO))
	var minimum_hall_slot_distance := _minimum_pair_distance(hall_slot_positions)
	var maximum_hall_slot_distance := _maximum_pair_distance(hall_slot_positions)
	var hall_z_min := INF
	var hall_z_max := -INF
	for slot_position in hall_slot_positions:
		hall_z_min = minf(hall_z_min, slot_position.z)
		hall_z_max = maxf(hall_z_max, slot_position.z)
	if (
		hall_slot_positions.size() != combat_system.get_active_enemy_count()
		or minimum_hall_slot_distance < 1.0
		or maximum_hall_slot_distance > 17.0
		or hall_z_max - hall_z_min > 0.5
		or int(hall_arrival.get("navigation_failure_count", -1)) != 0
	):
		_fail("Main-hall compact front attack line was not reachable and non-overlapping: %s" % hall_arrival)
		return
	var main_hall_hp_before := int(building_system.get_building("main_hall").get("hp", -1))
	var hall_attack: Dictionary = combat_system.debug_step_enemy_ai(60.0)
	if (hall_attack.get("attacks", []) as Array).is_empty() or int(building_system.get_building("main_hall").get("hp", -1)) >= main_hall_hp_before:
		_fail("Arrived wave did not attack main hall: %s" % hall_attack)
		return

	var stop: Dictionary = combat_system.debug_stop_formal_first_wave_slice("verification_complete")
	await process_frame
	await process_frame
	if not bool(stop.get("ok", false)) or combat_system.get_active_enemy_count() != 0:
		_fail("Formal first-wave cleanup failed: %s" % stop)
		return
	for child in actor_root.get_children():
		if child.name.begins_with("FormalWaveEnemyFoot"):
			_fail("Formal first-wave actor remained after cleanup: %s" % child.name)
			return
	print("T0129C A4-P5R direct-assault first-wave verification passed: %s" % JSON.stringify({
		"spawned": 8,
		"survived_after_independent_defeat": 7,
		"target_sequence": DIRECT_TARGETS,
		"roads_affect_navigation": false,
		"minimum_gate_pair_distance": gate_arrival.get("minimum_pair_distance"),
		"minimum_main_hall_slot_distance": minimum_hall_slot_distance,
		"maximum_main_hall_slot_distance": maximum_hall_slot_distance,
		"main_hall_slot_depth_spread": hall_z_max - hall_z_min,
		"avoidance_callbacks": gate_arrival.get("avoidance_callback_count"),
		"active_enemy_count_after": combat_system.get_active_enemy_count()
	}))
	quit(0)


func _wait_for_all_stage(combat_system: Node, stage_id: String, frame_limit: int) -> bool:
	for _frame in range(frame_limit):
		await physics_frame
		var snapshot: Dictionary = combat_system.debug_get_formal_first_wave_slice_snapshot()
		if int(snapshot.get("navigation_failure_count", 0)) > 0:
			return false
		var arrived_count := 0
		for raw_slice in snapshot.get("slices", []):
			var slice := raw_slice as Dictionary
			if str(slice.get("current_stage_id", "")) == stage_id and bool(slice.get("attack_unlocked", false)):
				arrived_count += 1
		if arrived_count == combat_system.get_active_enemy_count():
			return true
	return false


func _wait_for_any_stage(combat_system: Node, stage_id: String, frame_limit: int) -> bool:
	for _frame in range(frame_limit):
		await physics_frame
		var snapshot: Dictionary = combat_system.debug_get_formal_first_wave_slice_snapshot()
		if int(snapshot.get("navigation_failure_count", 0)) > 0:
			return false
		for raw_slice in snapshot.get("slices", []):
			var slice := raw_slice as Dictionary
			if str(slice.get("current_stage_id", "")) == stage_id and bool(slice.get("attack_unlocked", false)):
				return true
	return false


func _find_slice_at_stage(snapshot: Dictionary, stage_id: String) -> Dictionary:
	for raw_slice in snapshot.get("slices", []):
		var slice := raw_slice as Dictionary
		if str(slice.get("current_stage_id", "")) == stage_id:
			return slice
	return {}


func _commit_first_damage(combat_system: Node, building_system: Node, building_id: String, hp_before: int) -> Dictionary:
	var result: Dictionary = {}
	for _attack_round in range(6):
		result = combat_system.debug_step_enemy_ai(3600.0)
		if int(building_system.get_building(building_id).get("hp", -1)) < hp_before:
			return result
	return result


func _minimum_pair_distance(positions: Array[Vector3]) -> float:
	var minimum_distance := INF
	for first_index in range(positions.size()):
		for second_index in range(first_index + 1, positions.size()):
			minimum_distance = minf(minimum_distance, positions[first_index].distance_to(positions[second_index]))
	return minimum_distance if is_finite(minimum_distance) else -1.0


func _maximum_pair_distance(positions: Array[Vector3]) -> float:
	var maximum_distance := 0.0
	for first_index in range(positions.size()):
		for second_index in range(first_index + 1, positions.size()):
			maximum_distance = maxf(maximum_distance, positions[first_index].distance_to(positions[second_index]))
	return maximum_distance


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	quit(1)
