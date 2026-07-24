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
	if combat_system == null or npc_system == null or resource_system == null or equipment_system == null:
		push_error("Combat pacing verification required nodes not found")
		quit(1)
		return

	var npc_id := "veteran_deputy_01"
	var initial_weapons := int(resource_system.get_resource("weapons"))
	var initial_unit: Dictionary = equipment_system.get_unit_type_snapshot(npc_id)
	if str(initial_unit.get("main_weapon_id", "")) != "sword_shield" or str(initial_unit.get("unit_type", "")) != "melee_infantry":
		push_error("Ada should enter the initial combat pacing scenario with sword_shield: %s" % JSON.stringify(initial_unit))
		quit(1)
		return
	if int(resource_system.get_resource("weapons")) != initial_weapons:
		push_error("Ada's initial sword_shield must not spend station weapon inventory")
		quit(1)
		return

	var ada_node := root.get_node_or_null("Main/WorldRoot/Station/NPCs/VeteranDeputy01") as Node3D
	if ada_node == null:
		push_error("Ada node missing")
		quit(1)
		return
	ada_node.global_position = Vector3.ZERO

	var spawn_result: Dictionary = combat_system.debug_spawn_wave(1, true)
	if not bool(spawn_result.get("ok", false)):
		push_error("Enemy spawn failed: %s" % JSON.stringify(spawn_result))
		quit(1)
		return

	var enemy_ids := _place_first_wave_in_melee(combat_system)
	if enemy_ids.size() != 3:
		push_error("First wave pacing test expects 3 enemies, got %d" % enemy_ids.size())
		quit(1)
		return

	npc_system.set_npc_behavior_mode(npc_id, "combat", "verify_combat_pacing", {
		"state_changes": {
			"current_action": "combat_ready",
			"combat_target_enemy_id": str(enemy_ids[0]),
			"combat_attack_cooldown": 0.0
		},
		"request_plan_reevaluation": false
	})

	var hp_before := int(npc_system.get_npc_state(npc_id).get("hp", 0))
	var first_enemy_before := int(combat_system.get_enemy(str(enemy_ids[0])).get("hp", 0))
	var first_step: Dictionary = combat_system.debug_step_enemy_ai(60.0)
	var friendly_attacks := _friendly_attack_count(first_step.get("friendly_attacks", {}))
	var enemy_attacks := _enemy_attack_count(first_step)
	var hp_after := int(npc_system.get_npc_state(npc_id).get("hp", 0))
	var first_enemy_after := int(combat_system.get_enemy(str(enemy_ids[0])).get("hp", 0))

	if friendly_attacks != 1:
		push_error("One x1 baseline second should produce exactly one Ada attack, got %d. step=%s" % [
			friendly_attacks,
			JSON.stringify(first_step)
		])
		quit(1)
		return
	if enemy_attacks <= 0 or enemy_attacks > 3:
		push_error("One x1 baseline second should not produce a burst of enemy attacks, got %d. step=%s" % [
			enemy_attacks,
			JSON.stringify(first_step)
		])
		quit(1)
		return
	if hp_after >= hp_before or hp_after <= 0:
		push_error("Ada should take bounded damage and remain conscious after the first baseline second. before=%d after=%d" % [
			hp_before,
			hp_after
		])
		quit(1)
		return
	if first_enemy_after >= first_enemy_before or first_enemy_after <= 0:
		push_error("First enemy should be damaged but not instantly defeated. before=%d after=%d" % [
			first_enemy_before,
			first_enemy_after
		])
		quit(1)
		return
	if combat_system.get_active_enemy_count() != 3:
		push_error("First wave should not be cleared after one x1 baseline second")
		quit(1)
		return

	var elapsed_combat_seconds := 1.0
	while (
		combat_system.get_active_enemy_count() > 0
		and not bool(npc_system.get_npc_state(npc_id).get("unconscious", false))
		and elapsed_combat_seconds < 30.0
	):
		combat_system.debug_step_enemy_ai(60.0)
		elapsed_combat_seconds += 1.0

	if elapsed_combat_seconds < 8.0:
		push_error("Ada vs first wave ended too quickly: %.2f combat seconds" % elapsed_combat_seconds)
		quit(1)
		return
	if combat_system.get_active_enemy_count() != 0:
		push_error("Ada should be able to finish the tuned first wave within 30 combat seconds. active=%d hp=%s" % [
			combat_system.get_active_enemy_count(),
			JSON.stringify(npc_system.get_npc_state(npc_id))
		])
		quit(1)
		return
	if bool(npc_system.get_npc_state(npc_id).get("unconscious", false)):
		push_error("Ada should survive the tuned first wave with a sword")
		quit(1)
		return

	print("Combat pacing verification passed.")
	quit(0)


func _place_first_wave_in_melee(combat_system: Node) -> Array[String]:
	var enemy_ids: Array = combat_system.get_active_enemy_ids()
	var positions: Array[Vector3] = [
		Vector3(0.0, 0.0, 1.1),
		Vector3(1.15, 0.0, 0.75),
		Vector3(-1.15, 0.0, 0.75)
	]
	var active_enemies: Dictionary = combat_system.get("_active_enemies")
	var placed: Array[String] = []
	for index in range(mini(enemy_ids.size(), positions.size())):
		var enemy_id := str(enemy_ids[index])
		var enemy: Dictionary = active_enemies.get(enemy_id, {})
		enemy["position"] = positions[index]
		enemy["attack_cooldown"] = 0.0
		active_enemies[enemy_id] = enemy
		placed.append(enemy_id)
	combat_system.set("_active_enemies", active_enemies)
	for enemy_id in placed:
		if combat_system.has_method("_refresh_enemy_node"):
			combat_system._refresh_enemy_node(enemy_id)
	return placed


func _friendly_attack_count(friendly_result: Dictionary) -> int:
	var total := 0
	for raw_entry in friendly_result.get("attacks", []):
		var entry: Dictionary = raw_entry
		total += int(entry.get("attack_count", 0))
	return total


func _enemy_attack_count(step_result: Dictionary) -> int:
	var total := 0
	for raw_entry in step_result.get("attacks", []):
		var entry: Dictionary = raw_entry
		total += int(entry.get("attack_count", 0))
	return total
