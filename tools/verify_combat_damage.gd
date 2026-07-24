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
		push_error("Combat damage verification required nodes not found")
		quit(1)
		return

	npc_system.set_npc_recruited("stableman_01", true)
	resource_system.add_resource("item_sword_shield", 1)
	resource_system.add_resource("item_mail_chest", 1)
	var weapon_result: Dictionary = equipment_system.equip_npc_main_weapon("stableman_01", "sword_shield", "private")
	var armor_result: Dictionary = equipment_system.equip_npc_armor("stableman_01", "chest", "mail_chest", "private")
	if not bool(weapon_result.get("ok", false)) or not bool(armor_result.get("ok", false)):
		push_error("Failed to equip stableman for combat damage verification")
		quit(1)
		return

	var stableman_node := root.get_node_or_null("Main/WorldRoot/Station/NPCs/Stableman01") as Node3D
	if stableman_node == null:
		push_error("Stableman node missing")
		quit(1)
		return
	stableman_node.global_position = Vector3(0.0, 0.0, 0.0)

	var spawn_result: Dictionary = combat_system.debug_spawn_wave(1, true)
	if not bool(spawn_result.get("ok", false)):
		push_error("Enemy spawn failed: %s" % JSON.stringify(spawn_result))
		quit(1)
		return
	var enemy_id := _place_first_enemy(combat_system, Vector3(0.0, 0.0, 1.0))
	var enemy_before: Dictionary = combat_system.get_enemy(enemy_id)
	var npc_hp_before := int(npc_system.get_npc_state("stableman_01").get("hp", 0))

	npc_system.set_npc_behavior_mode("stableman_01", "combat", "verify_damage", {
		"state_changes": {
			"current_action": "combat_ready",
			"combat_target_enemy_id": enemy_id,
			"combat_attack_cooldown": 0.0
		},
		"request_plan_reevaluation": false
	})
	var step_result: Dictionary = combat_system.debug_step_enemy_ai(1.0)
	var enemy_after: Dictionary = combat_system.get_enemy(enemy_id)
	var npc_hp_after := int(npc_system.get_npc_state("stableman_01").get("hp", 0))
	if int(enemy_after.get("hp", 0)) >= int(enemy_before.get("hp", 0)):
		push_error("Combat-mode armed NPC should damage enemy. before=%s after=%s" % [
			JSON.stringify(enemy_before),
			JSON.stringify(enemy_after)
		])
		quit(1)
		return
	if npc_hp_after >= npc_hp_before:
		push_error("Enemy should still damage nearby NPC during mutual combat")
		quit(1)
		return
	if npc_hp_before - npc_hp_after >= int(enemy_before.get("attack_power", 0)):
		push_error("NPC armor defense should reduce enemy raw attack damage. before=%d after=%d raw=%d" % [
			npc_hp_before,
			npc_hp_after,
			int(enemy_before.get("attack_power", 0))
		])
		quit(1)
		return
	var friendly_result: Dictionary = step_result.get("friendly_attacks", {})
	if (friendly_result.get("attacks", []) as Array).is_empty():
		push_error("Combat step should expose friendly attack snapshot")
		quit(1)
		return
	if not _npc_has_event(memory_system, "stableman_01", "attack_made"):
		push_error("NPC attack should write attack_made event")
		quit(1)
		return

	var cooldown_after_first := float(npc_system.get_npc_state("stableman_01").get("combat_attack_cooldown", 0.0))
	if cooldown_after_first <= 0.0:
		push_error("NPC attack should leave a positive attack cooldown")
		quit(1)
		return
	var hp_before_short_step := int(combat_system.get_enemy(enemy_id).get("hp", 0))
	var short_step: Dictionary = combat_system.debug_step_enemy_ai(0.1)
	var hp_after_short_step := int(combat_system.get_enemy(enemy_id).get("hp", 0))
	var short_friendly: Dictionary = short_step.get("friendly_attacks", {})
	if hp_after_short_step != hp_before_short_step or _friendly_attack_count(short_friendly) != 0:
		push_error("A short game-second step should not bypass attack interval cooldown")
		quit(1)
		return
	if float(npc_system.get_npc_state("stableman_01").get("combat_attack_cooldown", 0.0)) >= cooldown_after_first:
		push_error("Attack cooldown should decrease by combat action seconds")
		quit(1)
		return

	var active_enemies: Dictionary = combat_system.get("_active_enemies")
	var weakened_enemy: Dictionary = active_enemies.get(enemy_id, {})
	weakened_enemy["hp"] = 1
	active_enemies[enemy_id] = weakened_enemy
	combat_system.set("_active_enemies", active_enemies)
	for raw_other_enemy_id in combat_system.get_active_enemy_ids():
		var other_enemy_id := str(raw_other_enemy_id)
		if other_enemy_id != enemy_id and combat_system.has_method("_remove_enemy_from_combat"):
			combat_system._remove_enemy_from_combat(other_enemy_id)
	npc_system.update_npc_state("stableman_01", {"combat_attack_cooldown": 0.0})
	var kill_step: Dictionary = combat_system.debug_step_enemy_ai(0.1)
	await process_frame
	if combat_system.get_active_enemy_count() != 0:
		push_error("Enemy should be removed from active combat when HP reaches zero. step=%s enemy=%s npc_state=%s" % [
			JSON.stringify(kill_step),
			JSON.stringify(combat_system.get_enemy(enemy_id)),
			JSON.stringify(npc_system.get_npc_state("stableman_01"))
		])
		quit(1)
		return
	if _mode(npc_system, "stableman_01") != "work":
		push_error("Combat NPC should return to work when all enemies are defeated")
		quit(1)
		return

	var avoid_spawn: Dictionary = combat_system.debug_spawn_wave(1, true)
	if not bool(avoid_spawn.get("ok", false)):
		push_error("Enemy spawn for avoid-combat test failed")
		quit(1)
		return
	enemy_id = _place_first_enemy(combat_system, Vector3(0.0, 0.0, 1.0))
	var avoid_enemy_before := int(combat_system.get_enemy(enemy_id).get("hp", 0))
	npc_system.set_npc_behavior_mode("stableman_01", "avoid_combat", "verify_avoid_no_attack", {
		"state_changes": {
			"current_action": "avoid_combat",
			"combat_attack_cooldown": 0.0,
			"combat_target_enemy_id": enemy_id
		},
		"request_plan_reevaluation": false
	})
	combat_system.debug_step_enemy_ai(1.0)
	var avoid_enemy_after := int(combat_system.get_enemy(enemy_id).get("hp", 0))
	if avoid_enemy_after != avoid_enemy_before:
		push_error("avoid_combat NPC should not attack enemies")
		quit(1)
		return

	print("Combat damage verification passed.")
	quit(0)


func _place_first_enemy(combat_system: Node, position: Vector3) -> String:
	var enemy_ids: Array = combat_system.get_active_enemy_ids()
	if enemy_ids.is_empty():
		return ""
	var enemy_id := str(enemy_ids[0])
	var active_enemies: Dictionary = combat_system.get("_active_enemies")
	var enemy: Dictionary = active_enemies.get(enemy_id, {})
	enemy["position"] = position
	active_enemies[enemy_id] = enemy
	combat_system.set("_active_enemies", active_enemies)
	if combat_system.has_method("_refresh_enemy_node"):
		combat_system._refresh_enemy_node(enemy_id)
	return enemy_id


func _friendly_attack_count(friendly_result: Dictionary) -> int:
	var total := 0
	for raw_entry in friendly_result.get("attacks", []):
		var entry: Dictionary = raw_entry
		total += int(entry.get("attack_count", 0))
	return total


func _npc_has_event(memory_system: Node, npc_id: String, event_type: String) -> bool:
	for raw_event in memory_system.get_npc_daily_events(npc_id):
		var event: Dictionary = raw_event
		if str(event.get("type", "")) == event_type:
			return true
	return false


func _mode(npc_system: Node, npc_id: String) -> String:
	var snapshot: Dictionary = npc_system.get_npc_behavior_mode_snapshot(npc_id)
	return str(snapshot.get("behavior_mode", ""))
