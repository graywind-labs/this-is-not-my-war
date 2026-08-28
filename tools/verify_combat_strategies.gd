extends SceneTree


func _init() -> void:
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
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var npc_panel := root.get_node_or_null("Main/UI/NPCPanel")
	if (
		combat_system == null
		or equipment_system == null
		or npc_system == null
		or resource_system == null
		or memory_system == null
		or npc_panel == null
	):
		push_error("T1105 combat strategy verification required systems are missing")
		quit(1)
		return

	var npc_id := "veteran_deputy_01"
	resource_system.add_resource("item_sword_shield", 2)
	resource_system.add_resource("item_bow", 1)

	var sword_result: Dictionary = equipment_system.equip_npc_main_weapon(npc_id, "sword_shield", "local_public")
	if not bool(sword_result.get("ok", false)):
		push_error("Failed to equip sword_shield: %s" % JSON.stringify(sword_result))
		quit(1)
		return
	if not _assert_strategy_ids(combat_system.get_npc_combat_strategy_options(npc_id), ["attack", "avoid"], "sword options"):
		quit(1)
		return
	if str(combat_system.get_npc_combat_strategy(npc_id).get("id", "")) != "attack":
		push_error("Sword shield default strategy should be attack")
		quit(1)
		return

	npc_system.debug_select_npc(npc_id)
	await process_frame
	var strategy_select := root.find_child("NPCCombatStrategySelect", true, false) as OptionButton
	if strategy_select == null:
		push_error("NPCPanel should create combat strategy selector beside weapon equip controls")
		quit(1)
		return
	if not _select_option_by_id(strategy_select, "avoid"):
		push_error("NPC strategy selector should include avoid for sword shield")
		quit(1)
		return
	strategy_select.item_selected.emit(strategy_select.selected)
	await process_frame
	if str(combat_system.get_npc_combat_strategy(npc_id).get("id", "")) != "avoid":
		push_error("NPCPanel strategy selector did not apply avoid strategy")
		quit(1)
		return
	if not _has_event(memory_system.get_npc_daily_events(npc_id), "combat_strategy_selected"):
		push_error("Manual combat strategy selection should write combat_strategy_selected")
		quit(1)
		return

	var bow_result: Dictionary = equipment_system.equip_npc_main_weapon(npc_id, "bow", "local_public")
	if not bool(bow_result.get("ok", false)):
		push_error("Failed to equip bow: %s" % JSON.stringify(bow_result))
		quit(1)
		return
	if not _assert_strategy_ids(combat_system.get_npc_combat_strategy_options(npc_id), ["max_output", "keep_distance", "avoid"], "bow options"):
		quit(1)
		return
	if str(combat_system.get_npc_combat_strategy(npc_id).get("id", "")) != "max_output":
		push_error("Bow should normalize invalid melee strategy to max_output")
		quit(1)
		return

	var mount_result: Dictionary = equipment_system.equip_npc_mount(npc_id, "", "local_public")
	if not bool(mount_result.get("ok", false)):
		push_error("Failed to equip mount: %s" % JSON.stringify(mount_result))
		quit(1)
		return
	if not _assert_strategy_ids(combat_system.get_npc_combat_strategy_options(npc_id), ["max_output", "keep_distance", "avoid"], "mounted ranged options"):
		quit(1)
		return

	var cavalry_id := "stableman_01"
	npc_system.set_npc_recruited(cavalry_id, true)
	var cavalry_weapon: Dictionary = equipment_system.equip_npc_main_weapon(cavalry_id, "sword_shield", "local_public")
	var cavalry_mount: Dictionary = equipment_system.equip_npc_mount(cavalry_id, "", "local_public")
	if not bool(cavalry_weapon.get("ok", false)) or not bool(cavalry_mount.get("ok", false)):
		push_error("Failed to equip cavalry test NPC")
		quit(1)
		return
	if not _assert_strategy_ids(combat_system.get_npc_combat_strategy_options(cavalry_id), ["attack", "charge_cycle", "avoid"], "cavalry options"):
		quit(1)
		return

	combat_system.debug_clear_enemies()
	var spawn_result: Dictionary = combat_system.debug_spawn_wave(1, true)
	if not bool(spawn_result.get("ok", false)):
		push_error("Failed to spawn wave for strategy behavior test")
		quit(1)
		return
	var enemy_id := _place_first_enemy(combat_system, Vector3(0.0, 0.0, 3.0), 100)
	npc_system.set_npc_behavior_mode(npc_id, "combat", "verify_strategy_avoid", {
		"state_changes": {
			"current_action": "combat_ready",
			"combat_target_enemy_id": enemy_id,
			"combat_attack_cooldown": 0.0
		},
		"request_plan_reevaluation": false
	})
	# This verifier isolates strategy behavior; the mounted lifecycle has its own
	# real-navigation test, so finish the assigned-horse pickup fixture here.
	npc_system.stop_npc_movement_with_state(npc_id, {
		"combat_mounted": true,
		"combat_mount_phase": "mounted",
		"current_action": "combat_ready"
	})
	var ranged_origin: Vector3 = npc_system.get_npc_world_position(npc_id)
	_place_first_enemy(combat_system, ranged_origin + Vector3(0.0, 0.0, 2.0), 100)
	combat_system.set_npc_combat_strategy(npc_id, "avoid", "private")
	var avoid_hp_before := int(combat_system.get_enemy(enemy_id).get("hp", 0))
	var avoid_step: Dictionary = combat_system.debug_step_enemy_ai(1.0)
	var avoid_hp_after := int(combat_system.get_enemy(enemy_id).get("hp", 0))
	if avoid_hp_after != avoid_hp_before:
		push_error("Combat avoid strategy should not attack while avoiding. step=%s" % JSON.stringify(avoid_step))
		quit(1)
		return
	var avoid_state: Dictionary = npc_system.get_npc_state(npc_id)
	if not str(avoid_state.get("current_action", "")).begins_with("moving_to_combat_strategy_"):
		push_error("Combat avoid strategy should reuse short-step avoidance movement without leaving combat mode: %s" % JSON.stringify(avoid_state))
		quit(1)
		return
	var avoid_movement := _first_strategy_movement(avoid_step)
	var avoid_travel := float(avoid_movement.get("travel_distance", 999.0))
	if avoid_travel > 3.4:
		push_error("Combat avoid strategy should move by a short avoidance step, not run to a corner. movement=%s" % JSON.stringify(avoid_movement))
		quit(1)
		return
	if str(npc_system.get_npc_behavior_mode_snapshot(npc_id).get("behavior_mode", "")) != "combat":
		push_error("Combat avoid strategy must remain behavior_mode=combat")
		quit(1)
		return

	_place_first_enemy(combat_system, ranged_origin + Vector3(0.0, 0.0, 13.0), 100)
	var avoid_stop_step: Dictionary = combat_system.debug_step_enemy_ai(1.0)
	var avoid_stop_state: Dictionary = npc_system.get_npc_state(npc_id)
	if str(avoid_stop_state.get("current_action", "")) != "combat_ready":
		push_error("Combat avoid strategy should stop moving and wait once enemy is far enough. step=%s state=%s" % [
			JSON.stringify(avoid_stop_step),
			JSON.stringify(avoid_stop_state)
		])
		quit(1)
		return
	var avoid_stop_movement := _first_strategy_movement(avoid_stop_step)
	if not bool(avoid_stop_movement.get("holding", false)) or not bool(avoid_stop_movement.get("stopped_movement", false)):
		push_error("Combat avoid strategy should report stopped holding after enemy leaves safe range. movement=%s" % JSON.stringify(avoid_stop_movement))
		quit(1)
		return

	combat_system.debug_clear_enemies()
	combat_system.debug_spawn_wave(1, true)
	# T0188 raises the minimum safe distance from the legacy 6.25 m to 8.5 m;
	# use a point beyond the current data contract for the already-safe fixture.
	enemy_id = _place_first_enemy(combat_system, ranged_origin + Vector3(0.0, 0.0, 10.0), 100)
	_set_npc_world_position(npc_id, ranged_origin)
	npc_system.set_npc_behavior_mode(npc_id, "combat", "verify_strategy_avoid_holding", {
		"state_changes": {
			"current_action": "combat_ready",
			"combat_target_enemy_id": enemy_id,
			"combat_attack_cooldown": 0.0
		},
		"request_plan_reevaluation": false
	})
	npc_system.stop_npc_movement_with_state(npc_id, {
		"combat_mounted": true,
		"combat_mount_phase": "mounted",
		"current_action": "combat_ready",
		"combat_target_enemy_id": enemy_id
	})
	_set_npc_world_position(npc_id, ranged_origin)
	combat_system.set_npc_combat_strategy(npc_id, "avoid", "private")
	var avoid_hold_hp_before := int(combat_system.get_enemy(enemy_id).get("hp", 0))
	var avoid_hold_step: Dictionary = combat_system.debug_step_enemy_ai(1.0)
	var avoid_hold_hp_after := int(combat_system.get_enemy(enemy_id).get("hp", 0))
	if avoid_hold_hp_after != avoid_hold_hp_before:
		push_error("Combat avoid holding should not attack. step=%s" % JSON.stringify(avoid_hold_step))
		quit(1)
		return
	var avoid_hold_state: Dictionary = npc_system.get_npc_state(npc_id)
	if str(avoid_hold_state.get("current_action", "")) != "combat_ready":
		push_error("Combat avoid strategy should wait in place when enemy is already far enough. step=%s state=%s" % [
			JSON.stringify(avoid_hold_step),
			JSON.stringify(avoid_hold_state)
		])
		quit(1)
		return
	var avoid_hold_movement := _first_strategy_movement(avoid_hold_step)
	if not bool(avoid_hold_movement.get("holding", false)) or str(avoid_hold_movement.get("reason", "")) != "combat_strategy_avoid_holding":
		push_error("Combat avoid strategy should report holding when enemy is already far enough. movement=%s" % JSON.stringify(avoid_hold_movement))
		quit(1)
		return

	combat_system.debug_clear_enemies()
	combat_system.debug_spawn_wave(1, true)
	enemy_id = _place_first_enemy(combat_system, ranged_origin + Vector3(0.0, 0.0, 2.0), 100)
	_set_npc_world_position(npc_id, ranged_origin)
	npc_system.set_npc_behavior_mode(npc_id, "combat", "verify_keep_distance", {
		"state_changes": {
			"current_action": "combat_ready",
			"combat_target_enemy_id": enemy_id,
			"combat_attack_cooldown": 0.0
		},
		"request_plan_reevaluation": false
	})
	npc_system.stop_npc_movement_with_state(npc_id, {
		"combat_mounted": true,
		"combat_mount_phase": "mounted",
		"current_action": "combat_ready",
		"combat_target_enemy_id": enemy_id
	})
	_set_npc_world_position(npc_id, ranged_origin)
	combat_system.set_npc_combat_strategy(npc_id, "keep_distance", "private")
	var keep_step: Dictionary = combat_system.debug_step_enemy_ai(1.0)
	var keep_state: Dictionary = npc_system.get_npc_state(npc_id)
	if not str(keep_state.get("current_action", "")).begins_with("moving_to_combat_strategy_"):
		push_error("Keep-distance shooting should move a short distance before shooting when enemy is too close. step=%s state=%s" % [
			JSON.stringify(keep_step),
			JSON.stringify(keep_state)
		])
		quit(1)
		return
	var keep_target := _first_strategy_movement(keep_step)
	var target_distance := float(keep_target.get("target_enemy_distance", 999.0))
	var keep_min_distance := float(combat_system._get_keep_distance_min_distance(12.0))
	if target_distance < keep_min_distance or target_distance > 12.0:
		push_error("Keep-distance shooting should move into its configured min/range band, target distance %.2f" % target_distance)
		quit(1)
		return

	combat_system.debug_clear_enemies()
	combat_system.debug_spawn_wave(1, true)
	enemy_id = _place_first_enemy(combat_system, Vector3(0.0, 0.0, 1.2), 200)
	var charge_select: Dictionary = combat_system.set_npc_combat_strategy(cavalry_id, "charge_cycle", "private")
	if not bool(charge_select.get("ok", false)):
		push_error("Failed to select cavalry charge-cycle strategy")
		quit(1)
		return
	npc_system.set_npc_behavior_mode(cavalry_id, "combat", "verify_charge_impact", {
		"state_changes": {
			"current_action": "combat_ready",
			"combat_target_enemy_id": enemy_id,
			"combat_attack_cooldown": 0.0,
			"combat_charge_phase": "impact"
		},
		"request_plan_reevaluation": false
	})
	npc_system.stop_npc_movement_with_state(cavalry_id, {
		"combat_mounted": true,
		"combat_mount_phase": "mounted",
		"current_action": "combat_ready",
		"combat_target_enemy_id": enemy_id,
		"combat_charge_phase": "impact"
	})
	var cavalry_origin: Vector3 = npc_system.get_npc_world_position(cavalry_id)
	_place_first_enemy(combat_system, cavalry_origin + Vector3(0.0, 0.0, 1.2), 200)
	var active_enemies: Dictionary = combat_system.get("_active_enemies")
	var winding_enemy: Dictionary = active_enemies.get(enemy_id, {})
	winding_enemy["attack_windup_remaining"] = 0.4
	winding_enemy["attack_windup_target"] = {
		"type": "npc",
		"id": cavalry_id,
		"name": "托马"
	}
	winding_enemy["current_action"] = "winding_up_%s" % cavalry_id
	active_enemies[enemy_id] = winding_enemy
	combat_system.set("_active_enemies", active_enemies)
	var charge_hp_before := int(combat_system.get_enemy(enemy_id).get("hp", 0))
	var charge_context: Dictionary = combat_system._calculate_npc_attack_context(
		cavalry_id,
		npc_system.get_npc(cavalry_id),
		npc_system.get_npc_state(cavalry_id)
	)
	var charge_impact_seconds := float((charge_context.get("animation_timing", {}) as Dictionary).get("impact_seconds", 0.0))
	var charge_windup: Dictionary = combat_system._advance_single_npc_combat_attack(cavalry_id, maxf(0.001, charge_impact_seconds - 0.01))
	if int(charge_windup.get("attack_count", 0)) != 0:
		push_error("Charge-cycle collision must wait for the approved weapon impact: %s" % JSON.stringify(charge_windup))
		quit(1)
		return
	var charge_result: Dictionary = combat_system._advance_single_npc_combat_attack(cavalry_id, 0.02)
	var charge_attacks: Array = charge_result.get("attacks", [])
	var charge_attack: Dictionary = charge_attacks[0] if not charge_attacks.is_empty() else {}
	if charge_attack.is_empty():
		push_error("Charge-cycle impact should produce a weapon attack plus horse collision: %s" % JSON.stringify(charge_result))
		quit(1)
		return
	var charge_impact: Dictionary = charge_attack.get("charge_impact", {})
	var charged_enemy: Dictionary = combat_system.get_enemy(enemy_id)
	var charge_hp_loss := charge_hp_before - int(charged_enemy.get("hp", 0))
	var collision_damage := int(charge_impact.get("collision_damage", 0))
	var weapon_damage := int(charge_attack.get("damage", 0))
	var base_context: Dictionary = charge_impact.get("base_attack_context", {})
	var unboosted_weapon_damage := int(combat_system.calculate_damage_resolution(
		float(base_context.get("raw_attack_power", 0.0)),
		float(charge_attack.get("target_defense", 0.0)),
		float(charge_attack.get("penetration", 0.0))
	).get("damage", 0))
	if (
		collision_damage <= 0
		or float(charge_impact.get("weapon_damage_multiplier", 1.0)) <= 1.0
		or charge_hp_loss != collision_damage + weapon_damage
		or (weapon_damage > 0 and weapon_damage <= unboosted_weapon_damage)
	):
		push_error("Mounted charge should always apply independent collision damage and only add boosted weapon damage on actual weapon contact")
		quit(1)
		return
	if (
		not bool(charge_impact.get("interrupted_windup", false))
		or float(charged_enemy.get("stagger_remaining", 0.0)) <= 0.0
		or float(charged_enemy.get("attack_windup_remaining", -1.0)) != 0.0
		or int(charged_enemy.get("windup_interrupt_count", 0)) <= 0
	):
		push_error("Horse collision should stagger the enemy and interrupt its active windup: %s" % JSON.stringify(charged_enemy))
		quit(1)
		return
	if str(npc_system.get_npc_state(cavalry_id).get("combat_charge_phase", "")) != "withdraw":
		push_error("Cavalry should return to withdraw phase after an impact")
		quit(1)
		return

	print("T1105 combat strategy verification passed.")
	quit(0)


func _assert_strategy_ids(options: Array, expected_ids: Array[String], label: String) -> bool:
	var actual: Array[String] = []
	for raw_option in options:
		var option: Dictionary = raw_option if raw_option is Dictionary else {}
		actual.append(str(option.get("id", "")))
	if actual != expected_ids:
		push_error("%s mismatch. expected=%s actual=%s" % [label, JSON.stringify(expected_ids), JSON.stringify(actual)])
		return false
	return true


func _select_option_by_id(select: OptionButton, expected_id: String) -> bool:
	for index in range(select.get_item_count()):
		if str(select.get_item_metadata(index)) == expected_id:
			select.select(index)
			return true
	return false


func _has_event(events: Array, event_type: String) -> bool:
	for raw_event in events:
		var event: Dictionary = raw_event if raw_event is Dictionary else {}
		if str(event.get("type", "")) == event_type:
			return true
	return false


func _first_strategy_movement(step: Dictionary) -> Dictionary:
	var friendly_attacks: Dictionary = step.get("friendly_attacks", {}) if (step.get("friendly_attacks", {}) is Dictionary) else {}
	var attack_entries: Array = friendly_attacks.get("attacks", []) if (friendly_attacks.get("attacks", []) is Array) else []
	for raw_entry in attack_entries:
		var entry: Dictionary = raw_entry if raw_entry is Dictionary else {}
		var movement: Dictionary = entry.get("strategy_movement", {}) if (entry.get("strategy_movement", {}) is Dictionary) else {}
		if not movement.is_empty():
			return movement
	return {}


func _first_charge_attack(step: Dictionary, npc_id: String) -> Dictionary:
	var friendly_attacks: Dictionary = step.get("friendly_attacks", {}) if step.get("friendly_attacks", {}) is Dictionary else {}
	for raw_entry in friendly_attacks.get("attacks", []):
		var entry: Dictionary = raw_entry if raw_entry is Dictionary else {}
		if str(entry.get("npc_id", "")) != npc_id:
			continue
		for raw_attack in entry.get("attacks", []):
			var attack: Dictionary = raw_attack if raw_attack is Dictionary else {}
			if attack.get("charge_impact", {}) is Dictionary and not (attack.get("charge_impact", {}) as Dictionary).is_empty():
				return attack
	return {}


func _place_first_enemy(combat_system: Node, position: Vector3, hp: int = 60) -> String:
	var enemy_ids: Array = combat_system.get_active_enemy_ids()
	if enemy_ids.is_empty():
		push_error("No enemy available to place")
		quit(1)
		return ""
	var enemy_id := str(enemy_ids[0])
	var active_enemies: Dictionary = combat_system.get("_active_enemies")
	var enemy: Dictionary = active_enemies.get(enemy_id, {})
	enemy["position"] = position
	enemy["hp"] = hp
	enemy["max_hp"] = maxi(hp, int(enemy.get("max_hp", hp)))
	enemy["alive"] = true
	active_enemies[enemy_id] = enemy
	combat_system.set("_active_enemies", active_enemies)
	if combat_system.has_method("_refresh_enemy_node"):
		combat_system._refresh_enemy_node(enemy_id)
	return enemy_id


func _set_npc_world_position(npc_id: String, position: Vector3) -> void:
	var npc_root := root.get_node_or_null("Main/WorldRoot/Station/NPCs")
	if npc_root == null:
		push_error("NPC root missing")
		quit(1)
		return
	for child in npc_root.get_children():
		if str(child.get_meta("npc_id", "")) == npc_id and child is Node3D:
			(child as Node3D).global_position = position
			return
	push_error("NPC node missing: %s" % npc_id)
	quit(1)
