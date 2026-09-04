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

	var combat := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var equipment := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var resources := root.get_node_or_null("Main/Systems/ResourceSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var station_controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	_check(combat != null and npc_system != null, "T0321 combat or NPC system missing")
	_check(equipment != null and resources != null and time_system != null, "T0321 equipment, resource or time system missing")
	_check(station_controller != null, "T0321 station controller missing")
	if not _failures.is_empty():
		_finish()
		return

	time_system.set_paused(true)
	resources.add_resource("item_sword_shield", 1)
	npc_system.set_npc_recruited(NPC_ID, true)
	_check(bool(equipment.equip_npc_main_weapon(NPC_ID, "sword_shield", "private").get("ok", false)), "T0321 failed to arm Ada")
	combat.set_npc_combat_strategy(NPC_ID, "attack", "private")
	var ada := npc_system.get_node_or_null(npc_system._npc_nodes.get(NPC_ID, NodePath())) as ActorMotionBody
	_check(ada != null, "T0321 Ada actor missing")
	if ada == null:
		_finish()
		return
	ada.cancel_motion("t0321_fixture")
	ada.global_position = Vector3(0.0, 0.2, 20.0)
	ada.velocity = Vector3.ZERO
	npc_system.update_npc_state(NPC_ID, {"hp": 10000, "max_hp": 10000, "unconscious": false, "escaped": false})

	# Match the reported sequence: finish the scheduled production wave, return
	# Ada to the station, then use GM to generate wave one again.
	var first_spawn: Dictionary = combat.spawn_wave(1, false, "t0321_first_formal_runtime")
	_check(bool(first_spawn.get("ok", false)), "T0321 first production wave failed: %s" % first_spawn)
	var first_ids: Array[String] = combat.get_active_enemy_ids()
	_check(not first_ids.is_empty(), "T0321 first GM wave has no enemies")
	for index in range(1, first_ids.size()):
		combat._remove_enemy_from_combat(first_ids[index])
	var first_target_id := first_ids[0] if not first_ids.is_empty() else ""
	var first_enemy_actor := combat.get_node_or_null(combat._formal_first_wave_node_paths.get(first_target_id, NodePath())) as ActorMotionBody
	_check(first_enemy_actor != null, "T0321 first-wave enemy actor missing")
	if first_enemy_actor != null:
		first_enemy_actor.cancel_motion("t0321_first_natural_kill")
		first_enemy_actor.global_position = ada.global_position + Vector3(0.0, 0.0, 1.08)
		first_enemy_actor.velocity = Vector3.ZERO
		var first_enemy: Dictionary = combat.get_enemy(first_target_id)
		first_enemy["position"] = first_enemy_actor.global_position
		first_enemy["hp"] = 1
		first_enemy["max_hp"] = maxi(1, int(first_enemy.get("max_hp", 1)))
		first_enemy["alive"] = true
		first_enemy["stagger_remaining"] = 10000.0
		first_enemy["target"] = {}
		combat._cancel_enemy_attack_timeline(first_enemy)
		combat._active_enemies[first_target_id] = first_enemy
		combat._set_formal_enemy_tactical_motion_paused(first_target_id, true)
		combat._refresh_enemy_node(first_target_id)
	npc_system.set_npc_behavior_mode(NPC_ID, "combat", "t0321_first_wave", {
		"state_changes": {"current_action": "combat_ready", "combat_target_enemy_id": first_target_id},
		"request_plan_reevaluation": false,
	})
	time_system.set_paused(false)
	for _frame in range(240):
		combat._advance_combat_ai(FRAME_SECONDS, false)
		await physics_frame
		if combat.get_active_enemy_count() == 0:
			break
	time_system.set_paused(true)
	var cleared_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	_check(combat.get_active_enemy_count() == 0, "T0321 first wave did not clear")
	_check(str(cleared_state.get("behavior_mode", "")) == "work", "T0321 Ada did not leave combat after first wave: %s" % cleared_state)
	_check(str(cleared_state.get("combat_target_enemy_id", "")).is_empty(), "T0321 first-wave target lock survived battle end: %s" % cleared_state)

	var second_spawn: Dictionary = combat.debug_run_formal_dynamic_wave_slice(1, true)
	_check(bool(second_spawn.get("ok", false)), "T0321 second GM wave failed: %s" % second_spawn)
	var second_ids: Array[String] = combat.get_active_enemy_ids()
	_check(not second_ids.is_empty(), "T0321 second GM wave has no enemies")
	_check(first_ids != second_ids, "T0321 production and GM wave identities unexpectedly overlap: %s -> %s" % [first_ids, second_ids])
	if second_ids.is_empty():
		_finish()
		return
	var target_id := second_ids[0]
	for index in range(1, second_ids.size()):
		combat._remove_enemy_from_combat(second_ids[index])
	var enemy_actor := combat.get_node_or_null(combat._formal_first_wave_node_paths.get(target_id, NodePath())) as ActorMotionBody
	_check(enemy_actor != null, "T0321 second-wave enemy actor missing")
	if enemy_actor == null:
		_finish()
		return
	enemy_actor.cancel_motion("t0321_fixture")
	# Ada is still inside the station after wave one. The next group is outside
	# the wall but already within the authored 37.2 m detection circle.
	ada.global_position = Vector3(0.0, 0.2, 30.0)
	enemy_actor.global_position = Vector3(0.0, 0.2, 60.0)
	enemy_actor.velocity = Vector3.ZERO
	var second_enemy: Dictionary = combat.get_enemy(target_id)
	second_enemy["position"] = enemy_actor.global_position
	second_enemy["hp"] = 10000
	second_enemy["max_hp"] = 10000
	second_enemy["alive"] = true
	second_enemy["stagger_remaining"] = 10000.0
	second_enemy["target"] = {}
	combat._cancel_enemy_attack_timeline(second_enemy)
	combat._active_enemies[target_id] = second_enemy
	combat._set_formal_enemy_tactical_motion_paused(target_id, true)
	combat._refresh_enemy_node(target_id)
	_check(station_controller.is_world_position_inside_station(ada.global_position), "T0321 Ada union fixture is outside station")
	_check(not station_controller.is_world_position_inside_station(enemy_actor.global_position), "T0321 repeated-wave enemy fixture is inside station")
	var repeated_wave_scope: Dictionary = combat._get_friendly_target_scope(NPC_ID)
	_check(str(repeated_wave_scope.get("scope", "")) == "entire_station_plus_unified_radius", "T0321 unbreached inside union scope mismatch: %s" % repeated_wave_scope)
	_check(bool(repeated_wave_scope.get("include_station_enemies", false)), "T0321 unbreached inside union omitted station candidates: %s" % repeated_wave_scope)
	_check(not bool(repeated_wave_scope.get("station_enemy_only", true)), "T0321 unbreached inside union incorrectly became station-only: %s" % repeated_wave_scope)
	_check(str(combat._find_nearest_friendly_combat_enemy(NPC_ID, repeated_wave_scope).get("id", "")) == target_id, "T0321 nearby outside enemy was absent from inside union")

	var start_position := ada.global_position
	var enemy_hp_before := int(second_enemy.get("hp", 0))
	var ada_hp_before := int(npc_system.get_npc_state(NPC_ID).get("hp", 0))
	var incoming: Dictionary = combat._apply_enemy_attack_to_npc(
		second_enemy,
		NPC_ID,
		1,
		1.0,
		0.0,
		0.0,
		0.0
	)
	var incoming_result: Dictionary = incoming.get("result", {}) if incoming.get("result", {}) is Dictionary else {}
	_check(int(incoming_result.get("hp_after", ada_hp_before)) == ada_hp_before - 1, "T0321 second-wave enemy damage did not reach Ada: %s" % incoming)
	var entered_combat := false
	var acquired_target := false
	var moved := false
	var attacked := false
	time_system.set_paused(false)
	for _frame in range(600):
		combat._advance_behavior_mode_contacts()
		combat._advance_combat_ai(FRAME_SECONDS, false)
		await physics_frame
		var state: Dictionary = npc_system.get_npc_state(NPC_ID)
		entered_combat = entered_combat or str(state.get("behavior_mode", "")) == "combat"
		acquired_target = acquired_target or str(state.get("combat_target_enemy_id", "")) == target_id
		moved = moved or ada.global_position.distance_to(start_position) > 0.25
		attacked = attacked or int(combat.get_enemy(target_id).get("hp", enemy_hp_before)) < enemy_hp_before
		if attacked:
			break

	var final_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	var diagnostics := {
		"first_ids": first_ids,
		"second_ids": second_ids,
		"entered_combat": entered_combat,
		"acquired_target": acquired_target,
		"moved": moved,
		"attacked": attacked,
		"incoming_damage": incoming_result,
		"repeated_wave_scope": repeated_wave_scope,
		"ada_position": ada.global_position,
		"enemy_position": enemy_actor.global_position,
		"distance": ada.global_position.distance_to(enemy_actor.global_position),
		"final_state": final_state,
	}
	print("T0321_REPEAT_WAVE_DIAGNOSTICS %s" % JSON.stringify(diagnostics))
	_check(entered_combat, "T0321 Ada did not re-enter combat for repeated wave: %s" % diagnostics)
	_check(acquired_target, "T0321 Ada did not acquire repeated-wave enemy: %s" % diagnostics)
	_check(moved, "T0321 Ada did not pursue repeated-wave enemy: %s" % diagnostics)
	_check(attacked, "T0321 Ada did not damage repeated-wave enemy: %s" % diagnostics)

	combat.clear_spawned_enemies()
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0321_REPEAT_WAVE_FRIENDLY_REENGAGE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
