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
	_check(combat_system != null and npc_system != null, "T0145 combat dependencies missing")
	_check(equipment_system != null and resource_system != null and time_system != null, "T0145 equipment/time dependencies missing")
	if not _failures.is_empty():
		_finish()
		return

	time_system.set_paused(true)
	npc_system.set_npc_recruited(NPC_ID, true)
	resource_system.add_resource("item_bow", 3)
	npc_system.set_npc_behavior_mode(NPC_ID, "work", "verify_t0145_equip", {"request_plan_reevaluation": false})
	npc_system.stop_npc_movement_with_state(NPC_ID, {"current_action": "idle", "combat_mounted": false})
	var equip_result: Dictionary = equipment_system.equip_npc_main_weapon(NPC_ID, "bow", "private")
	_check(bool(equip_result.get("ok", false)), "T0145 could not equip bow")
	var npc_actor := root.get_node_or_null("Main/WorldRoot/Station/NPCs/Stableman01") as Node3D
	_check(npc_actor != null, "T0145 formal NPC actor missing")
	if npc_actor == null:
		_finish()
		return
	npc_actor.global_position = Vector3.ZERO

	var spawn_result: Dictionary = combat_system.debug_spawn_wave(1, true)
	_check(bool(spawn_result.get("ok", false)), "T0145 could not spawn target wave")
	var enemy_ids: Array = combat_system.get_active_enemy_ids()
	_check(not enemy_ids.is_empty(), "T0145 target enemy missing")
	if enemy_ids.is_empty():
		_finish()
		return
	var enemy_id := str(enemy_ids[0])
	for index in range(1, enemy_ids.size()):
		combat_system._remove_enemy_from_combat(str(enemy_ids[index]))
	_set_enemy_fixture(combat_system, enemy_id, Vector3(0.0, 0.0, 8.0), 500)
	await physics_frame

	var attack_sequence := 14501
	var release := _release_friendly(combat_system, npc_system, enemy_id, attack_sequence)
	var released_projectile: Dictionary = release.get("projectile", {}) if release.get("projectile", {}) is Dictionary else {}
	var projectile_id := str(released_projectile.get("id", ""))
	var attack_id := str(release.get("attack_id", ""))
	_check(not attack_id.is_empty(), "T0145 release omitted attack_id")
	_check(str(released_projectile.get("attack_id", "")) == attack_id, "T0145 release/projectile attack_id mismatch")
	_check(int(release.get("attack_sequence", 0)) == attack_sequence, "T0145 release lost timeline sequence")
	_check(int(released_projectile.get("attack_sequence", 0)) == attack_sequence, "T0145 projectile lost timeline sequence")
	var active_projectiles: Dictionary = combat_system.get("_active_projectiles")
	var replay_projectile: Dictionary = (active_projectiles.get(projectile_id, {}) as Dictionary).duplicate(true)
	var hp_before := int(combat_system.get_enemy(enemy_id).get("hp", 0))
	_advance_until_resolved(combat_system)
	var hit_result: Dictionary = combat_system.debug_get_combat_snapshot().get("last_projectile_result", {})
	_check(str(hit_result.get("status", "")) == "hit", "T0145 physical arrow did not hit")
	_check(str(hit_result.get("attack_id", "")) == attack_id, "T0145 terminal result changed attack_id")
	var resolution: Dictionary = hit_result.get("resolution", {}) if hit_result.get("resolution", {}) is Dictionary else {}
	var hit_fact: Dictionary = hit_result.get("hit_fact", {}) if hit_result.get("hit_fact", {}) is Dictionary else {}
	var attack_result: Dictionary = resolution.get("damage_result", {}) if resolution.get("damage_result", {}) is Dictionary else {}
	var damage_result: Dictionary = attack_result.get("damage_result", {}) if attack_result.get("damage_result", {}) is Dictionary else {}
	_check(str(resolution.get("attack_id", "")) == attack_id, "T0145 resolution lost attack_id")
	_check(str(hit_fact.get("attack_id", "")) == attack_id and str(hit_fact.get("status", "")) == "hit", "T0145 hit fact is not traceable")
	_check(str(attack_result.get("attack_id", "")) == attack_id, "T0145 attack result lost attack_id")
	_check(str(damage_result.get("attack_id", "")) == attack_id, "T0145 damage result lost attack_id")
	_check(int(combat_system.get_enemy(enemy_id).get("hp", 0)) < hp_before, "T0145 hit fact did not commit damage")

	# Re-submit the same authoritative attack against the same real collider. The
	# reservation ledger must reject it even though the source dictionary and
	# collider are still available to the caller.
	var enemy_paths: Dictionary = combat_system.get("_enemy_nodes")
	var enemy_node := combat_system.get_node_or_null(enemy_paths.get(enemy_id, NodePath())) as Node3D if enemy_paths.has(enemy_id) else null
	_check(enemy_node != null, "T0145 replay collider missing")
	if enemy_node != null:
		var hp_after_first_hit := int(combat_system.get_enemy(enemy_id).get("hp", 0))
		var duplicate: Dictionary = combat_system._resolve_combat_projectile_collision(
			replay_projectile,
			{
				"collider": enemy_node,
				"position": enemy_node.global_position + Vector3.UP * 0.9,
				"normal": Vector3.BACK
			}
		)
		_check(bool(duplicate.get("duplicate_ignored", false)), "T0145 duplicate attack_id was not rejected")
		_check(str(duplicate.get("attack_id", "")) == attack_id, "T0145 duplicate response lost attack_id")
		_check(int(combat_system.get_enemy(enemy_id).get("hp", 0)) == hp_after_first_hit, "T0145 duplicate collision applied damage twice")

	# Reusing a timeline sequence for a later projectile is still safe because
	# the projectile authority contributes a monotonic suffix to attack_id.
	_set_enemy_fixture(combat_system, enemy_id, Vector3(0.0, 0.0, 8.0), 500)
	await physics_frame
	var second_release := _release_friendly(combat_system, npc_system, enemy_id, attack_sequence)
	var second_attack_id := str(second_release.get("attack_id", ""))
	_check(not second_attack_id.is_empty() and second_attack_id != attack_id, "T0145 attack_id was not globally unique")
	_set_enemy_fixture(combat_system, enemy_id, Vector3(5.0, 0.0, 8.0), 500)
	await physics_frame
	_advance_until_resolved(combat_system)
	var miss_result: Dictionary = combat_system.debug_get_combat_snapshot().get("last_projectile_result", {})
	var miss_fact: Dictionary = miss_result.get("hit_fact", {}) if miss_result.get("hit_fact", {}) is Dictionary else {}
	_check(str(miss_result.get("status", "")) in ["blocked", "miss"], "T0145 moved target did not produce a terminal miss fact")
	_check(str(miss_fact.get("attack_id", "")) == second_attack_id, "T0145 miss fact lost attack_id")
	_check(not bool(miss_fact.get("damage_applied", true)), "T0145 miss fact claims damage")

	combat_system.debug_clear_enemies()
	await process_frame
	_check(combat_system.get_active_projectile_snapshots().is_empty(), "T0145 cleanup left active projectiles")
	_check((combat_system.get("_resolved_projectile_attack_facts") as Dictionary).is_empty(), "T0145 cleanup left resolved attack facts")
	_finish()


func _release_friendly(combat_system: Node, npc_system: Node, enemy_id: String, attack_sequence: int) -> Dictionary:
	var npc: Dictionary = npc_system.get_npc(NPC_ID)
	var context: Dictionary = combat_system._calculate_npc_attack_context(NPC_ID, npc, npc_system.get_npc_state(NPC_ID))
	context["attack_sequence"] = attack_sequence
	var enemy: Dictionary = combat_system.get_enemy(enemy_id)
	var target := {
		"type": "enemy",
		"id": enemy_id,
		"name": str(enemy.get("name", enemy_id)),
		"position": enemy.get("position", Vector3.ZERO),
		"distance": npc_system.get_npc_world_position(NPC_ID).distance_to(enemy.get("position", Vector3.ZERO))
	}
	npc_system.update_npc_state(NPC_ID, {
		"behavior_mode": "combat",
		"combat_mode": "combat",
		"combat_projectile_authority": "combat_system"
	})
	return combat_system._release_npc_projectile(NPC_ID, npc, target, context)


func _advance_until_resolved(combat_system: Node) -> void:
	for _step in range(100):
		if combat_system.get_active_projectile_snapshots().is_empty():
			return
		combat_system.debug_advance_combat_projectiles(PROJECTILE_STEP_SECONDS)


func _set_enemy_fixture(combat_system: Node, enemy_id: String, position: Vector3, hp: int) -> void:
	var enemy: Dictionary = combat_system.get_enemy(enemy_id)
	enemy["position"] = position
	enemy["hp"] = hp
	enemy["max_hp"] = hp
	enemy["alive"] = true
	enemy["target"] = {}
	combat_system._cancel_enemy_attack_timeline(enemy)
	var active_enemies: Dictionary = combat_system.get("_active_enemies")
	active_enemies[enemy_id] = enemy
	combat_system.set("_active_enemies", active_enemies)
	var node_paths: Dictionary = combat_system.get("_enemy_nodes")
	var enemy_node := combat_system.get_node_or_null(node_paths.get(enemy_id, NodePath())) as Node3D if node_paths.has(enemy_id) else null
	if enemy_node != null:
		enemy_node.global_position = position
	combat_system._refresh_enemy_node(enemy_id)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0145_PROJECTILE_ATTACK_ID PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("T0145_PROJECTILE_ATTACK_ID FAIL count=%d" % _failures.size())
	quit(1)
