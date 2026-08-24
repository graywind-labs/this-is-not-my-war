extends SceneTree


const MAIN_PATH := "res://scenes/main/Main.tscn"
const ACTOR_PATH := "Main/WorldRoot/FormalStationLayout/FormalEnemies/FormalActiveEnemyFoot01"
const EXPECTED_STAGES := ["spawn", "reveal", "approach_mid", "contact", "front_gate", "gate_turn", "north_junction", "plaza_junction", "warehouse", "main_hall"]

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
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var game_state := root.get_node_or_null("GameState")
	if combat_system == null or building_system == null or memory_system == null or game_state == null:
		_fail("A4-P4 runtime dependencies unavailable")
		return

	var start: Dictionary = combat_system.debug_run_formal_active_enemy_main_hall_slice()
	await physics_frame
	var actor := root.get_node_or_null(ACTOR_PATH) as ActorMotionBody
	if not bool(start.get("ok", false)) or actor == null:
		_fail("Formal main-hall slice did not start: %s" % start)
		return
	actor.configure_profile("enemy_foot", {
		"profile": {"base_speed": 20.0, "acceleration": 50.0},
		"navigation_agent": {"target_desired_distance": 1.0, "path_desired_distance": 0.8}
	})
	actor.navigation_agent.max_speed = 25.0

	if not await _wait_for_phase(combat_system, "front_gate_reached", 1200):
		_fail("Enemy did not reach front gate: %s" % combat_system.debug_get_formal_active_enemy_main_hall_slice_snapshot())
		return
	_destroy_building_with_enemy(combat_system, building_system, "front_gate")
	combat_system.debug_step_enemy_ai(60.0)
	if not await _wait_for_phase(combat_system, "warehouse_reached", 480):
		_fail("Enemy did not reach warehouse: %s" % combat_system.debug_get_formal_active_enemy_main_hall_slice_snapshot())
		return

	var main_hall_hp_before := int(building_system.get_building("main_hall").get("hp", -1))
	_destroy_building_with_enemy(combat_system, building_system, "warehouse")
	var route_start: Dictionary = combat_system.debug_step_enemy_ai(60.0)
	var marching: Dictionary = combat_system.debug_get_formal_active_enemy_main_hall_slice_snapshot()
	if (
		int(building_system.get_building("warehouse").get("hp", -1)) != 0
		or int(building_system.get_building("main_hall").get("hp", -2)) != main_hall_hp_before
		or str(marching.get("phase", "")) != "marching_to_main_hall"
		or str(marching.get("target_stage_id", "")) != "main_hall"
		or not (route_start.get("attacks", []) as Array).is_empty()
	):
		_fail("Warehouse destruction did not start a damage-free physical main-hall route: %s / %s" % [route_start, marching])
		return

	if not await _wait_for_phase(combat_system, "main_hall_reached", 300):
		_fail("Enemy did not physically reach main hall: %s" % combat_system.debug_get_formal_active_enemy_main_hall_slice_snapshot())
		return
	var arrival: Dictionary = combat_system.debug_get_formal_active_enemy_main_hall_slice_snapshot()
	if (
		arrival.get("completed_stage_ids", []) != EXPECTED_STAGES
		or not bool(arrival.get("attack_unlocked", false))
		or str(arrival.get("attack_target_building_id", "")) != "main_hall"
		or bool(arrival.get("main_hall_combat_authority_committed", true))
		or bool(game_state.get("game_over"))
	):
		_fail("Main-hall authority unlocked before/without exact physical arrival: %s" % arrival)
		return

	var attack_step: Dictionary = combat_system.debug_step_enemy_ai(60.0)
	var main_hall_hp_after := int(building_system.get_building("main_hall").get("hp", -1))
	var attacked: Dictionary = combat_system.debug_get_formal_active_enemy_main_hall_slice_snapshot()
	if (
		main_hall_hp_after >= main_hall_hp_before
		or (attack_step.get("attacks", []) as Array).is_empty()
		or not bool(attacked.get("main_hall_combat_authority_committed", false))
		or str(attacked.get("phase", "")) != "attacking_main_hall"
		or bool(game_state.get("game_over"))
	):
		_fail("Physical main-hall arrival did not commit the first non-terminal damage: %s / %s" % [attack_step, attacked])
		return
	if not _has_building_event(memory_system.get_plaza_events(), "main_hall"):
		_fail("Main-hall attack did not emit building_damaged")
		return

	_destroy_building_with_enemy(combat_system, building_system, "main_hall")
	var failure: Dictionary = combat_system.debug_get_formal_active_enemy_main_hall_slice_snapshot()
	if (
		int(building_system.get_building("main_hall").get("hp", -1)) != 0
		or not bool(game_state.get("game_over"))
		or str(game_state.get("game_result")) != "failure"
		or str(game_state.get("game_over_reason")) != "main_hall_destroyed"
		or str(failure.get("phase", "")) != "main_hall_destroyed_failure"
	):
		_fail("Main-hall destruction did not preserve the existing failure authority: %s" % failure)
		return

	var stop: Dictionary = combat_system.debug_stop_formal_active_enemy_main_hall_slice("verification_complete")
	await process_frame
	await process_frame
	if not bool(stop.get("ok", false)) or combat_system.get_active_enemy_count() != 0 or root.get_node_or_null(ACTOR_PATH) != null:
		_fail("Formal main-hall slice cleanup failed: %s" % stop)
		return

	print("T0129C A4-P4 formal active enemy main-hall verification passed: %s" % JSON.stringify({
		"route": EXPECTED_STAGES,
		"main_hall_hp_before": main_hall_hp_before,
		"main_hall_hp_after_first_hit": main_hall_hp_after,
		"failure_reason": game_state.get("game_over_reason"),
		"active_enemy_count_after": combat_system.get_active_enemy_count()
	}))
	quit(0)


func _destroy_building_with_enemy(combat_system: Node, building_system: Node, building_id: String) -> void:
	for _attack_round in range(12):
		combat_system.debug_step_enemy_ai(3600.0)
		if int(building_system.get_building(building_id).get("hp", -1)) == 0:
			return


func _wait_for_phase(combat_system: Node, expected_phase: String, frame_limit: int) -> bool:
	for _frame in range(frame_limit):
		await physics_frame
		var snapshot: Dictionary = combat_system.debug_get_formal_active_enemy_main_hall_slice_snapshot()
		if str(snapshot.get("phase", "")) == expected_phase:
			return true
		if str(snapshot.get("phase", "")) == "navigation_failed":
			return false
	return false


func _has_building_event(events: Array, building_id: String) -> bool:
	for raw_event in events:
		if not raw_event is Dictionary:
			continue
		var event := raw_event as Dictionary
		if str(event.get("type", "")) != "building_damaged":
			continue
		var payload := event.get("payload", {}) as Dictionary
		if str(payload.get("building_id", "")) == building_id:
			return true
	return false


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	quit(1)
