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
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	if (
		combat_system == null
		or npc_system == null
		or resource_system == null
		or equipment_system == null
		or memory_system == null
	):
		push_error("Combat flow verification required nodes not found")
		quit(1)
		return

	if memory_system.has_method("clear_event_log"):
		memory_system.clear_event_log()

	_place_all_npcs_far(npc_system)
	_set_npc_position(npc_system, "stableman_01", Vector3(1.0, 0.0, 0.0))
	_set_npc_position(npc_system, "cook_01", Vector3(0.35, 0.0, 0.0))

	npc_system.set_npc_recruited("stableman_01", true)
	resource_system.add_resource("item_sword_shield", 1)
	var weapon_result: Dictionary = equipment_system.equip_npc_main_weapon("stableman_01", "sword_shield", "private")
	if not bool(weapon_result.get("ok", false)):
		push_error("Failed to equip stableman for combat flow verification: %s" % JSON.stringify(weapon_result))
		quit(1)
		return

	var spawn_result: Dictionary = combat_system.debug_spawn_wave(1, true)
	if not bool(spawn_result.get("ok", false)):
		push_error("Enemy spawn failed: %s" % JSON.stringify(spawn_result))
		quit(1)
		return

	var start_event := _last_event(memory_system.get_plaza_events(), "combat_started")
	if start_event.is_empty():
		push_error("Wave spawn should write a plaza combat_started event")
		quit(1)
		return
	var start_payload: Dictionary = start_event.get("payload", {})
	if int(start_payload.get("enemy_count", 0)) <= 0:
		push_error("combat_started should include enemy_count")
		quit(1)
		return
	if (start_payload.get("friendly_roster", []) as Array).is_empty():
		push_error("combat_started should list recruited armed friendly combatants")
		quit(1)
		return
	if not str(start_event.get("summary", "")).contains("敌军来袭"):
		push_error("combat_started summary should announce enemy arrival")
		quit(1)
		return

	var enemy_ids: Array[String] = combat_system.get_active_enemy_ids()
	if enemy_ids.is_empty():
		push_error("Expected active enemies after spawn")
		quit(1)
		return
	var formal_combatant_position: Vector3 = npc_system.get_npc_world_position("stableman_01")
	_place_enemies_for_flow_test(combat_system, enemy_ids, formal_combatant_position, false)

	combat_system.debug_step_enemy_ai(60.0)
	if _mode(npc_system, "stableman_01") != "combat":
		push_error("Recruited armed NPC should enter combat on enemy contact")
		quit(1)
		return
	_place_enemies_for_flow_test(combat_system, enemy_ids, formal_combatant_position, true)
	npc_system.update_npc_state("stableman_01", {"combat_attack_cooldown": 0.0})
	var kill_result: Dictionary = combat_system.debug_step_enemy_ai(600.0)
	await process_frame

	if combat_system.get_active_enemy_count() != 0:
		push_error("All weakened enemies should be defeated. result=%s" % JSON.stringify(kill_result))
		quit(1)
		return
	if _mode(npc_system, "stableman_01") != "work":
		push_error("Combat NPC should return to work after enemies are defeated")
		quit(1)
		return
	var end_event := _last_event(memory_system.get_plaza_events(), "combat_ended")
	if end_event.is_empty():
		push_error("All enemies defeated should write a plaza combat_ended event")
		quit(1)
		return
	var end_payload: Dictionary = end_event.get("payload", {})
	if (end_payload.get("injured_npcs", []) as Array).is_empty():
		push_error("combat_ended should include NPCs injured during the battle")
		quit(1)
		return
	if (end_payload.get("defeated_by_npc", []) as Array).is_empty():
		push_error("combat_ended should include enemy defeats by NPC")
		quit(1)
		return
	if not str(end_event.get("summary", "")).contains("战斗结束"):
		push_error("combat_ended summary should mention battle end")
		quit(1)
		return

	var stableman_reevaluation: Dictionary = npc_system.get_plan_reevaluation_request("stableman_01")
	if str(stableman_reevaluation.get("npc_id", "")) != "stableman_01":
		push_error("Combat NPC should request plan reevaluation after battle")
		quit(1)
		return

	print("Combat flow verification passed.")
	quit(0)


func _place_all_npcs_far(npc_system: Node) -> void:
	var index := 0
	for raw_npc_id in npc_system.get_npc_ids():
		_set_npc_position(npc_system, str(raw_npc_id), Vector3(9.0 + float(index), 0.0, -12.0))
		index += 1


func _set_npc_position(npc_system: Node, npc_id: String, position: Vector3) -> void:
	var npc_nodes: Dictionary = npc_system.get("_npc_nodes")
	var node_path := NodePath(str(npc_nodes.get(npc_id, "")))
	var npc_node := root.get_node_or_null(node_path) as Node3D
	if npc_node != null:
		npc_node.global_position = position


func _place_enemies_for_flow_test(combat_system: Node, enemy_ids: Array[String], center: Vector3, weaken: bool) -> void:
	var active_enemies: Dictionary = combat_system.get("_active_enemies")
	for index in range(enemy_ids.size()):
		var enemy_id := str(enemy_ids[index])
		var enemy: Dictionary = active_enemies.get(enemy_id, {})
		if enemy.is_empty():
			continue
		enemy["position"] = center + Vector3(0.0, 0.0, float(index) * 0.05)
		if weaken:
			enemy["hp"] = 1
			enemy["attack_cooldown"] = 999.0
		active_enemies[enemy_id] = enemy
	combat_system.set("_active_enemies", active_enemies)
	for enemy_id in enemy_ids:
		if combat_system.has_method("_refresh_enemy_node"):
			combat_system._refresh_enemy_node(enemy_id)


func _mode(npc_system: Node, npc_id: String) -> String:
	var snapshot: Dictionary = npc_system.debug_get_behavior_mode_snapshot(npc_id)
	return str(snapshot.get("behavior_mode", ""))


func _last_event(events: Array, event_type: String) -> Dictionary:
	for index in range(events.size() - 1, -1, -1):
		var event: Dictionary = events[index]
		if str(event.get("type", "")) == event_type:
			return event
	return {}
