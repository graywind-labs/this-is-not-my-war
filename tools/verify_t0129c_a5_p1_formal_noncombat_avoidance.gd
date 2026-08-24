extends SceneTree


const EXPECTED_NPC_COUNT := 8
const MIN_AVOIDANCE_TRAVEL := 0.45
const MAX_FRAME_DISPLACEMENT := 0.14


func _init() -> void:
	root.size = Vector2i(1280, 720)
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn could not be loaded")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	if combat_system == null or npc_system == null or time_system == null:
		_fail("A5-P1 required systems are missing")
		return

	var original_positions: Dictionary = {}
	for npc_id in npc_system.get_npc_ids():
		original_positions[npc_id] = npc_system.get_npc_world_position(npc_id)
	var spawn_result: Dictionary = combat_system.spawn_wave(1, true, "a5_p1_verification")
	if not bool(spawn_result.get("ok", false)):
		_fail("Default wave spawn failed: %s" % JSON.stringify(spawn_result))
		return
	var migration: Dictionary = spawn_result.get("formal_combat_world_result", {})
	var migrated_ids := migration.get("migrated_npc_ids", []) as Array
	var noncombatant_ids := migration.get("noncombatant_npc_ids", []) as Array
	if migrated_ids.size() != EXPECTED_NPC_COUNT or noncombatant_ids.is_empty():
		_fail("Default battle did not migrate all eight NPCs and expose civilians: %s" % JSON.stringify(migration))
		return

	var world_snapshot: Dictionary = combat_system.debug_get_default_formal_combat_world_snapshot()
	var npc_world := world_snapshot.get("npc_world", {}) as Dictionary
	if int(npc_world.get("actor_count", 0)) != EXPECTED_NPC_COUNT:
		_fail("Formal NPC population is incomplete: %s" % JSON.stringify(npc_world))
		return
	for raw_actor in npc_world.get("actors", []):
		var actor := raw_actor as Dictionary
		if (
			not bool(actor.get("navigation_motion_enabled", false))
			or not bool(actor.get("navigation_map_matches", false))
			or int(actor.get("body_collision_layer", 0)) == 0
			or int(actor.get("body_collision_mask", 0)) == 0
			or (actor.get("world_position", Vector3.ZERO) as Vector3).x < 900.0
		):
			_fail("A migrated NPC lacks formal navigation or solid collision: %s" % JSON.stringify(actor))
			return

	var npc_id := str(noncombatant_ids[0])
	var npc_start: Vector3 = npc_system.get_npc_world_position(npc_id)
	# Keep the focused movement slice deterministic: logical combat contact is
	# already exercised by combat regressions, while physics keeps running here.
	time_system.set_process(false)
	var enemy_id := str(combat_system.get_active_enemy_ids()[0])
	var enemy_node := _find_enemy_node(enemy_id) as CharacterBody3D
	if enemy_node == null:
		_fail("Formal enemy body was not found")
		return
	var enemy_position := npc_start + Vector3(-3.0, 0.0, 0.0)
	_set_enemy_position(combat_system, enemy_id, enemy_node, enemy_position)
	enemy_node.set_motion_paused(true)
	var forced: Dictionary = combat_system.debug_trigger_npc_avoidance(npc_id)
	if not bool(forced.get("ok", false)):
		_fail("Noncombatant did not enter avoidance against a nearby enemy: %s" % JSON.stringify(forced))
		return
	var avoidance: Dictionary = _find_avoidance(combat_system, npc_id)
	var target_position := _as_vector3(avoidance.get("target_position", {}))
	if target_position.x < 900.0:
		_fail("Avoidance target remained in the legacy coordinate world: %s" % JSON.stringify(avoidance))
		return
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	if str(state.get("behavior_mode", "")) != "avoid_combat":
		_fail("Noncombatant authority mode is not avoid_combat: %s" % JSON.stringify(state))
		return

	var moved_actor := _find_npc_actor(
		(combat_system.debug_get_default_formal_combat_world_snapshot().get("npc_world", {}) as Dictionary),
		npc_id
	)
	var motion := moved_actor.get("motion", {}) as Dictionary
	if (
		not bool(motion.get("active", false))
		or str(motion.get("state", "")) not in ["moving", "waiting_for_path"]
		or _horizontal_distance((motion.get("target_position", Vector3.ZERO) as Vector3), target_position) > 0.05
	):
		_fail("Avoidance did not become a real ActorMotionBody request: %s" % JSON.stringify(motion))
		return
	for _frame in range(45):
		await physics_frame
	var npc_end: Vector3 = npc_system.get_npc_world_position(npc_id)
	var moved_snapshot: Dictionary = combat_system.debug_get_default_formal_combat_world_snapshot()
	var moved_world := moved_snapshot.get("npc_world", {}) as Dictionary
	var completed_actor := _find_npc_actor(moved_world, npc_id)
	var completed_motion := completed_actor.get("motion", {}) as Dictionary
	var maximum_frame_displacement := float(completed_motion.get("maximum_frame_displacement", INF))
	if npc_end.distance_to(npc_start) < MIN_AVOIDANCE_TRAVEL:
		_fail("Noncombatant avoidance did not produce physical CharacterBody movement")
		return
	if npc_end.distance_to(enemy_position) <= npc_start.distance_to(enemy_position):
		_fail("Noncombatant did not physically increase distance from the enemy")
		return
	if maximum_frame_displacement > MAX_FRAME_DISPLACEMENT:
		_fail("Avoidance exceeded bounded per-frame motion: %.3f" % maximum_frame_displacement)
		return
	var clear_result: Dictionary = combat_system.clear_spawned_enemies()
	await process_frame
	await process_frame
	if not bool(clear_result.get("ok", false)):
		_fail("Clearing formal battle failed: %s" % JSON.stringify(clear_result))
		return
	for raw_npc_id in migrated_ids:
		var restored_npc_id := str(raw_npc_id)
		var restored: Vector3 = npc_system.get_npc_world_position(restored_npc_id)
		var original: Vector3 = original_positions.get(restored_npc_id, Vector3.INF)
		if restored.distance_to(original) > 0.01:
			_fail("NPC was not restored after formal avoidance: %s" % restored_npc_id)
			return
	if str(npc_system.get_npc_state(npc_id).get("behavior_mode", "")) != "work":
		_fail("Avoiding NPC did not return to work mode after battle cleanup")
		return

	print(
		"A5-P1 formal noncombat avoidance verification passed: npc=%s actors=%d moved=%.3f max_frame=%.3f"
		% [npc_id, migrated_ids.size(), npc_start.distance_to(npc_end), maximum_frame_displacement]
	)
	quit(0)


func _find_enemy_node(enemy_id: String) -> Node:
	var formal_root := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/FormalEnemies")
	if formal_root == null:
		return null
	for child in formal_root.get_children():
		if str(child.get_meta("enemy_id", "")) == enemy_id:
			return child
	return null


func _find_avoidance(combat_system: Node, npc_id: String) -> Dictionary:
	for raw_avoidance in combat_system.get_active_avoidances():
		var avoidance := raw_avoidance as Dictionary
		if str(avoidance.get("npc_id", "")) == npc_id:
			return avoidance
	return {}


func _find_npc_actor(npc_world: Dictionary, npc_id: String) -> Dictionary:
	for raw_actor in npc_world.get("actors", []):
		var actor := raw_actor as Dictionary
		if str(actor.get("npc_id", "")) == npc_id:
			return actor
	return {}


func _as_vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Dictionary:
		var data := value as Dictionary
		return Vector3(float(data.get("x", 0.0)), float(data.get("y", 0.0)), float(data.get("z", 0.0)))
	return Vector3.ZERO


func _horizontal_distance(first: Vector3, second: Vector3) -> float:
	return Vector2(first.x, first.z).distance_to(Vector2(second.x, second.z))


func _set_enemy_position(combat_system: Node, enemy_id: String, enemy_node: CharacterBody3D, position: Vector3) -> void:
	enemy_node.global_position = position
	var enemy: Dictionary = combat_system._active_enemies.get(enemy_id, {})
	enemy["position"] = position
	combat_system._active_enemies[enemy_id] = enemy


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
