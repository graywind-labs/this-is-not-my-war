extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const SHOOTER_NPC_ID := "stableman_01"
const FRIENDLY_BLOCKER_NPC_ID := "cook_01"
const PROJECTILE_STEP_SECONDS := 0.05

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	for _frame in range(6):
		await process_frame
		await physics_frame

	var combat := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var equipment := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var resources := root.get_node_or_null("Main/Systems/ResourceSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	_check(not [combat, npc_system, equipment, resources, time_system, controller].has(null), "T0248 production dependencies missing")
	if not _failures.is_empty():
		_finish()
		return

	resources.add_resource("item_bow", 2)
	npc_system.set_npc_recruited(SHOOTER_NPC_ID, true)
	npc_system.set_npc_behavior_mode(SHOOTER_NPC_ID, "work", "verify_t0248_equip", {"request_plan_reevaluation": false})
	npc_system.stop_npc_movement_with_state(SHOOTER_NPC_ID, {"current_action": "idle", "combat_mounted": false})
	var equip_result: Dictionary = equipment.equip_npc_main_weapon(SHOOTER_NPC_ID, "bow", "private")
	_check(bool(equip_result.get("ok", false)), "T0248 could not equip friendly bow: %s" % equip_result)
	var spawned: Dictionary = combat.debug_run_formal_dynamic_wave_slice(1, true)
	_check(bool(spawned.get("ok", false)), "T0248 first wave failed to spawn: %s" % spawned)
	var enemy_ids: Array[String] = combat.get_active_enemy_ids()
	_check(enemy_ids.size() >= 4, "T0248 requires four formal enemies")
	if not _failures.is_empty():
		_finish()
		return

	var navigation_map: RID = controller.get_production_navigation_map_rid()
	var friendly_origin := NavigationServer3D.map_get_closest_point(navigation_map, Vector3(-3.0, 0.0, 22.0))
	var friendly_middle := NavigationServer3D.map_get_closest_point(navigation_map, Vector3(-3.0, 0.0, 26.0))
	var enemy_end := NavigationServer3D.map_get_closest_point(navigation_map, Vector3(-3.0, 0.0, 30.0))
	var shooter_actor := _get_npc_actor(npc_system, SHOOTER_NPC_ID)
	var friendly_blocker_actor := _get_npc_actor(npc_system, FRIENDLY_BLOCKER_NPC_ID)
	_check(shooter_actor != null and friendly_blocker_actor != null, "T0248 NPC actors missing")
	if not _failures.is_empty():
		_finish()
		return
	_place_npc(shooter_actor, friendly_origin)
	_place_npc(friendly_blocker_actor, friendly_middle)
	npc_system.update_npc_state(SHOOTER_NPC_ID, {"hp": 10000, "max_hp": 10000, "unconscious": false, "combat_mounted": false})
	npc_system.update_npc_state(FRIENDLY_BLOCKER_NPC_ID, {"hp": 10000, "max_hp": 10000, "unconscious": false, "combat_mounted": false})

	var friendly_target_id := enemy_ids[0]
	var enemy_shooter_id := enemy_ids[1]
	var enemy_blocker_id := enemy_ids[2]
	var corpse_target_id := enemy_ids[3]
	_place_enemy(combat, friendly_target_id, enemy_end, 500, "sword_shield")
	for index in range(1, enemy_ids.size()):
		var far_position := NavigationServer3D.map_get_closest_point(navigation_map, Vector3(12.0 + float(index), 0.0, 42.0 + float(index)))
		_place_enemy(combat, enemy_ids[index], far_position, 500, "sword_shield")
	await physics_frame
	time_system.set_paused(true)

	# Friendly arrow: the cook overlaps the trajectory but is transparent; the
	# actual enemy collider receives damage and owns the stuck presentation.
	var target_hp_before := int(combat.get_enemy(friendly_target_id).get("hp", 0))
	var friendly_release := _release_friendly(combat, npc_system, friendly_target_id)
	_check(str(friendly_release.get("projectile_status", "")) == "in_flight", "T0248 friendly arrow was not released")
	_advance_until_resolved(combat)
	var friendly_hit: Dictionary = combat.debug_get_combat_snapshot().get("last_projectile_result", {})
	_check(str(friendly_hit.get("status", "")) == "hit", "T0248 friendly arrow did not hit after passing ally: %s" % JSON.stringify(friendly_hit))
	_check(str((friendly_hit.get("resolution", {}) as Dictionary).get("actual_target_id", "")) == friendly_target_id, "T0248 friendly arrow did not hit the physical enemy")
	_check(int(combat.get_enemy(friendly_target_id).get("hp", 0)) < target_hp_before, "T0248 friendly arrow applied no enemy damage")
	_check(int(friendly_hit.get("same_side_skip_count", 0)) >= 1, "T0248 friendly arrow did not record same-side pass-through")
	_check((friendly_hit.get("same_side_skipped_ids", PackedStringArray()) as PackedStringArray).has(FRIENDLY_BLOCKER_NPC_ID), "T0248 friendly blocker identity was not skipped")
	var friendly_stuck: Dictionary = friendly_hit.get("stuck_projectile", {}) if friendly_hit.get("stuck_projectile", {}) is Dictionary else {}
	_check(str(friendly_stuck.get("anchor_kind", "")) == "enemy", "T0248 friendly hit arrow was not attached to enemy")
	var friendly_arrow_id := str(friendly_stuck.get("id", ""))
	var friendly_arrow_before: Vector3 = friendly_stuck.get("world_position", Vector3.ZERO)
	var target_actor := _get_enemy_actor(combat, friendly_target_id)
	var target_shift := Vector3(1.75, 0.0, 0.0)
	if target_actor != null:
		_place_enemy(combat, friendly_target_id, target_actor.global_position + target_shift, int(combat.get_enemy(friendly_target_id).get("hp", 1)), "sword_shield")
	await physics_frame
	var friendly_arrow_after := _find_stuck(combat, friendly_arrow_id)
	_check(not friendly_arrow_after.is_empty(), "T0248 enemy-attached arrow disappeared while target lived")
	_check((friendly_arrow_after.get("world_position", Vector3.ZERO) as Vector3).distance_to(friendly_arrow_before + target_shift) < 0.3, "T0248 arrow did not follow living enemy")

	# Enemy arrow: another enemy occupies the line but must be ignored; the NPC
	# capsule is the first hostile collider and owns the attached arrow.
	_place_npc(shooter_actor, friendly_origin)
	_place_npc(friendly_blocker_actor, NavigationServer3D.map_get_closest_point(navigation_map, Vector3(8.0, 0.0, 22.0)))
	_place_enemy(combat, enemy_shooter_id, enemy_end, 500, "bow")
	_place_enemy(combat, enemy_blocker_id, friendly_middle, 500, "sword_shield")
	await physics_frame
	var npc_hp_before := int(npc_system.get_npc_state(SHOOTER_NPC_ID).get("hp", 0))
	var enemy_release := _release_enemy(combat, enemy_shooter_id, SHOOTER_NPC_ID, friendly_origin)
	_check(str(enemy_release.get("projectile_status", "")) == "in_flight", "T0248 enemy arrow was not released")
	_advance_until_resolved(combat)
	var enemy_hit: Dictionary = combat.debug_get_combat_snapshot().get("last_projectile_result", {})
	_check(str(enemy_hit.get("status", "")) == "hit", "T0248 enemy arrow did not hit NPC after passing ally: %s" % JSON.stringify(enemy_hit))
	_check(str((enemy_hit.get("resolution", {}) as Dictionary).get("actual_target_id", "")) == SHOOTER_NPC_ID, "T0248 enemy arrow did not resolve against NPC")
	_check(int(npc_system.get_npc_state(SHOOTER_NPC_ID).get("hp", 0)) < npc_hp_before, "T0248 enemy arrow applied no NPC damage")
	_check((enemy_hit.get("same_side_skipped_ids", PackedStringArray()) as PackedStringArray).has(enemy_blocker_id), "T0248 enemy blocker identity was not skipped")
	var npc_stuck: Dictionary = enemy_hit.get("stuck_projectile", {}) if enemy_hit.get("stuck_projectile", {}) is Dictionary else {}
	_check(str(npc_stuck.get("anchor_kind", "")) == "npc", "T0248 enemy arrow was not attached to NPC")
	var npc_arrow_id := str(npc_stuck.get("id", ""))
	var npc_arrow_before: Vector3 = npc_stuck.get("world_position", Vector3.ZERO)
	var npc_shift := Vector3(-1.5, 0.0, 0.0)
	_place_npc(shooter_actor, shooter_actor.global_position + npc_shift)
	await physics_frame
	var npc_arrow_after := _find_stuck(combat, npc_arrow_id)
	_check(not npc_arrow_after.is_empty(), "T0248 NPC-attached arrow disappeared during combat")
	_check((npc_arrow_after.get("world_position", Vector3.ZERO) as Vector3).distance_to(npc_arrow_before + npc_shift) < 0.3, "T0248 arrow did not follow NPC")

	# A dodged shot still ends as a physical arrow at the real world/endpoint;
	# it never bends toward or applies compatibility damage to the moved target.
	_place_npc(shooter_actor, friendly_origin)
	_place_enemy(combat, enemy_shooter_id, NavigationServer3D.map_get_closest_point(navigation_map, Vector3(13.0, 0.0, 44.0)), 500, "bow")
	_place_enemy(combat, enemy_blocker_id, NavigationServer3D.map_get_closest_point(navigation_map, Vector3(15.0, 0.0, 46.0)), 500, "sword_shield")
	_place_enemy(combat, corpse_target_id, NavigationServer3D.map_get_closest_point(navigation_map, Vector3(17.0, 0.0, 48.0)), 500, "sword_shield")
	_place_enemy(combat, friendly_target_id, enemy_end, 500, "sword_shield")
	await physics_frame
	var miss_target_hp := int(combat.get_enemy(friendly_target_id).get("hp", 0))
	var miss_release := _release_friendly(combat, npc_system, friendly_target_id)
	_check(str(miss_release.get("projectile_status", "")) == "in_flight", "T0248 miss fixture did not release")
	_place_enemy(combat, friendly_target_id, enemy_end + Vector3(5.0, 0.0, 0.0), miss_target_hp, "sword_shield")
	await physics_frame
	_advance_until_resolved(combat)
	var miss_result: Dictionary = combat.debug_get_combat_snapshot().get("last_projectile_result", {})
	_check(str(miss_result.get("status", "")) in ["blocked", "miss"], "T0248 dodged arrow has no terminal fact")
	_check(int(combat.get_enemy(friendly_target_id).get("hp", 0)) == miss_target_hp, "T0248 dodged target received compatibility damage")
	_check(not (miss_result.get("stuck_projectile", {}) as Dictionary).is_empty(), "T0248 dodged arrow left no terminal presentation")

	# A lethal arrow is attached to EnemyArtView before damage resolution. The
	# art view is reparented as the corpse, so the arrow survives body removal and
	# is deleted automatically with that corpse rather than becoming orphaned.
	_place_npc(shooter_actor, friendly_origin)
	_place_enemy(combat, friendly_target_id, NavigationServer3D.map_get_closest_point(navigation_map, Vector3(11.0, 0.0, 43.0)), 500, "sword_shield")
	_place_enemy(combat, enemy_shooter_id, NavigationServer3D.map_get_closest_point(navigation_map, Vector3(13.0, 0.0, 45.0)), 500, "bow")
	_place_enemy(combat, enemy_blocker_id, NavigationServer3D.map_get_closest_point(navigation_map, Vector3(15.0, 0.0, 47.0)), 500, "sword_shield")
	_place_enemy(combat, corpse_target_id, enemy_end, 1, "sword_shield")
	await physics_frame
	var corpse_release := _release_friendly(combat, npc_system, corpse_target_id)
	_check(str(corpse_release.get("projectile_status", "")) == "in_flight", "T0248 corpse fixture did not release")
	_advance_until_resolved(combat)
	var corpse_result: Dictionary = combat.debug_get_combat_snapshot().get("last_projectile_result", {})
	var corpse_stuck: Dictionary = corpse_result.get("stuck_projectile", {}) if corpse_result.get("stuck_projectile", {}) is Dictionary else {}
	var corpse_arrow_id := str(corpse_stuck.get("id", ""))
	_check(not combat.get_active_enemy_ids().has(corpse_target_id), "T0248 lethal arrow did not defeat target")
	_check(str(corpse_stuck.get("anchor_kind", "")) == "enemy", "T0248 lethal arrow was not retained on corpse")
	var corpse_arrow_record: Dictionary = combat._stuck_projectiles.get(corpse_arrow_id, {}) if combat._stuck_projectiles.get(corpse_arrow_id, {}) is Dictionary else {}
	var corpse_arrow_view := corpse_arrow_record.get("view") as Node3D
	var corpse_art := corpse_arrow_view.get_parent() if corpse_arrow_view != null else null
	var corpse_arrow_parented := corpse_art != null and str(corpse_art.name).ends_with("DefeatPresentation")
	_check(corpse_arrow_parented, "T0248 lethal arrow did not follow defeat presentation")
	if corpse_art != null:
		corpse_art.queue_free()
	await process_frame
	await process_frame
	_check(_find_stuck(combat, corpse_arrow_id).is_empty(), "T0248 corpse cleanup left an orphan arrow")

	var retained_before_clear: int = combat.get_stuck_projectile_snapshots().size()
	_check(retained_before_clear >= 2, "T0248 did not retain world/NPC battlefield arrows")
	# The normal all-enemies-cleared transition removes world/NPC arrows, but
	# keeps arrows that became children of an enemy defeat presentation.
	for active_enemy_id in combat.get_active_enemy_ids():
		combat._remove_enemy_from_combat(active_enemy_id)
	var final_mode_exit: Dictionary = combat._handle_all_enemies_cleared("verify_t0248_enemies_cleared")
	var final_cleanup: Dictionary = final_mode_exit.get("projectile_cleanup_result", {}) if final_mode_exit.get("projectile_cleanup_result", {}) is Dictionary else {}
	_check(combat.get_active_enemy_ids().is_empty(), "T0248 enemy clear fixture did not empty combat")
	_check(int(final_cleanup.get("world_and_npc_arrows_cleared", 0)) >= 2, "T0248 natural battle end did not clear battlefield/NPC arrows")
	var after_battle_stuck: Array = combat.get_stuck_projectile_snapshots()
	var only_corpse_arrows_remain := true
	for stuck_after_battle in after_battle_stuck:
		if str(stuck_after_battle.get("anchor_kind", "")) != "enemy":
			only_corpse_arrows_remain = false
	_check(only_corpse_arrows_remain, "T0248 battle end left a non-corpse arrow: %s" % [after_battle_stuck])
	if not after_battle_stuck.is_empty():
		var final_record: Dictionary = combat._stuck_projectiles.get(str(after_battle_stuck[0].get("id", "")), {})
		var final_view := final_record.get("view") as Node3D
		if final_view != null and final_view.get_parent() != null:
			final_view.get_parent().queue_free()
	await process_frame
	await process_frame
	_check(combat.get_active_projectile_snapshots().is_empty(), "T0248 battle cleanup left flying arrows")
	_check(combat.get_stuck_projectile_snapshots().is_empty(), "T0248 battle cleanup left stuck arrows")
	print("T0248_PROJECTILE_STICK_DIAGNOSTICS %s" % JSON.stringify({
		"friendly_same_side_skips": friendly_hit.get("same_side_skip_count", 0),
		"enemy_same_side_skips": enemy_hit.get("same_side_skip_count", 0),
		"retained_before_clear": retained_before_clear,
		"natural_cleanup_count": final_cleanup.get("world_and_npc_arrows_cleared", 0),
		"corpse_arrow_parented": corpse_arrow_parented
	}))
	combat.clear_spawned_enemies()
	_finish()


func _release_friendly(combat: Node, npc_system: Node, enemy_id: String) -> Dictionary:
	var npc: Dictionary = npc_system.get_npc(SHOOTER_NPC_ID)
	var context: Dictionary = combat._calculate_npc_attack_context(SHOOTER_NPC_ID, npc, npc_system.get_npc_state(SHOOTER_NPC_ID))
	var enemy: Dictionary = combat.get_enemy(enemy_id)
	return combat._release_npc_projectile(SHOOTER_NPC_ID, npc, {
		"type": "enemy",
		"id": enemy_id,
		"name": str(enemy.get("name", enemy_id)),
		"position": enemy.get("position", Vector3.ZERO),
		"distance": npc_system.get_npc_world_position(SHOOTER_NPC_ID).distance_to(enemy.get("position", Vector3.ZERO))
	}, context)


func _release_enemy(combat: Node, enemy_id: String, npc_id: String, npc_position: Vector3) -> Dictionary:
	var enemy: Dictionary = combat.get_enemy(enemy_id)
	return combat._apply_enemy_attack(enemy, {
		"type": "npc",
		"id": npc_id,
		"name": npc_id,
		"position": npc_position,
		"distance": enemy.get("position", Vector3.ZERO).distance_to(npc_position)
	})


func _advance_until_resolved(combat: Node) -> void:
	for _step in range(180):
		if combat.get_active_projectile_snapshots().is_empty():
			return
		combat.debug_advance_combat_projectiles(PROJECTILE_STEP_SECONDS)


func _place_npc(actor: Node3D, position: Vector3) -> void:
	actor.stop_movement()
	actor.global_position = position
	actor.velocity = Vector3.ZERO


func _place_enemy(combat: Node, enemy_id: String, position: Vector3, hp: int, weapon_type: String) -> void:
	var enemy: Dictionary = combat.get_enemy(enemy_id)
	if enemy.is_empty():
		return
	enemy["position"] = position
	enemy["hp"] = hp
	enemy["max_hp"] = maxi(hp, int(enemy.get("max_hp", hp)))
	enemy["alive"] = true
	enemy["weapon_type"] = weapon_type
	enemy["target"] = {}
	combat._cancel_enemy_attack_timeline(enemy)
	combat._active_enemies[enemy_id] = enemy
	var actor := _get_enemy_actor(combat, enemy_id)
	if actor != null:
		actor.cancel_motion("t0248_fixture")
		actor.apply_external_displacement(position, "t0248_fixture")
		actor.global_position = position
		actor.velocity = Vector3.ZERO
	combat._refresh_enemy_node(enemy_id)


func _get_npc_actor(npc_system: Node, npc_id: String) -> Node3D:
	return npc_system.get_node_or_null(npc_system._npc_nodes.get(npc_id, NodePath())) as Node3D


func _get_enemy_actor(combat: Node, enemy_id: String) -> Node3D:
	return combat.get_node_or_null(combat._enemy_nodes.get(enemy_id, NodePath())) as Node3D


func _find_stuck(combat: Node, projectile_id: String) -> Dictionary:
	for snapshot in combat.get_stuck_projectile_snapshots():
		if str(snapshot.get("id", "")) == projectile_id:
			return snapshot
	return {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0248_PROJECTILE_FRIENDLY_PASS_THROUGH_AND_STICK_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
