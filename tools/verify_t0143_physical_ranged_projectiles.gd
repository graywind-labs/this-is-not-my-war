extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const NPC_ID := "stableman_01"
const PROJECTILE_STEP_SECONDS := 0.05

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	await process_frame
	await physics_frame
	await physics_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var station_layout := root.get_node_or_null("Main/Presentation/StationLayoutController")
	_check(combat_system != null, "CombatSystem missing")
	_check(npc_system != null, "NPCSystem missing")
	_check(equipment_system != null, "EquipmentSystem missing")
	_check(resource_system != null, "ResourceSystem missing")
	_check(time_system != null, "TimeSystem missing")
	_check(station_layout != null, "StationLayoutController missing")
	if not _failures.is_empty():
		_finish()
		return

	time_system.set_paused(true)
	npc_system.set_npc_recruited(NPC_ID, true)
	resource_system.add_resource("item_bow", 4)
	resource_system.add_resource("item_crossbow", 4)
	var npc_actor := root.get_node_or_null("Main/WorldRoot/Station/NPCs/Stableman01") as Node3D
	_check(npc_actor != null, "Stableman actor missing")
	if npc_actor == null:
		_finish()
		return
	var navigation_map: RID = station_layout.get_production_navigation_map_rid()
	var fixture_origin := NavigationServer3D.map_get_closest_point(navigation_map, Vector3(-3.0, 0.0, 22.0))
	npc_actor.global_position = fixture_origin
	var spawn_result: Dictionary = combat_system.debug_spawn_wave(1, true)
	_check(bool(spawn_result.get("ok", false)), "Could not spawn projectile target wave")
	var enemy_ids: Array = combat_system.get_active_enemy_ids()
	_check(enemy_ids.size() >= 2, "Projectile verification needs two enemies")
	if enemy_ids.size() < 2:
		_finish()
		return
	var target_id := str(enemy_ids[0])
	var crossing_id := str(enemy_ids[1])
	for index in range(2, enemy_ids.size()):
		combat_system._remove_enemy_from_combat(str(enemy_ids[index]))

	# A released arrow stores the current aim point, does not deal release-time
	# damage, and can hit a different enemy that actually crosses its path.
	_check(_equip_weapon(npc_system, equipment_system, "bow"), "Could not equip bow")
	_set_enemy_fixture(combat_system, target_id, fixture_origin + Vector3(0.0, 0.0, 8.0), 500)
	_set_enemy_fixture(combat_system, crossing_id, fixture_origin + Vector3(0.0, 0.0, 4.0), 500)
	await physics_frame
	var target_before := int(combat_system.get_enemy(target_id).get("hp", 0))
	var crossing_before := int(combat_system.get_enemy(crossing_id).get("hp", 0))
	var bow_release := _release_friendly(combat_system, npc_system, target_id)
	_check(str(bow_release.get("projectile_status", "")) == "in_flight", "Bow release did not create a formal projectile")
	_check(int(combat_system.get_enemy(target_id).get("hp", 0)) == target_before, "Bow damaged its target at release")
	_check(int(combat_system.get_enemy(crossing_id).get("hp", 0)) == crossing_before, "Bow damaged the crossing enemy at release")
	_check(combat_system.get_active_projectile_snapshots().size() == 1, "Bow release did not expose exactly one active projectile")
	_advance_until_resolved(combat_system)
	var actual_hit := combat_system.debug_get_combat_snapshot().get("last_projectile_result", {}) as Dictionary
	_check(str(actual_hit.get("status", "")) == "hit", "Bow did not report a physical hit: %s" % JSON.stringify(actual_hit))
	_check(str((actual_hit.get("resolution", {}) as Dictionary).get("actual_target_id", "")) == crossing_id, "Bow damaged the locked target instead of the actual crossing enemy")
	_check(int(combat_system.get_enemy(target_id).get("hp", 0)) == target_before, "Locked target lost HP without being physically hit")
	_check(int(combat_system.get_enemy(crossing_id).get("hp", 0)) < crossing_before, "Actual crossing enemy did not receive collision damage")

	# Moving the target after release must not bend the trajectory or apply a
	# late compatibility hit.
	_set_enemy_fixture(combat_system, target_id, fixture_origin + Vector3(0.0, 0.0, 8.0), 500)
	_set_enemy_fixture(combat_system, crossing_id, fixture_origin + Vector3(6.0, 0.0, 4.0), 500)
	await physics_frame
	var dodge_hp_before := int(combat_system.get_enemy(target_id).get("hp", 0))
	var dodge_release := _release_friendly(combat_system, npc_system, target_id)
	var released_aim: Vector3 = (dodge_release.get("projectile", {}) as Dictionary).get("aim_position_at_release", Vector3.ZERO)
	_set_enemy_fixture(combat_system, target_id, fixture_origin + Vector3(5.0, 0.0, 8.0), 500)
	await physics_frame
	_advance_until_resolved(combat_system)
	var dodge_result := combat_system.debug_get_combat_snapshot().get("last_projectile_result", {}) as Dictionary
	_check(str(dodge_result.get("status", "")) in ["blocked", "miss"], "Moved target did not evade the released arrow")
	_check(int(combat_system.get_enemy(target_id).get("hp", 0)) == dodge_hp_before, "Moved target received compatibility damage after evading")
	_check((released_aim as Vector3).distance_to(fixture_origin + Vector3(0.0, 0.9, 8.0)) < 0.25, "Release aim did not capture the target's current position")
	_check(bool(dodge_result.get("tracks_target_after_release", true)) == false, "Projectile snapshot claims post-release tracking")

	# Crossbow uses the same collision authority and an enemy ranged projectile
	# only damages the NPC once the capsule is physically reached.
	_check(_equip_weapon(npc_system, equipment_system, "crossbow"), "Could not equip crossbow")
	_set_enemy_fixture(combat_system, target_id, fixture_origin + Vector3(0.0, 0.0, 8.0), 500)
	await physics_frame
	var crossbow_hp_before := int(combat_system.get_enemy(target_id).get("hp", 0))
	var crossbow_release := _release_friendly(combat_system, npc_system, target_id)
	_check(str(crossbow_release.get("weapon_id", "")) == "crossbow", "Crossbow release used the wrong projectile kind")
	_check(int(combat_system.get_enemy(target_id).get("hp", 0)) == crossbow_hp_before, "Crossbow damaged at release")
	_advance_until_resolved(combat_system)
	_check(int(combat_system.get_enemy(target_id).get("hp", 0)) < crossbow_hp_before, "Crossbow physical collision did not damage the enemy")

	var enemy: Dictionary = combat_system.get_enemy(target_id)
	enemy["weapon_type"] = "bow"
	enemy["attack_power"] = 4
	enemy["penetration"] = 1.0
	_set_active_enemy(combat_system, target_id, enemy)
	_set_enemy_fixture(combat_system, target_id, fixture_origin + Vector3(0.0, 0.0, 7.0), 500)
	npc_system.update_npc_state(NPC_ID, {"hp": 100, "max_hp": 100, "unconscious": false})
	await physics_frame
	var npc_hp_before := int(npc_system.get_npc_state(NPC_ID).get("hp", 0))
	var enemy_target := {"type": "npc", "id": NPC_ID, "name": "托马", "position": fixture_origin, "distance": 7.0}
	var enemy_release: Dictionary = combat_system._apply_enemy_attack(combat_system.get_enemy(target_id), enemy_target)
	_check(str(enemy_release.get("projectile_status", "")) == "in_flight", "Enemy bow did not create a formal projectile")
	_check(int(npc_system.get_npc_state(NPC_ID).get("hp", 0)) == npc_hp_before, "Enemy bow damaged NPC at release")
	_advance_until_resolved(combat_system)
	_check(int(npc_system.get_npc_state(NPC_ID).get("hp", 0)) < npc_hp_before, "Enemy projectile collision did not damage NPC")

	var art_snapshot: Dictionary = npc_system.debug_get_npc_character_art_snapshot(NPC_ID)
	_check(bool(art_snapshot.get("formal_projectile_authority", false)), "Formal character packaging did not disable its preview projectile authority")
	combat_system.debug_clear_enemies()
	await process_frame
	_finish()


func _release_friendly(combat_system: Node, npc_system: Node, enemy_id: String) -> Dictionary:
	var npc: Dictionary = npc_system.get_npc(NPC_ID)
	var context: Dictionary = combat_system._calculate_npc_attack_context(NPC_ID, npc, npc_system.get_npc_state(NPC_ID))
	var enemy: Dictionary = combat_system.get_enemy(enemy_id)
	var target := {
		"type": "enemy",
		"id": enemy_id,
		"name": str(enemy.get("name", enemy_id)),
		"position": enemy.get("position", Vector3.ZERO),
		"distance": npc_system.get_npc_world_position(NPC_ID).distance_to(enemy.get("position", Vector3.ZERO)),
	}
	npc_system.update_npc_state(NPC_ID, {
		"behavior_mode": "combat",
		"combat_mode": "combat",
		"combat_projectile_authority": "combat_system",
	})
	return combat_system._release_npc_projectile(NPC_ID, npc, target, context)


func _advance_until_resolved(combat_system: Node) -> void:
	for _step in range(100):
		if combat_system.get_active_projectile_snapshots().is_empty():
			return
		combat_system.debug_advance_combat_projectiles(PROJECTILE_STEP_SECONDS)


func _equip_weapon(npc_system: Node, equipment_system: Node, weapon_id: String) -> bool:
	npc_system.set_npc_behavior_mode(NPC_ID, "work", "verify_t0143_equip", {"request_plan_reevaluation": false})
	npc_system.stop_npc_movement_with_state(NPC_ID, {"current_action": "idle", "combat_mounted": false})
	var current: Dictionary = equipment_system.get_unit_type_snapshot(NPC_ID)
	if str(current.get("main_weapon_id", "")) == weapon_id:
		return true
	return bool(equipment_system.equip_npc_main_weapon(NPC_ID, weapon_id, "private").get("ok", false))


func _set_enemy_fixture(combat_system: Node, enemy_id: String, position: Vector3, hp: int) -> void:
	var enemy: Dictionary = combat_system.get_enemy(enemy_id)
	enemy["position"] = position
	enemy["hp"] = hp
	enemy["max_hp"] = hp
	enemy["alive"] = true
	enemy["target"] = {}
	combat_system._cancel_enemy_attack_timeline(enemy)
	_set_active_enemy(combat_system, enemy_id, enemy)
	var node_paths: Dictionary = combat_system.get("_enemy_nodes")
	var enemy_node := combat_system.get_node_or_null(node_paths.get(enemy_id, NodePath())) as Node3D if node_paths.has(enemy_id) else null
	if enemy_node != null:
		enemy_node.global_position = position
	combat_system._refresh_enemy_node(enemy_id)


func _set_active_enemy(combat_system: Node, enemy_id: String, enemy: Dictionary) -> void:
	var active_enemies: Dictionary = combat_system.get("_active_enemies")
	active_enemies[enemy_id] = enemy
	combat_system.set("_active_enemies", active_enemies)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0143_PHYSICAL_RANGED_PROJECTILES PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("T0143_PHYSICAL_RANGED_PROJECTILES FAIL count=%d" % _failures.size())
	quit(1)
