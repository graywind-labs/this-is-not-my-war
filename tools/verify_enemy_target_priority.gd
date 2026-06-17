extends SceneTree


func _init() -> void:
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(root.size)

	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		push_error("Failed to load Main.tscn")
		quit(1)
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var gm_panel := root.get_node_or_null("Main/UI/GMPanel")
	var enemy_root := root.get_node_or_null("Main/WorldRoot/Station/Enemies")
	if combat_system == null or building_system == null or npc_system == null or gm_panel == null or enemy_root == null:
		push_error("Enemy target priority verification required nodes not found")
		quit(1)
		return

	var spawn_result: Dictionary = combat_system.debug_spawn_wave(1, true)
	if not bool(spawn_result.get("ok", false)):
		push_error("Failed to spawn first wave: %s" % JSON.stringify(spawn_result))
		quit(1)
		return
	var first_enemy_id := str(combat_system.get_active_enemy_ids()[0])
	var first_enemy_state: Dictionary = combat_system.get_enemy(first_enemy_id)
	var first_preferences: Array = first_enemy_state.get("target_preference", [])
	if first_preferences.has("wall") or first_preferences.has("front_wall"):
		push_error("Enemy target preferences should not include wall targets: %s" % JSON.stringify(first_preferences))
		quit(1)
		return
	combat_system.debug_step_enemy_ai(1.0)
	var first_target: Dictionary = combat_system.debug_get_enemy_target(first_enemy_id)
	if str(first_target.get("type", "")) != "building" or str(first_target.get("id", "")) != "front_gate":
		push_error("Enemy should target front_gate first, got: %s" % JSON.stringify(first_target))
		quit(1)
		return

	var gate_before := int(building_system.get_building("front_gate").get("hp", 0))
	combat_system.debug_step_enemy_ai(720.0)
	combat_system.debug_step_enemy_ai(10.0)
	var gate_after := int(building_system.get_building("front_gate").get("hp", 0))
	if gate_after >= gate_before:
		push_error("Enemy should move to and damage front_gate. before=%d after=%d" % [gate_before, gate_after])
		quit(1)
		return

	combat_system.debug_clear_enemies()
	await process_frame
	await process_frame
	combat_system.debug_spawn_wave(1, true)
	first_enemy_id = str(combat_system.get_active_enemy_ids()[0])
	var first_enemy: Dictionary = combat_system.get_enemy(first_enemy_id)
	var enemy_position: Vector3 = first_enemy.get("position", Vector3.ZERO)
	var npc_id := "stableman_01"
	var npc_node := root.get_node_or_null("Main/WorldRoot/Station/NPCs/%s" % _make_node_name(npc_id)) as Node3D
	if npc_node == null:
		push_error("Cannot find NPC node for nearby unit priority test")
		quit(1)
		return
	npc_node.global_position = enemy_position + Vector3(0.0, 0.0, -1.0)
	var npc_hp_before := int(npc_system.get_npc_state(npc_id).get("hp", 0))
	combat_system.debug_step_enemy_ai(3.0)
	var nearby_target: Dictionary = combat_system.debug_get_enemy_target(first_enemy_id)
	if str(nearby_target.get("type", "")) != "npc" or str(nearby_target.get("id", "")) != npc_id:
		push_error("Nearby actionable NPC should override building target, got: %s" % JSON.stringify(nearby_target))
		quit(1)
		return
	var npc_hp_after := int(npc_system.get_npc_state(npc_id).get("hp", 0))
	if npc_hp_after >= npc_hp_before:
		push_error("Enemy should damage nearby NPC. before=%d after=%d" % [npc_hp_before, npc_hp_after])
		quit(1)
		return

	combat_system.debug_clear_enemies()
	await process_frame
	await process_frame
	for raw_npc_id in npc_system.get_npc_ids():
		var move_node := root.get_node_or_null("Main/WorldRoot/Station/NPCs/%s" % _make_node_name(str(raw_npc_id))) as Node3D
		if move_node != null:
			move_node.global_position = Vector3(-30.0, 0.0, -20.0)
	var wall_hp_before := int(building_system.get_building("wall").get("hp", 0))
	building_system.debug_damage_building("front_gate", 9999)
	combat_system.debug_spawn_wave(1, true)
	first_enemy_id = str(combat_system.get_active_enemy_ids()[0])
	combat_system.debug_step_enemy_ai(1.0)
	var warehouse_target: Dictionary = combat_system.debug_get_enemy_target(first_enemy_id)
	if str(warehouse_target.get("type", "")) != "building" or str(warehouse_target.get("id", "")) != "warehouse":
		push_error("Enemy should skip wall after front_gate is destroyed and target warehouse, got: %s" % JSON.stringify(warehouse_target))
		quit(1)
		return
	var wall_hp_after := int(building_system.get_building("wall").get("hp", 0))
	if wall_hp_after != wall_hp_before:
		push_error("Enemy target priority should not damage wall. before=%d after=%d" % [wall_hp_before, wall_hp_after])
		quit(1)
		return

	building_system.debug_damage_building("warehouse", 9999)
	combat_system.debug_step_enemy_ai(1.0)
	var main_hall_target: Dictionary = combat_system.debug_get_enemy_target(first_enemy_id)
	if str(main_hall_target.get("type", "")) != "building" or str(main_hall_target.get("id", "")) != "main_hall":
		push_error("Enemy should fall through destroyed targets to main_hall, got: %s" % JSON.stringify(main_hall_target))
		quit(1)
		return
	combat_system.debug_step_enemy_ai(1200.0)
	combat_system.debug_step_enemy_ai(1200.0)
	combat_system.debug_step_enemy_ai(1200.0)
	var game_state := root.get_node_or_null("/root/GameState")
	if game_state == null or not bool(game_state.game_over) or str(game_state.failure_reason) != "main_hall_destroyed":
		push_error("Main hall destruction should set failure state")
		quit(1)
		return

	gm_panel._execute_command("step_enemies 1")
	var snapshot: Dictionary = combat_system.debug_get_combat_snapshot()
	if not snapshot.has("enemy_targets") or not snapshot.has("last_ai_step_result"):
		push_error("Combat snapshot should expose enemy target and AI step information")
		quit(1)
		return

	print("Enemy target priority verification passed.")
	quit(0)


func _make_node_name(id_value: String) -> String:
	var parts := id_value.split("_")
	var result := ""
	for part in parts:
		if part.is_empty():
			continue
		result += part.substr(0, 1).to_upper() + part.substr(1).to_lower()
	return "NPC" if result.is_empty() else result
