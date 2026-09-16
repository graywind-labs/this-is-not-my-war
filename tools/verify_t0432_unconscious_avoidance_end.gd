extends SceneTree

const NPC_ID := "cook_01"


func _init() -> void:
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(root.size)

	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("T0432 failed to load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	if combat_system == null or npc_system == null or memory_system == null:
		_fail("T0432 runtime dependencies are unavailable")
		return

	var spawn_result: Dictionary = combat_system.debug_spawn_wave(1, true)
	if not bool(spawn_result.get("ok", false)):
		_fail("T0432 enemy spawn failed: %s" % JSON.stringify(spawn_result))
		return
	var enemy_ids: Array = combat_system.get_active_enemy_ids()
	if enemy_ids.is_empty():
		_fail("T0432 spawned no enemies")
		return
	var enemy_id := str(enemy_ids[0])
	_place_enemy(combat_system, npc_system, enemy_id)
	combat_system.debug_step_enemy_ai(0.0)
	await process_frame

	if _behavior_mode(npc_system) != "avoid_combat":
		_fail("T0432 fixture NPC did not enter avoid_combat")
		return
	var ended_before := _events_of_type(memory_system, "avoidance_ended").size()
	var hp := int(npc_system.get_npc_state(NPC_ID).get("hp", 1))
	var damage_result: Dictionary = npc_system.apply_damage_to_npc(
		NPC_ID,
		hp,
		enemy_id,
		"local_public",
		{"enemy_attack": true, "request_plan_reevaluation": false}
	)
	await process_frame
	if not bool(damage_result.get("unconscious", false)) or _behavior_mode(npc_system) != "unconscious":
		_fail("T0432 NPC did not remain in the authoritative unconscious mode")
		return
	if combat_system.get_active_enemy_count() <= 0:
		_fail("T0432 fixture lost all enemies before the timing assertion")
		return
	if _events_of_type(memory_system, "avoidance_ended").size() != ended_before:
		_fail("T0432 unconscious transition wrote avoidance_ended while enemies remained")
		return
	var deferred: Dictionary = combat_system.debug_get_combat_snapshot().get("deferred_avoidance_endings", {})
	if not deferred.has(NPC_ID):
		_fail("T0432 unconscious avoidance ending was not deferred")
		return

	combat_system.debug_clear_enemies()
	await process_frame
	var ended_after := _events_of_type(memory_system, "avoidance_ended")
	if ended_after.size() != ended_before + 1:
		_fail("T0432 enemy clear did not write exactly one deferred avoidance_ended")
		return
	var event: Dictionary = ended_after[-1]
	var payload: Dictionary = event.get("payload", {})
	if str(event.get("summary", "")) != "布鲁诺不再避战，回到驿站日常安排。":
		_fail("T0432 deferred event summary changed unexpectedly: %s" % str(event.get("summary", "")))
		return
	if int(payload.get("active_enemy_count", -1)) != 0:
		_fail("T0432 deferred event was written before the active enemy count reached zero")
		return
	if _behavior_mode(npc_system) != "unconscious":
		_fail("T0432 enemy clear incorrectly returned the unconscious NPC to work")
		return
	if (combat_system.debug_get_combat_snapshot().get("deferred_avoidance_endings", {}) as Dictionary).has(NPC_ID):
		_fail("T0432 deferred avoidance marker survived enemy clear")
		return

	print("T0432 unconscious avoidance end timing verification passed.")
	quit(0)


func _place_enemy(combat_system: Node, npc_system: Node, enemy_id: String) -> void:
	var position: Vector3 = npc_system.get_npc_world_position(NPC_ID) + Vector3(0.0, 0.0, 2.5)
	var active_enemies: Dictionary = combat_system.get("_active_enemies")
	var enemy: Dictionary = active_enemies.get(enemy_id, {})
	enemy["position"] = position
	active_enemies[enemy_id] = enemy
	combat_system.set("_active_enemies", active_enemies)
	var formal_root := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/FormalEnemies")
	if formal_root == null:
		return
	for child in formal_root.get_children():
		if str(child.get_meta("enemy_id", "")) == enemy_id and child is Node3D:
			(child as Node3D).global_position = position
			if child.has_method("set_motion_paused"):
				child.set_motion_paused(true)
			return


func _behavior_mode(npc_system: Node) -> String:
	return str(npc_system.get_npc_behavior_mode_snapshot(NPC_ID).get("behavior_mode", ""))


func _events_of_type(memory_system: Node, event_type: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_event in memory_system.get_npc_daily_events(NPC_ID):
		var event: Dictionary = raw_event
		if str(event.get("type", "")) == event_type:
			result.append(event)
	return result


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
