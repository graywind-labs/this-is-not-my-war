extends SceneTree


const MAIN_PATH := "res://scenes/main/Main.tscn"
const ENEMY_ID := "wave_01_formal_enemy_001"
const ACTOR_PATH := "Main/WorldRoot/FormalStationLayout/FormalEnemies/FormalActiveEnemyFoot01"
const EXPECTED_STAGES := ["spawn", "reveal", "approach_mid", "contact", "front_gate"]

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
	var legacy_enemy_root := root.get_node_or_null("Main/WorldRoot/Station/Enemies")
	if combat_system == null or building_system == null or memory_system == null or legacy_enemy_root == null:
		_fail("A4-P2 runtime dependencies unavailable")
		return

	var gate_hp_before := int(building_system.get_building("front_gate").get("hp", -1))
	var start: Dictionary = combat_system.debug_run_formal_active_enemy_front_gate_slice()
	if (
		not bool(start.get("ok", false))
		or int(start.get("spawned_count", 0)) != 1
		or int(start.get("active_enemy_count", 0)) != 1
		or start.get("spawned_enemy_ids", []) != [ENEMY_ID]
	):
		_fail("Formal active enemy slice did not start as one real wave enemy: %s" % start)
		return
	await physics_frame
	var actor := root.get_node_or_null(ACTOR_PATH) as ActorMotionBody
	if actor == null or legacy_enemy_root.get_child_count() != 0:
		_fail("Formal active enemy must exist only under the formal root")
		return
	var enemy_before: Dictionary = combat_system.get_enemy(ENEMY_ID)
	if not bool(enemy_before.get("formal_navigation_authority", false)):
		_fail("Active enemy state did not declare formal navigation authority")
		return

	var early_step: Dictionary = combat_system.debug_step_enemy_ai(600.0)
	if (
		int(building_system.get_building("front_gate").get("hp", -2)) != gate_hp_before
		or not (early_step.get("attacks", []) as Array).is_empty()
	):
		_fail("Enemy attacked before physical front-gate arrival: %s" % early_step)
		return

	actor.configure_profile("enemy_foot", {
		"profile": {"base_speed": 20.0, "acceleration": 50.0},
		"navigation_agent": {"target_desired_distance": 1.0, "path_desired_distance": 0.8}
	})
	actor.navigation_agent.max_speed = 25.0
	var reached := false
	for _frame in range(1200):
		await physics_frame
		var snapshot: Dictionary = combat_system.debug_get_formal_active_enemy_front_gate_slice_snapshot()
		if str(snapshot.get("phase", "")) == "front_gate_reached":
			reached = true
			break
		if str(snapshot.get("phase", "")) == "navigation_failed":
			break
	if not reached:
		_fail("Active enemy did not physically reach the formal front gate: %s" % combat_system.debug_get_formal_active_enemy_front_gate_slice_snapshot())
		return

	var arrival: Dictionary = combat_system.debug_get_formal_active_enemy_front_gate_slice_snapshot()
	if (
		arrival.get("completed_stage_ids", []) != EXPECTED_STAGES
		or not bool(arrival.get("attack_unlocked", false))
		or bool(arrival.get("combat_authority_committed", true))
		or int(arrival.get("active_enemy_count", 0)) != 1
	):
		_fail("Physical arrival did not unlock exactly the front-gate authority boundary: %s" % arrival)
		return

	var attack_step: Dictionary = combat_system.debug_step_enemy_ai(60.0)
	var gate_hp_after := int(building_system.get_building("front_gate").get("hp", -1))
	var attacked: Dictionary = combat_system.debug_get_formal_active_enemy_front_gate_slice_snapshot()
	if (
		gate_hp_after >= gate_hp_before
		or (attack_step.get("attacks", []) as Array).is_empty()
		or not bool(attacked.get("combat_authority_committed", false))
		or str((attacked.get("enemy", {}) as Dictionary).get("target", {}).get("id", "")) != "front_gate"
	):
		_fail("Physical arrival did not enter the existing front-gate attack authority: %s / %s" % [attack_step, attacked])
		return
	if not _has_event(memory_system.get_plaza_events(), "combat_started"):
		_fail("Real active enemy slice did not preserve combat_started")
		return
	if not _has_event(memory_system.get_plaza_events(), "building_damaged"):
		_fail("Front-gate attack did not preserve building_damaged")
		return
	var stop: Dictionary = combat_system.debug_stop_formal_active_enemy_front_gate_slice("verification_complete")
	await process_frame
	await process_frame
	if (
		not bool(stop.get("ok", false))
		or combat_system.get_active_enemy_count() != 0
		or root.get_node_or_null(ACTOR_PATH) != null
		or not _has_event(memory_system.get_plaza_events(), "combat_ended")
	):
		_fail("Formal active enemy cleanup / battle end compatibility failed: %s" % stop)
		return
	var death_start: Dictionary = combat_system.debug_run_formal_active_enemy_front_gate_slice()
	await physics_frame
	var death_actor := root.get_node_or_null(ACTOR_PATH) as ActorMotionBody
	if not bool(death_start.get("ok", false)) or death_actor == null:
		_fail("Death cleanup slice could not start")
		return
	var defeat: Dictionary = combat_system.apply_enemy_area_damage(
		death_actor.global_position,
		2.0,
		1000.0,
		{"source_type": "verification", "source_id": "a4_p2", "source_name": "A4-P2 验证"}
	)
	await process_frame
	await process_frame
	if (
		int(defeat.get("defeated_count", 0)) != 1
		or combat_system.get_active_enemy_count() != 0
		or root.get_node_or_null(ACTOR_PATH) != null
		or bool(combat_system.debug_get_formal_active_enemy_front_gate_slice_snapshot().get("active", true))
	):
		_fail("Formal active enemy defeat did not clean runtime authority: %s" % defeat)
		return

	print("T0129C A4-P2 formal active enemy front-gate verification passed: %s" % JSON.stringify({
		"route": EXPECTED_STAGES,
		"gate_hp_before": gate_hp_before,
		"gate_hp_after": gate_hp_after,
		"damage": gate_hp_before - gate_hp_after,
		"active_enemy_count_after": combat_system.get_active_enemy_count(),
		"defeat_cleanup": true,
		"combat_events_preserved": true
	}))
	quit(0)


func _has_event(events: Array, event_type: String) -> bool:
	for raw_event in events:
		if raw_event is Dictionary and str((raw_event as Dictionary).get("type", "")) == event_type:
			return true
	return false


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	quit(1)
