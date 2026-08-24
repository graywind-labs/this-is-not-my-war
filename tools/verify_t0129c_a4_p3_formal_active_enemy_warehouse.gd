extends SceneTree


const MAIN_PATH := "res://scenes/main/Main.tscn"
const ACTOR_PATH := "Main/WorldRoot/FormalStationLayout/FormalEnemies/FormalActiveEnemyFoot01"
const EXPECTED_STAGES := ["spawn", "reveal", "approach_mid", "contact", "front_gate", "gate_turn", "north_junction", "plaza_junction", "warehouse"]

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
	if combat_system == null or building_system == null or memory_system == null:
		_fail("A4-P3 runtime dependencies unavailable")
		return

	var start: Dictionary = combat_system.debug_run_formal_active_enemy_warehouse_slice()
	await physics_frame
	var actor := root.get_node_or_null(ACTOR_PATH) as ActorMotionBody
	if not bool(start.get("ok", false)) or actor == null:
		_fail("Formal warehouse slice did not start: %s" % start)
		return
	actor.configure_profile("enemy_foot", {
		"profile": {"base_speed": 20.0, "acceleration": 50.0},
		"navigation_agent": {"target_desired_distance": 1.0, "path_desired_distance": 0.8}
	})
	actor.navigation_agent.max_speed = 25.0
	if not await _wait_for_phase(combat_system, "front_gate_reached", 1200):
		_fail("Enemy did not reach front gate before warehouse route: %s" % combat_system.debug_get_formal_active_enemy_warehouse_slice_snapshot())
		return

	var warehouse_hp_before := int(building_system.get_building("warehouse").get("hp", -1))
	for _attack_round in range(12):
		combat_system.debug_step_enemy_ai(3600.0)
		if int(building_system.get_building("front_gate").get("hp", -1)) == 0:
			break
	if int(building_system.get_building("front_gate").get("hp", -1)) != 0:
		_fail("Enemy did not destroy front gate")
		return
	var route_start: Dictionary = combat_system.debug_step_enemy_ai(60.0)
	var marching: Dictionary = combat_system.debug_get_formal_active_enemy_warehouse_slice_snapshot()
	if (
		int(building_system.get_building("warehouse").get("hp", -2)) != warehouse_hp_before
		or str(marching.get("phase", "")) != "marching_to_warehouse"
		or str(marching.get("target_stage_id", "")) != "gate_turn"
		or not (route_start.get("attacks", []) as Array).is_empty()
	):
		_fail("Gate destruction did not start a damage-free physical warehouse route: %s / %s" % [route_start, marching])
		return

	if not await _wait_for_phase(combat_system, "warehouse_reached", 480):
		_fail("Enemy did not physically reach warehouse: %s" % combat_system.debug_get_formal_active_enemy_warehouse_slice_snapshot())
		return
	var arrival: Dictionary = combat_system.debug_get_formal_active_enemy_warehouse_slice_snapshot()
	if (
		arrival.get("completed_stage_ids", []) != EXPECTED_STAGES
		or not bool(arrival.get("attack_unlocked", false))
		or str(arrival.get("attack_target_building_id", "")) != "warehouse"
		or bool(arrival.get("warehouse_combat_authority_committed", true))
	):
		_fail("Warehouse authority unlocked before/without the exact physical route: %s" % arrival)
		return

	var attack_step: Dictionary = combat_system.debug_step_enemy_ai(60.0)
	var warehouse_hp_after := int(building_system.get_building("warehouse").get("hp", -1))
	var attacked: Dictionary = combat_system.debug_get_formal_active_enemy_warehouse_slice_snapshot()
	if (
		warehouse_hp_after >= warehouse_hp_before
		or (attack_step.get("attacks", []) as Array).is_empty()
		or not bool(attacked.get("warehouse_combat_authority_committed", false))
		or str(attacked.get("phase", "")) != "attacking_warehouse"
		or str((attacked.get("enemy", {}) as Dictionary).get("target", {}).get("id", "")) != "warehouse"
	):
		_fail("Physical warehouse arrival did not commit warehouse damage: %s / %s" % [attack_step, attacked])
		return
	if not _has_building_event(memory_system.get_plaza_events(), "warehouse"):
		_fail("Warehouse attack did not emit a warehouse building_damaged event")
		return

	var stop: Dictionary = combat_system.debug_stop_formal_active_enemy_warehouse_slice("verification_complete")
	await process_frame
	await process_frame
	if not bool(stop.get("ok", false)) or combat_system.get_active_enemy_count() != 0 or root.get_node_or_null(ACTOR_PATH) != null:
		_fail("Formal warehouse slice cleanup failed: %s" % stop)
		return

	print("T0129C A4-P3 formal active enemy warehouse verification passed: %s" % JSON.stringify({
		"route": EXPECTED_STAGES,
		"warehouse_hp_before": warehouse_hp_before,
		"warehouse_hp_after_first_hit": warehouse_hp_after,
		"active_enemy_count_after": combat_system.get_active_enemy_count()
	}))
	quit(0)


func _wait_for_phase(combat_system: Node, expected_phase: String, frame_limit: int) -> bool:
	for _frame in range(frame_limit):
		await physics_frame
		var snapshot: Dictionary = combat_system.debug_get_formal_active_enemy_warehouse_slice_snapshot()
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
		if str(payload.get("building_id", payload.get("target_id", ""))) == building_id:
			return true
	return false


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	quit(1)
