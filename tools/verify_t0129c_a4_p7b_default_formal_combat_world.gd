extends SceneTree


func _init() -> void:
	root.size = Vector2i(1280, 720)
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Main.tscn could not be loaded")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var legacy_enemy_root := root.get_node_or_null("Main/WorldRoot/Station/Enemies")
	if combat_system == null or npc_system == null or legacy_enemy_root == null:
		_fail("P7b required systems are missing")
		return

	var spawn_result: Dictionary = combat_system.spawn_wave(1, true, "p7b_verification")
	if not bool(spawn_result.get("ok", false)) or str(spawn_result.get("world_mode", "")) != "formal_runtime":
		_fail("Default spawn_wave did not enter formal runtime: %s" % JSON.stringify(spawn_result))
		return
	if legacy_enemy_root.get_child_count() != 0 or int(spawn_result.get("legacy_area3d_spawned_count", -1)) != 0:
		_fail("Default spawn_wave still created legacy Area3D enemies")
		return

	var world_snapshot: Dictionary = combat_system.debug_get_default_formal_combat_world_snapshot()
	var npc_world: Dictionary = world_snapshot.get("npc_world", {})
	var combat_actors := npc_world.get("actors", []) as Array
	if not bool(world_snapshot.get("active", false)) or combat_actors.is_empty():
		_fail("No eligible NPC was migrated into the formal combat world")
		return
	for raw_actor in combat_actors:
		var actor := raw_actor as Dictionary
		if (
			not bool(actor.get("navigation_motion_enabled", false))
			or not bool(actor.get("navigation_map_matches", false))
			or int(actor.get("body_collision_layer", 0)) == 0
			or int(actor.get("body_collision_mask", 0)) == 0
		):
			_fail("Migrated combat NPC lacks shared navigation or solid collision: %s" % JSON.stringify(actor))
			return
		if (actor.get("world_position", Vector3.ZERO) as Vector3).x < 900.0:
			_fail("Migrated combat NPC is not in the formal world")
			return

	var probe_actor := combat_actors[0] as Dictionary
	var probe_npc_id := str(probe_actor.get("npc_id", ""))
	var probe_position: Vector3 = npc_system.get_npc_world_position(probe_npc_id)
	var enemy_id := str(combat_system.get_active_enemy_ids()[0])
	var enemy_node := _find_enemy_node(enemy_id) as CharacterBody3D
	if enemy_node == null:
		_fail("Formal enemy CharacterBody3D was not found")
		return
	var enemy_position := probe_position + Vector3(0.0, 0.0, 5.0)
	_set_enemy_position(combat_system, enemy_id, enemy_node, enemy_position)
	combat_system._advance_combat_ai(0.1)
	var first_slice := _find_slice(combat_system.debug_get_formal_first_wave_slice_snapshot(), enemy_id)
	var npc_id := str(first_slice.get("combat_target_id", ""))
	if (
		str(first_slice.get("combat_target_type", "")) != "npc"
		or npc_id.is_empty()
		or not (npc_world.get("npc_ids", []) as Array).has(npc_id)
	):
		_fail("Enemy did not acquire the NPC's real Body position: %s" % JSON.stringify(first_slice))
		return
	var npc_position: Vector3 = npc_system.get_npc_world_position(npc_id)
	var first_target: Vector3 = first_slice.get("motion_target_position", Vector3.ZERO)
	var first_repath_count := int(first_slice.get("pressure_repath_count", 0))

	var npc_move_target := npc_position + Vector3(1.5, 0.0, 0.0)
	if not npc_system.move_npc_to_world_position(npc_id, "plaza", "广场", npc_move_target, {
		"current_action": "idle",
		"current_location": "plaza",
		"current_location_name": "广场",
		"last_action_result": "p7b_moving_target_arrived"
	}):
		_fail("Formal combat NPC could not start ActorMotionBody movement")
		return
	for _frame in range(45):
		await physics_frame
	var moved_npc_position: Vector3 = npc_system.get_npc_world_position(npc_id)
	if moved_npc_position.distance_to(npc_position) < 0.4:
		_fail("Formal combat NPC did not physically move")
		return
	_set_enemy_position(combat_system, enemy_id, enemy_node, moved_npc_position + Vector3(0.0, 0.0, 5.0))
	combat_system._advance_combat_ai(0.1)
	var second_slice := _find_slice(combat_system.debug_get_formal_first_wave_slice_snapshot(), enemy_id)
	var second_target: Vector3 = second_slice.get("motion_target_position", Vector3.ZERO)
	if (
		str(second_slice.get("combat_target_id", "")) != npc_id
		or int(second_slice.get("pressure_repath_count", 0)) <= first_repath_count
		or second_target.distance_to(first_target) < 0.35
	):
		_fail("Enemy did not replan after its NPC target moved: %s" % JSON.stringify(second_slice))
		return

	var positions_before_clear: Dictionary = {}
	for raw_actor in combat_actors:
		var active_npc_id := str((raw_actor as Dictionary).get("npc_id", ""))
		positions_before_clear[active_npc_id] = npc_system.get_npc_world_position(active_npc_id)
	var clear_result: Dictionary = combat_system.clear_spawned_enemies()
	await process_frame
	await process_frame
	if not bool(clear_result.get("ok", false)) or bool(combat_system.debug_get_default_formal_combat_world_snapshot().get("active", true)):
		_fail("Clearing the wave did not exit the formal combat world")
		return
	for raw_actor in combat_actors:
		var restored_npc_id := str((raw_actor as Dictionary).get("npc_id", ""))
		var restored_position: Vector3 = npc_system.get_npc_world_position(restored_npc_id)
		var retained_position: Vector3 = positions_before_clear.get(restored_npc_id, Vector3.INF)
		if restored_position.distance_to(retained_position) > 0.01:
			_fail("NPC position changed while leaving formal combat: %s" % restored_npc_id)
			return
		var migration_snapshot: Dictionary = npc_system.debug_get_spatial_migration_snapshot(restored_npc_id)
		if bool((migration_snapshot.get("motion", {}) as Dictionary).get("active", false)):
			_fail("NPC retained a formal motion request after cleanup: %s" % restored_npc_id)
			return

	print("A4-P7b default formal combat world verification passed.")
	quit(0)


func _set_enemy_position(combat_system: Node, enemy_id: String, enemy_node: CharacterBody3D, position: Vector3) -> void:
	enemy_node.global_position = position
	var enemy: Dictionary = combat_system._active_enemies.get(enemy_id, {})
	enemy["position"] = position
	combat_system._active_enemies[enemy_id] = enemy


func _find_enemy_node(enemy_id: String) -> Node:
	var formal_root := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/FormalEnemies")
	if formal_root == null:
		return null
	for child in formal_root.get_children():
		if str(child.get_meta("enemy_id", "")) == enemy_id:
			return child
	return null


func _find_slice(snapshot: Dictionary, enemy_id: String) -> Dictionary:
	for raw_slice in snapshot.get("slices", []):
		var slice := raw_slice as Dictionary
		if str(slice.get("enemy_id", "")) == enemy_id:
			return slice
	return {}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
