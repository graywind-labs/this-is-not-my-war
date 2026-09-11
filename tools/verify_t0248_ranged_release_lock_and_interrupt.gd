extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const NPC_ID := "stableman_01"

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
	_check(not [combat, npc_system, equipment, resources, time_system, controller].has(null), "T0248 release-lock dependencies missing")
	if not _failures.is_empty():
		_finish()
		return

	resources.add_resource("item_bow", 1)
	npc_system.set_npc_recruited(NPC_ID, true)
	npc_system.set_npc_behavior_mode(NPC_ID, "work", "verify_t0248_release_equip", {"request_plan_reevaluation": false})
	npc_system.stop_npc_movement_with_state(NPC_ID, {"current_action": "idle", "combat_mounted": false})
	var equipped: Dictionary = equipment.equip_npc_main_weapon(NPC_ID, "bow", "private")
	_check(bool(equipped.get("ok", false)), "T0248 release-lock bow equip failed")
	combat.set_npc_combat_strategy(NPC_ID, "attack", "private")
	var spawned: Dictionary = combat.debug_run_formal_dynamic_wave_slice(1, true)
	_check(bool(spawned.get("ok", false)), "T0248 release-lock wave spawn failed")
	var enemy_ids: Array[String] = combat.get_active_enemy_ids()
	_check(not enemy_ids.is_empty(), "T0248 release-lock enemy missing")
	if not _failures.is_empty():
		_finish()
		return
	var enemy_id := enemy_ids[0]
	for index in range(1, enemy_ids.size()):
		combat._remove_enemy_from_combat(enemy_ids[index])

	var navigation_map: RID = controller.get_production_navigation_map_rid()
	var npc_position := NavigationServer3D.map_get_closest_point(navigation_map, Vector3(-3.0, 0.0, 22.0))
	var enemy_position := NavigationServer3D.map_get_closest_point(navigation_map, Vector3(-3.0, 0.0, 30.0))
	var npc_actor := npc_system.get_node_or_null(npc_system._npc_nodes.get(NPC_ID, NodePath())) as Node3D
	var enemy_actor := combat.get_node_or_null(combat._enemy_nodes.get(enemy_id, NodePath())) as Node3D
	_check(npc_actor != null and enemy_actor != null, "T0248 release-lock actors missing")
	if not _failures.is_empty():
		_finish()
		return
	_place_npc(npc_actor, npc_position)
	_place_enemy(combat, enemy_id, enemy_position, "bow")
	npc_system.set_npc_behavior_mode(NPC_ID, "combat", "verify_t0248_release", {
		"state_changes": _friendly_idle_attack_state(enemy_id),
		"request_plan_reevaluation": false
	})
	await physics_frame
	time_system.set_paused(true)

	# Friendly ranged windup owns its actor target through release. Moving the
	# target out of range does not erase a successfully completed animation.
	combat._advance_single_npc_combat_attack(NPC_ID, 0.02)
	var friendly_windup: Dictionary = npc_system.get_npc_state(NPC_ID)
	_check(str(friendly_windup.get("combat_attack_phase", "")) == "windup", "T0248 friendly bow did not enter windup")
	var friendly_target_id := str(friendly_windup.get("combat_attack_target_enemy_id", ""))
	var far_enemy_position := NavigationServer3D.map_get_closest_point(navigation_map, Vector3(24.0, 0.0, 58.0))
	_place_enemy(combat, enemy_id, far_enemy_position, "bow")
	var friendly_release_step := maxf(
		0.01,
		float(friendly_windup.get("combat_attack_impact_seconds", 0.0))
		- float(friendly_windup.get("combat_attack_elapsed_seconds", 0.0))
		+ 0.02
	)
	combat._advance_single_npc_combat_attack(NPC_ID, friendly_release_step)
	var friendly_projectiles: Array = combat.get_active_projectile_snapshots()
	_check(friendly_projectiles.size() == 1, "T0248 friendly completed windup did not release after target moved")
	if not friendly_projectiles.is_empty():
		_check(str((friendly_projectiles[0].get("target_at_release", {}) as Dictionary).get("id", "")) == friendly_target_id, "T0248 friendly release changed its cycle target")
	var friendly_post_release_interrupt: Dictionary = combat._interrupt_npc_attack_from_damage(NPC_ID, 1, {"source_id": enemy_id})
	_check(not friendly_post_release_interrupt.is_empty(), "T0248 friendly recovery was not interruptible")
	_check(combat.get_active_projectile_snapshots().size() == 1, "T0248 post-release friendly interruption deleted flying arrow")
	combat._clear_active_combat_projectiles("verify_t0248_friendly_release_complete")

	# Damage before authored release cancels the ranged action and creates no
	# projectile, using the same interruption contract as melee windup.
	_place_enemy(combat, enemy_id, enemy_position, "bow")
	npc_system.update_npc_state(NPC_ID, _friendly_idle_attack_state(enemy_id))
	combat._advance_single_npc_combat_attack(NPC_ID, 0.02)
	var friendly_pre_release: Dictionary = npc_system.get_npc_state(NPC_ID)
	_check(str(friendly_pre_release.get("combat_attack_phase", "")) == "windup", "T0248 friendly interrupt fixture did not enter windup")
	var friendly_interrupt: Dictionary = combat._interrupt_npc_attack_from_damage(NPC_ID, 1, {"source_id": enemy_id})
	_check(bool(friendly_interrupt.get("interrupted_before_impact", false)), "T0248 friendly pre-release damage was not marked interrupted")
	_check(str(npc_system.get_npc_state(NPC_ID).get("combat_attack_phase", "")) == "idle", "T0248 friendly pre-release interruption did not cancel action")
	_check(combat.get_active_projectile_snapshots().is_empty(), "T0248 friendly pre-release interruption spawned an arrow")

	# Enemy ranged actions use the same locked release and interruption rules.
	_place_npc(npc_actor, npc_position)
	_place_enemy(combat, enemy_id, enemy_position, "bow")
	var enemy: Dictionary = combat.get_enemy(enemy_id)
	combat._cancel_enemy_attack_timeline(enemy)
	combat._advance_enemy_attack(enemy, _npc_target(npc_position), 0.02)
	_check(str(enemy.get("attack_cycle_phase", "")) == "windup", "T0248 enemy bow did not enter windup")
	var enemy_cycle_target_id := str((enemy.get("attack_cycle_target", {}) as Dictionary).get("id", ""))
	var far_npc_position := NavigationServer3D.map_get_closest_point(navigation_map, Vector3(20.0, 0.0, 54.0))
	_place_npc(npc_actor, far_npc_position)
	var enemy_release_step := maxf(
		0.01,
		float(enemy.get("attack_impact_seconds", 0.0))
		- float(enemy.get("attack_cycle_elapsed", 0.0))
		+ 0.02
	)
	combat._advance_enemy_attack(enemy, _npc_target(far_npc_position), enemy_release_step)
	var enemy_projectiles: Array = combat.get_active_projectile_snapshots()
	_check(enemy_projectiles.size() == 1, "T0248 enemy completed windup did not release after NPC moved")
	if not enemy_projectiles.is_empty():
		_check(str((enemy_projectiles[0].get("target_at_release", {}) as Dictionary).get("id", "")) == enemy_cycle_target_id, "T0248 enemy release changed its cycle target")
	var enemy_post_release_interrupt: Dictionary = combat._interrupt_enemy_attack_from_damage(enemy, 1, {"source_id": NPC_ID})
	_check(not enemy_post_release_interrupt.is_empty(), "T0248 enemy recovery was not interruptible")
	_check(combat.get_active_projectile_snapshots().size() == 1, "T0248 post-release enemy interruption deleted flying arrow")
	combat._clear_active_combat_projectiles("verify_t0248_enemy_release_complete")

	_place_npc(npc_actor, npc_position)
	_place_enemy(combat, enemy_id, enemy_position, "bow")
	enemy = combat.get_enemy(enemy_id)
	combat._cancel_enemy_attack_timeline(enemy)
	combat._advance_enemy_attack(enemy, _npc_target(npc_position), 0.02)
	var enemy_interrupt: Dictionary = combat._interrupt_enemy_attack_from_damage(enemy, 1, {"source_id": NPC_ID})
	_check(bool(enemy_interrupt.get("interrupted_before_impact", false)), "T0248 enemy pre-release damage was not marked interrupted")
	_check(str(enemy.get("attack_cycle_phase", "")) == "idle", "T0248 enemy pre-release interruption did not cancel action")
	_check(combat.get_active_projectile_snapshots().is_empty(), "T0248 enemy pre-release interruption spawned an arrow")

	print("T0248_RANGED_RELEASE_LOCK_DIAGNOSTICS %s" % JSON.stringify({
		"friendly_cycle_target": friendly_target_id,
		"enemy_cycle_target": enemy_cycle_target_id,
		"friendly_pre_release_interrupted": friendly_interrupt.get("interrupted_before_impact", false),
		"enemy_pre_release_interrupted": enemy_interrupt.get("interrupted_before_impact", false)
	}))
	combat.clear_spawned_enemies()
	_finish()


func _friendly_idle_attack_state(enemy_id: String) -> Dictionary:
	return {
		"hp": 10000,
		"max_hp": 10000,
		"unconscious": false,
		"escaped": false,
		"combat_mounted": false,
		"combat_target_enemy_id": enemy_id,
		"combat_attack_phase": "idle",
		"combat_attack_elapsed_seconds": 0.0,
		"combat_attack_cycle_seconds": 0.0,
		"combat_attack_impact_seconds": 0.0,
		"combat_attack_target_enemy_id": "",
		"combat_attack_impact_committed": false,
		"combat_attack_sequence": 0,
		"combat_attack_last_sequence_time": -1.0,
		"combat_attack_next_sequence_time": 0.0,
		"combat_attack_sequence_lock_remaining": 0.0,
		"current_action": "combat_ready"
	}


func _npc_target(position: Vector3) -> Dictionary:
	return {"type": "npc", "id": NPC_ID, "name": NPC_ID, "position": position, "distance": 8.0}


func _place_npc(actor: Node3D, position: Vector3) -> void:
	actor.stop_movement()
	actor.global_position = position
	actor.velocity = Vector3.ZERO


func _place_enemy(combat: Node, enemy_id: String, position: Vector3, weapon_type: String) -> void:
	var enemy: Dictionary = combat.get_enemy(enemy_id)
	enemy["position"] = position
	enemy["hp"] = 10000
	enemy["max_hp"] = 10000
	enemy["alive"] = true
	enemy["weapon_type"] = weapon_type
	enemy["target"] = {}
	combat._cancel_enemy_attack_timeline(enemy)
	combat._active_enemies[enemy_id] = enemy
	var actor := combat.get_node_or_null(combat._enemy_nodes.get(enemy_id, NodePath())) as Node3D
	if actor != null:
		actor.cancel_motion("t0248_release_fixture")
		actor.global_position = position
		actor.velocity = Vector3.ZERO
	combat._refresh_enemy_node(enemy_id)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0248_RANGED_RELEASE_LOCK_AND_INTERRUPT_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
