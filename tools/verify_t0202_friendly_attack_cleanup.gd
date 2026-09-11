extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const NPC_ID := "veteran_deputy_01"
const FRAME_SECONDS := 1.0 / 60.0

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
	var event_bus := root.get_node_or_null("EventBus")
	_check(combat_system != null and npc_system != null and equipment_system != null, "T0202 combat systems missing")
	_check(resource_system != null and time_system != null and event_bus != null, "T0202 world systems missing")
	if not _failures.is_empty():
		_finish()
		return

	time_system.set_paused(true)
	resource_system.add_resource("item_sword_shield", 1)
	_check(bool(equipment_system.equip_npc_main_weapon(NPC_ID, "sword_shield", "private").get("ok", false)), "T0202 failed to arm Ada")
	combat_system.set_npc_combat_strategy(NPC_ID, "attack", "private")
	npc_system.set_npc_recruited(NPC_ID, true)
	var spawned: Dictionary = combat_system.spawn_wave(1, false, "verify_t0202_external_last_enemy_removal")
	_check(bool(spawned.get("ok", false)), "T0202 failed to spawn production wave: %s" % spawned)
	var enemy_ids: Array[String] = combat_system.get_active_enemy_ids()
	_check(not enemy_ids.is_empty(), "T0202 production enemy missing")
	if enemy_ids.is_empty():
		_finish()
		return
	var enemy_id := enemy_ids[0]
	for index in range(1, enemy_ids.size()):
		combat_system._remove_enemy_from_combat(enemy_ids[index])

	var npc_paths: Dictionary = npc_system.get("_npc_nodes")
	var ada := npc_system.get_node_or_null(npc_paths.get(NPC_ID, NodePath())) as ActorMotionBody
	var enemy_actor := combat_system.get_node_or_null(
		combat_system._formal_first_wave_node_paths.get(enemy_id, NodePath())
	) as ActorMotionBody
	_check(ada != null and enemy_actor != null, "T0202 production actors missing")
	if ada == null or enemy_actor == null:
		_finish()
		return

	ada.cancel_motion("t0202_fixture")
	enemy_actor.cancel_motion("t0202_fixture")
	ada.global_position = Vector3(0.0, 0.2, 20.0)
	enemy_actor.global_position = ada.global_position + Vector3(0.0, 0.0, 1.08)
	ada.velocity = Vector3.ZERO
	enemy_actor.velocity = Vector3.ZERO
	var enemy: Dictionary = combat_system._active_enemies.get(enemy_id, {})
	enemy["position"] = enemy_actor.global_position
	enemy["hp"] = 10000
	enemy["max_hp"] = 10000
	enemy["alive"] = true
	enemy["stagger_remaining"] = 10000.0
	enemy["target"] = {}
	combat_system._cancel_enemy_attack_timeline(enemy)
	combat_system._active_enemies[enemy_id] = enemy
	combat_system._set_formal_enemy_tactical_motion_paused(enemy_id, true)
	combat_system._refresh_enemy_node(enemy_id)
	npc_system.set_npc_behavior_mode(NPC_ID, "combat", "verify_t0202_attack_cleanup", {
		"state_changes": {
			"hp": 120,
			"max_hp": 120,
			"unconscious": false,
			"escaped": false,
			"combat_mounted": false,
			"current_action": "combat_ready",
			"combat_target_enemy_id": enemy_id,
			"combat_attack_sequence": 0,
			"combat_attack_last_sequence_time": -1.0,
			"combat_attack_next_sequence_time": 0.0,
			"combat_attack_sequence_lock_remaining": 0.0,
		},
		"request_plan_reevaluation": false,
	})

	var combat_tick := Callable(combat_system, "_on_logical_time_tick")
	if event_bus.logical_time_tick.is_connected(combat_tick):
		event_bus.logical_time_tick.disconnect(combat_tick)
	time_system.set_paused(false)
	combat_system._advance_combat_ai(FRAME_SECONDS, false)
	await physics_frame
	var attacking_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	_check(int(attacking_state.get("combat_attack_sequence", 0)) == 1, "T0202 Ada did not start one authority sequence: %s" % attacking_state)
	_check(str(attacking_state.get("combat_attack_phase", "")) == "windup", "T0202 fixture did not stop during windup: %s" % attacking_state)
	_check(str(attacking_state.get("current_action", "")).begins_with("winding_up_"), "T0202 visible attack action was not active: %s" % attacking_state)

	combat_system._remove_enemy_from_combat(enemy_id)
	_check(combat_system.get_active_enemy_count() == 0, "T0202 external removal left an active enemy")
	_check(not combat_system._active_battle.is_empty(), "T0202 fixture must retain the active battle until the next combat step")
	combat_system._on_logical_time_tick(FRAME_SECONDS, 1.0)
	await physics_frame
	var cleared_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	var art: Dictionary = ada.debug_get_character_art_snapshot()
	_check(str(cleared_state.get("behavior_mode", "")) == "work", "T0202 Ada did not leave combat after the last enemy disappeared: %s" % cleared_state)
	_check(str(cleared_state.get("current_action", "")) == "idle", "T0202 Ada kept attacking the removed enemy: %s" % cleared_state)
	_check(str(cleared_state.get("combat_target_enemy_id", "")).is_empty(), "T0202 strategic target survived cleanup: %s" % cleared_state)
	_check(str(cleared_state.get("combat_attack_target_enemy_id", "")).is_empty(), "T0202 attack target survived cleanup: %s" % cleared_state)
	_check(str(cleared_state.get("combat_attack_phase", "")) == "idle", "T0202 attack phase survived cleanup: %s" % cleared_state)
	_check(is_zero_approx(float(cleared_state.get("combat_attack_elapsed_seconds", -1.0))), "T0202 attack elapsed survived cleanup: %s" % cleared_state)
	_check(is_zero_approx(float(cleared_state.get("combat_attack_cycle_seconds", -1.0))), "T0202 attack cycle survived cleanup: %s" % cleared_state)
	_check(not str(art.get("current_state", "")).contains("attack"), "T0202 character art kept an attack state after cleanup: %s" % art)
	_check(combat_system.get_active_melee_swing_snapshots().is_empty(), "T0202 melee swing survived cleanup")
	_check(combat_system._active_battle.is_empty(), "T0202 active battle did not finish after cleanup")

	if _failures.is_empty():
		print("T0202_FRIENDLY_ATTACK_CLEANUP_OK %s" % JSON.stringify({
			"sequence_before_cleanup": int(attacking_state.get("combat_attack_sequence", 0)),
			"action_after_cleanup": str(cleared_state.get("current_action", "")),
			"phase_after_cleanup": str(cleared_state.get("combat_attack_phase", "")),
			"art_state_after_cleanup": str(art.get("current_state", "")),
		}))
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
