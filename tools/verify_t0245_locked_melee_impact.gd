extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const NPC_ID := "veteran_deputy_01"

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	for _frame in range(5):
		await process_frame
		await physics_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	_check(not [combat_system, npc_system, equipment_system, resource_system, time_system].has(null), "T0245 required systems missing")
	if not _failures.is_empty():
		_finish()
		return
	time_system.set_paused(true)
	resource_system.add_resource("item_sword_shield", 1)
	npc_system.set_npc_recruited(NPC_ID, true)
	_check(bool(equipment_system.equip_npc_main_weapon(NPC_ID, "sword_shield", "private").get("ok", false)), "T0245 failed to equip friendly sword")
	combat_system.set_npc_combat_strategy(NPC_ID, "attack", "private")
	var spawned: Dictionary = combat_system.debug_run_formal_dynamic_wave_slice(1, true)
	_check(bool(spawned.get("ok", false)), "T0245 failed to spawn combat fixture: %s" % spawned)
	var enemy_ids: Array[String] = combat_system.get_active_enemy_ids()
	_check(not enemy_ids.is_empty(), "T0245 combat fixture has no enemy")
	if not _failures.is_empty():
		_finish()
		return
	var enemy_id := enemy_ids[0]
	for index in range(1, enemy_ids.size()):
		combat_system._remove_enemy_from_combat(enemy_ids[index])

	_set_npc_position(npc_system, NPC_ID, Vector3(0.0, 0.0, -20.0))
	_set_enemy_position(combat_system, enemy_id, Vector3(1.0, 0.0, -20.0))
	npc_system.set_npc_behavior_mode(NPC_ID, "combat", "verify_t0245", {
		"state_changes": {
			"hp": 10000,
			"max_hp": 10000,
			"unconscious": false,
			"escaped": false,
			"combat_mounted": false,
			"combat_target_enemy_id": enemy_id,
			"current_action": "combat_ready"
		},
		"request_plan_reevaluation": false
	})
	var enemy: Dictionary = combat_system._active_enemies.get(enemy_id, {})
	enemy["hp"] = 10000
	enemy["max_hp"] = 10000
	enemy["alive"] = true
	enemy["weapon_type"] = "polearm"
	enemy["attack_power"] = 12.0
	combat_system._cancel_enemy_attack_timeline(enemy)
	combat_system._active_enemies[enemy_id] = enemy

	_verify_friendly_target_travel_hit(combat_system, npc_system, enemy_id)
	_verify_friendly_damage_interrupts(combat_system, npc_system, enemy_id)
	_verify_enemy_target_travel_hit(combat_system, npc_system, enemy_id)
	_verify_enemy_damage_interrupts(combat_system, npc_system, enemy_id)

	combat_system.clear_spawned_enemies()
	_finish()


func _verify_friendly_target_travel_hit(combat_system: Node, npc_system: Node, enemy_id: String) -> void:
	_prepare_friendly_windup(combat_system, npc_system, enemy_id, 0.10, 0.50, 1.00, 101)
	var hp_before := int(combat_system.get_enemy(enemy_id).get("hp", 0))
	_set_enemy_position(combat_system, enemy_id, Vector3(12.0, 0.0, -20.0))
	var result: Dictionary = combat_system._advance_single_npc_combat_attack(NPC_ID, 0.45)
	var hp_after := int(combat_system.get_enemy(enemy_id).get("hp", hp_before))
	var state: Dictionary = npc_system.get_npc_state(NPC_ID)
	_check(hp_after < hp_before, "T0245 friendly melee missed after target left range: %s" % result)
	_check(str(state.get("combat_attack_phase", "")) == "recovery", "T0245 friendly action did not enter recovery after locked impact: %s" % state)
	_check(bool(state.get("combat_attack_impact_committed", false)), "T0245 friendly locked impact was not committed")
	var attacks: Array = result.get("attacks", [])
	_check(attacks.size() == 1 and str((attacks[0] as Dictionary).get("melee_status", "")) == "hit", "T0245 friendly impact did not report one hit: %s" % result)
	_check(str(((attacks[0] as Dictionary).get("melee_contact", {}) as Dictionary).get("impact_authority", "")) == "locked_actor_timeline", "T0245 friendly impact used the wrong authority: %s" % result)


func _verify_friendly_damage_interrupts(combat_system: Node, npc_system: Node, enemy_id: String) -> void:
	_set_enemy_position(combat_system, enemy_id, Vector3(1.0, 0.0, -20.0))
	_prepare_friendly_windup(combat_system, npc_system, enemy_id, 0.10, 0.50, 1.00, 102)
	var target_hp_before := int(combat_system.get_enemy(enemy_id).get("hp", 0))
	var attacking_enemy: Dictionary = combat_system._active_enemies.get(enemy_id, {})
	var damage_result: Dictionary = combat_system._apply_enemy_attack_to_npc(
		attacking_enemy,
		NPC_ID,
		1,
		1.0,
		0.0,
		0.0,
		0.0
	)
	_check(not damage_result.is_empty(), "T0245 enemy damage fixture did not enter the authoritative NPC damage path")
	var state: Dictionary = npc_system.get_npc_state(NPC_ID)
	_check(str(state.get("combat_attack_phase", "")) == "idle", "T0245 pre-impact friendly damage did not interrupt windup: %s" % state)
	_check(bool((state.get("combat_last_damage_attack_interrupt", {}) as Dictionary).get("interrupted_before_impact", false)), "T0245 friendly pre-impact interrupt classification missing: %s" % state)
	_set_enemy_position(combat_system, enemy_id, Vector3(12.0, 0.0, -20.0))
	combat_system._advance_single_npc_combat_attack(NPC_ID, 0.45)
	_check(int(combat_system.get_enemy(enemy_id).get("hp", 0)) == target_hp_before, "T0245 interrupted friendly windup still dealt damage")

	_set_enemy_position(combat_system, enemy_id, Vector3(1.0, 0.0, -20.0))
	_prepare_friendly_windup(combat_system, npc_system, enemy_id, 0.10, 0.50, 1.00, 103)
	var hp_before_impact := int(combat_system.get_enemy(enemy_id).get("hp", 0))
	combat_system._advance_single_npc_combat_attack(NPC_ID, 0.45)
	var hp_after_impact := int(combat_system.get_enemy(enemy_id).get("hp", hp_before_impact))
	_check(hp_after_impact < hp_before_impact, "T0245 friendly post-impact fixture did not deal damage")
	combat_system._interrupt_npc_attack_from_damage(NPC_ID, 1, {"source_id": enemy_id})
	state = npc_system.get_npc_state(NPC_ID)
	_check(str(state.get("combat_attack_phase", "")) == "idle", "T0245 friendly recovery was not interruptible")
	_check(not bool((state.get("combat_last_damage_attack_interrupt", {}) as Dictionary).get("interrupted_before_impact", true)), "T0245 friendly post-impact interrupt was classified as pre-impact")
	_check(int(combat_system.get_enemy(enemy_id).get("hp", 0)) == hp_after_impact, "T0245 friendly post-impact damage was rolled back")


func _verify_enemy_target_travel_hit(combat_system: Node, npc_system: Node, enemy_id: String) -> void:
	_set_npc_position(npc_system, NPC_ID, Vector3(0.0, 0.0, -20.0))
	_set_enemy_position(combat_system, enemy_id, Vector3(1.0, 0.0, -20.0))
	_prepare_enemy_windup(combat_system, enemy_id, 0.10, 0.50, 1.00, 201)
	var hp_before := int(npc_system.get_npc_state(NPC_ID).get("hp", 0))
	_set_npc_position(npc_system, NPC_ID, Vector3(-12.0, 0.0, -20.0))
	var enemy_ids: Array[String] = [enemy_id]
	var result: Dictionary = combat_system._advance_enemy_ai(0.45, 0.45, enemy_ids)
	var enemy: Dictionary = combat_system._active_enemies.get(enemy_id, {})
	var hp_after := int(npc_system.get_npc_state(NPC_ID).get("hp", hp_before))
	_check(hp_after < hp_before, "T0245 enemy melee missed after target left range: %s" % result)
	_check(str(enemy.get("attack_cycle_phase", "")) == "recovery" and bool(enemy.get("attack_impact_committed", false)), "T0245 enemy locked impact did not enter committed recovery: %s" % enemy)
	var attack_steps: Array = result.get("attacks", [])
	var impacts: Array = (attack_steps[0] as Dictionary).get("attacks", []) if not attack_steps.is_empty() else []
	_check(impacts.size() == 1 and str(((impacts[0] as Dictionary).get("melee_contact", {}) as Dictionary).get("impact_authority", "")) == "locked_actor_timeline", "T0245 enemy impact used the wrong authority: %s" % result)


func _verify_enemy_damage_interrupts(combat_system: Node, npc_system: Node, enemy_id: String) -> void:
	_set_npc_position(npc_system, NPC_ID, Vector3(0.0, 0.0, -20.0))
	_set_enemy_position(combat_system, enemy_id, Vector3(1.0, 0.0, -20.0))
	_prepare_enemy_windup(combat_system, enemy_id, 0.10, 0.50, 1.00, 202)
	var npc_hp_before := int(npc_system.get_npc_state(NPC_ID).get("hp", 0))
	var damage_result: Dictionary = combat_system._apply_damage_to_enemy(enemy_id, 1, NPC_ID, {"source_type": "npc"})
	var interrupt: Dictionary = damage_result.get("attack_interrupt", {})
	var enemy: Dictionary = combat_system._active_enemies.get(enemy_id, {})
	_check(str(enemy.get("attack_cycle_phase", "")) == "idle", "T0245 pre-impact enemy damage did not interrupt windup: %s" % enemy)
	_check(bool(interrupt.get("interrupted_before_impact", false)), "T0245 enemy pre-impact interrupt classification missing: %s" % damage_result)
	var target: Dictionary = combat_system._make_npc_enemy_target(NPC_ID, enemy.get("position", Vector3.ZERO))
	combat_system._advance_enemy_attack(enemy, target, 0.45, combat_system._combat_timeline_seconds + 0.45)
	_check(int(npc_system.get_npc_state(NPC_ID).get("hp", 0)) == npc_hp_before, "T0245 interrupted enemy windup still dealt damage")

	_prepare_enemy_windup(combat_system, enemy_id, 0.10, 0.50, 1.00, 203)
	enemy = combat_system._active_enemies.get(enemy_id, {})
	target = combat_system._make_npc_enemy_target(NPC_ID, enemy.get("position", Vector3.ZERO))
	var hp_before_impact := int(npc_system.get_npc_state(NPC_ID).get("hp", 0))
	combat_system._advance_enemy_attack(enemy, target, 0.45, combat_system._combat_timeline_seconds + 0.45)
	combat_system._active_enemies[enemy_id] = enemy
	var hp_after_impact := int(npc_system.get_npc_state(NPC_ID).get("hp", hp_before_impact))
	_check(hp_after_impact < hp_before_impact, "T0245 enemy post-impact fixture did not deal damage")
	damage_result = combat_system._apply_damage_to_enemy(enemy_id, 1, NPC_ID, {"source_type": "npc"})
	interrupt = damage_result.get("attack_interrupt", {})
	_check(not bool(interrupt.get("interrupted_before_impact", true)), "T0245 enemy post-impact interrupt was classified as pre-impact: %s" % damage_result)
	_check(int(npc_system.get_npc_state(NPC_ID).get("hp", 0)) == hp_after_impact, "T0245 enemy post-impact damage was rolled back")


func _prepare_friendly_windup(combat_system: Node, npc_system: Node, enemy_id: String, elapsed: float, impact: float, cycle: float, sequence: int) -> void:
	npc_system.update_npc_state(NPC_ID, {
		"combat_target_enemy_id": enemy_id,
		"combat_attack_target_enemy_id": enemy_id,
		"combat_attack_phase": "windup",
		"combat_attack_elapsed_seconds": elapsed,
		"combat_attack_cycle_seconds": cycle,
		"combat_attack_impact_seconds": impact,
		"combat_attack_sequence": sequence,
		"combat_attack_impact_committed": false,
		"combat_attack_next_sequence_time": 0.0,
		"combat_attack_sequence_lock_remaining": 0.0,
		"current_action": "winding_up_%s" % enemy_id
	})
	var target: Dictionary = combat_system._make_enemy_attack_target(enemy_id, combat_system._get_npc_position(NPC_ID))
	var npc: Dictionary = npc_system.get_npc(NPC_ID)
	var state: Dictionary = npc_system.get_npc_state(NPC_ID)
	var context: Dictionary = combat_system._calculate_npc_attack_context(NPC_ID, npc, state)
	combat_system._begin_melee_swing("friendly", NPC_ID, "sword_shield", target, sequence, context)


func _prepare_enemy_windup(combat_system: Node, enemy_id: String, elapsed: float, impact: float, cycle: float, sequence: int) -> void:
	var enemy: Dictionary = combat_system._active_enemies.get(enemy_id, {})
	var target: Dictionary = combat_system._make_npc_enemy_target(NPC_ID, enemy.get("position", Vector3.ZERO))
	enemy["attack_cycle_phase"] = "windup"
	enemy["attack_cycle_elapsed"] = elapsed
	enemy["attack_cycle_duration"] = cycle
	enemy["attack_impact_seconds"] = impact
	enemy["attack_cycle_target"] = target.duplicate(true)
	enemy["attack_impact_committed"] = false
	enemy["attack_sequence"] = sequence
	enemy["attack_next_sequence_time"] = 0.0
	enemy["attack_windup_remaining"] = maxf(0.0, impact - elapsed)
	enemy["attack_windup_target"] = target.duplicate(true)
	enemy["current_action"] = "winding_up_%s" % NPC_ID
	combat_system._active_enemies[enemy_id] = enemy
	combat_system._begin_melee_swing("enemy", enemy_id, str(enemy.get("weapon_type", "polearm")), target, sequence)


func _set_npc_position(npc_system: Node, npc_id: String, position: Vector3) -> void:
	var actor := npc_system.get_node_or_null(npc_system._npc_nodes.get(npc_id, NodePath())) as ActorMotionBody
	if actor != null:
		actor.cancel_motion("t0245_fixture")
		actor.global_position = position
		actor.velocity = Vector3.ZERO


func _set_enemy_position(combat_system: Node, enemy_id: String, position: Vector3) -> void:
	var actor := combat_system.get_node_or_null(combat_system._formal_first_wave_node_paths.get(enemy_id, NodePath())) as ActorMotionBody
	if actor != null:
		actor.cancel_motion("t0245_fixture")
		actor.global_position = position
		actor.velocity = Vector3.ZERO
	var enemy: Dictionary = combat_system._active_enemies.get(enemy_id, {})
	enemy["position"] = position
	combat_system._active_enemies[enemy_id] = enemy


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0245 locked melee impact verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
