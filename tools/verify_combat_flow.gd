extends SceneTree


const COMBAT_ANIMATION_TIMING := preload("res://scripts/presentation/characters/CombatAnimationTiming.gd")
const COMBAT_NPC_ID := "stableman_01"


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

	combat_system.debug_step_enemy_ai(1.0)
	if _mode(npc_system, "stableman_01") != "combat":
		push_error("Recruited armed NPC should enter combat on enemy contact")
		quit(1)
		return
	var contact_result := await _resolve_formal_sword_contact(combat_system, npc_system, enemy_ids, formal_combatant_position)
	if not bool(contact_result.get("ok", false)):
		push_error("Formal combat-flow contact fixture failed: %s" % JSON.stringify(contact_result))
		quit(1)
		return
	var injury_source: Dictionary = combat_system.get_enemy(str(enemy_ids[1])) if enemy_ids.size() > 1 else {}
	var injury_result: Dictionary = npc_system.apply_damage_to_npc(COMBAT_NPC_ID, 3, str(injury_source.get("id", "flow_enemy")), "local_public")
	combat_system._record_battle_npc_damage(COMBAT_NPC_ID, "托马", injury_source, injury_result)
	for raw_enemy_id in combat_system.get_active_enemy_ids().duplicate():
		var remaining_id := str(raw_enemy_id)
		var remaining: Dictionary = combat_system.get_enemy(remaining_id)
		combat_system._apply_damage_to_enemy(remaining_id, int(remaining.get("hp", 1)), COMBAT_NPC_ID, {
			"source_type": "verified_flow_cleanup",
			"verified_contact_attack_id": str(contact_result.get("attack_id", ""))
		})
	var kill_result: Dictionary = combat_system._handle_all_enemies_cleared("verified_formal_contact_flow")
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


func _resolve_formal_sword_contact(combat_system: Node, npc_system: Node, enemy_ids: Array[String], source_position: Vector3) -> Dictionary:
	if enemy_ids.is_empty():
		return {"ok": false, "reason": "enemy_fixture_missing"}
	var source_node := _get_npc_node(npc_system, COMBAT_NPC_ID)
	if source_node == null:
		return {"ok": false, "reason": "formal_npc_wrapper_missing"}
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	if time_system != null:
		time_system.set_paused(true)
	var enemy_id := str(enemy_ids[0])
	var formal_slices: Dictionary = combat_system.get("_formal_first_wave_slices")
	formal_slices.erase(enemy_id)
	combat_system.set("_formal_first_wave_slices", formal_slices)
	for index in range(enemy_ids.size()):
		var candidate_id := str(enemy_ids[index])
		_set_enemy_position_and_hp(
			combat_system,
			candidate_id,
			source_position + Vector3(30.0 + float(index), 0.0, 30.0),
			1
		)
	var sequence := 1506001
	var timing: Dictionary = COMBAT_ANIMATION_TIMING.get_timing("sword_shield", 1.0)
	npc_system.update_npc_state(COMBAT_NPC_ID, {
		"behavior_mode": "combat",
		"combat_mode": "combat",
		"combat_mounted": false,
		"current_action": "winding_up_%s" % enemy_id,
		"combat_attack_sequence": sequence,
		"combat_attack_phase": "windup",
		"combat_attack_cycle_seconds": 1.0,
		"combat_attack_impact_seconds": float(timing.get("impact_seconds", 0.0)),
		"combat_attack_elapsed_seconds": 0.0,
		"combat_attack_playback_multiplier": float(timing.get("playback_multiplier", 1.0)),
	})
	source_node.set_facing_direction(Vector3(0.0, 0.0, -1.0))
	await process_frame
	var character_art := source_node.get("_character_art_view") as Node
	var animation_player := character_art.find_child("PilotAnimationPlayer", true, false) as AnimationPlayer if character_art != null else null
	if animation_player == null:
		return {"ok": false, "reason": "formal_animation_player_missing"}
	var contact_config: Dictionary = combat_system._get_weapon_melee_contact_config("sword_shield")
	var impact_authored := float(timing.get("impact_authored_seconds", 0.0))
	var window := float(contact_config.get("sample_window_authored_seconds", 0.22))
	var count := maxi(2, int(contact_config.get("sample_count", 7)))
	var samples: Array[Dictionary] = []
	animation_player.play("Melee_1H_Attack_Slice_Horizontal", 0.0)
	for index in range(count):
		var weight := float(index) / float(count - 1)
		animation_player.seek(lerpf(maxf(0.0, impact_authored - window), impact_authored, weight), true)
		animation_player.pause()
		await process_frame
		var sample: Dictionary = npc_system.get_npc_combat_melee_contact_segment(COMBAT_NPC_ID, "sword_shield")
		if not sample.is_empty():
			samples.append(sample)
	if samples.size() < 2:
		return {"ok": false, "reason": "formal_melee_geometry_unavailable", "sample_count": samples.size()}
	var contact_sample: Dictionary = samples.back()
	var max_reach := 0.0
	for sample in samples:
		var tip: Vector3 = sample.get("contact_end", source_position)
		var reach := Vector2(tip.x - source_position.x, tip.z - source_position.z).length()
		if reach > max_reach:
			max_reach = reach
			contact_sample = sample
	var contact_start: Vector3 = contact_sample.get("contact_start", source_position)
	var contact_end: Vector3 = contact_sample.get("contact_end", contact_start)
	var visible_contact := contact_start.lerp(contact_end, 0.78)
	_set_enemy_position_and_hp(combat_system, enemy_id, Vector3(visible_contact.x, source_position.y, visible_contact.z), 1)
	await physics_frame
	var target: Dictionary = combat_system.get_enemy(enemy_id)
	combat_system._begin_melee_swing("friendly", COMBAT_NPC_ID, "sword_shield", target, sequence)
	animation_player.play("Melee_1H_Attack_Slice_Horizontal", 0.0)
	for index in range(count):
		var weight := float(index) / float(count - 1)
		animation_player.seek(lerpf(maxf(0.0, impact_authored - window), impact_authored, weight), true)
		animation_player.pause()
		await process_frame
		combat_system._sample_melee_swing("friendly:%s" % COMBAT_NPC_ID)
	var resolved: Dictionary = combat_system._resolve_npc_melee_contact(
		COMBAT_NPC_ID,
		npc_system.get_npc(COMBAT_NPC_ID),
		target,
		combat_system._calculate_npc_attack_context(COMBAT_NPC_ID, npc_system.get_npc(COMBAT_NPC_ID), npc_system.get_npc_state(COMBAT_NPC_ID))
	)
	if time_system != null:
		time_system.set_paused(false)
	return {
		"ok": str(resolved.get("melee_status", "")) == "hit" and not combat_system.get_active_enemy_ids().has(enemy_id),
		"attack_id": "friendly:%s:%d" % [COMBAT_NPC_ID, sequence],
		"resolution": resolved,
		"sample_count": samples.size(),
		"model_reach": max_reach,
	}


func _set_enemy_position_and_hp(combat_system: Node, enemy_id: String, position: Vector3, hp: int) -> void:
	var enemy: Dictionary = combat_system.get_enemy(enemy_id)
	if enemy.is_empty():
		return
	enemy["position"] = position
	enemy["hp"] = hp
	enemy["max_hp"] = maxi(hp, 1)
	enemy["alive"] = true
	var active_enemies: Dictionary = combat_system.get("_active_enemies")
	active_enemies[enemy_id] = enemy
	combat_system.set("_active_enemies", active_enemies)
	var node_paths: Dictionary = combat_system.get("_enemy_nodes")
	var enemy_node := combat_system.get_node_or_null(node_paths.get(enemy_id, NodePath())) as Node3D if node_paths.has(enemy_id) else null
	if enemy_node != null:
		enemy_node.global_position = position
	combat_system._refresh_enemy_node(enemy_id)


func _get_npc_node(npc_system: Node, npc_id: String) -> Node3D:
	var npc_nodes: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(npc_nodes.get(npc_id, NodePath())) as Node3D


func _mode(npc_system: Node, npc_id: String) -> String:
	var snapshot: Dictionary = npc_system.debug_get_behavior_mode_snapshot(npc_id)
	return str(snapshot.get("behavior_mode", ""))


func _last_event(events: Array, event_type: String) -> Dictionary:
	for index in range(events.size() - 1, -1, -1):
		var event: Dictionary = events[index]
		if str(event.get("type", "")) == event_type:
			return event
	return {}
