extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const ACTIVE_NPC_ID := "veteran_deputy_01"
const MOUNTED_NPC_ID := "stableman_01"
const AVOIDING_NPC_ID := "cook_01"

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
	var horse_system := root.get_node_or_null("Main/Systems/HorseSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var station_controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	_check(combat_system != null and npc_system != null, "T0188 combat or NPC system missing")
	_check(equipment_system != null and resource_system != null and horse_system != null, "T0188 equipment or horse systems missing")
	_check(time_system != null and station_controller != null, "T0188 time or station controller missing")
	if not _failures.is_empty():
		_finish()
		return
	time_system.set_paused(true)

	resource_system.add_resource("item_sword_shield", 3)
	_check(bool(equipment_system.equip_npc_main_weapon(ACTIVE_NPC_ID, "sword_shield", "private").get("ok", false)), "T0188 failed to arm active responder")
	combat_system.set_npc_combat_strategy(ACTIVE_NPC_ID, "attack", "private")
	_set_npc_position(npc_system, ACTIVE_NPC_ID, Vector3(-40.0, 0.0, -28.0))
	npc_system.update_npc_state(ACTIVE_NPC_ID, {"behavior_mode": "work", "current_action": "sleep_in_dormitory"})

	var enemy_id := _spawn_single_enemy(combat_system, Vector3(5.0, 0.0, 86.0))
	_check(not enemy_id.is_empty(), "T0188 failed to spawn enemy")
	_check(not station_controller.is_world_position_inside_station(Vector3(5.0, 0.0, 86.0)), "T0188 outside fixture was classified inside station")
	combat_system._advance_behavior_mode_contacts()
	_check(_mode(npc_system, ACTIVE_NPC_ID) == "work", "T0188 outside enemy incorrectly triggered global combat")

	_set_enemy_position(combat_system, enemy_id, Vector3(0.0, 0.0, 30.0))
	_check(station_controller.is_world_position_inside_station(Vector3(0.0, 0.0, 30.0)), "T0188 inside fixture was classified outside station")
	combat_system._advance_behavior_mode_contacts()
	_check(_mode(npc_system, ACTIVE_NPC_ID) == "combat", "T0188 distant armed recruit did not enter combat on station breach")
	_check(not str(npc_system.get_npc_state(ACTIVE_NPC_ID).get("current_action", "")).begins_with("sleep"), "T0188 armed sleeping recruit was not awakened by station breach")
	var response: Dictionary = combat_system.debug_get_combat_snapshot().get("friendly_station_response", {})
	_check(bool(response.get("station_breached", false)), "T0188 station breach runtime fact missing")
	_check((response.get("station_enemy_ids", []) as Array).has(enemy_id), "T0188 station enemy missing from response snapshot")
	var outside_enemy_id := "%s_outside_nearby" % enemy_id
	var outside_enemy: Dictionary = combat_system.get_enemy(enemy_id).duplicate(true)
	outside_enemy["id"] = outside_enemy_id
	outside_enemy["name"] = "站外近敌夹具"
	outside_enemy["position"] = Vector3(-60.0, 0.0, -28.0)
	combat_system._active_enemies[outside_enemy_id] = outside_enemy
	_check(not station_controller.is_world_position_inside_station(outside_enemy["position"]), "T0188 nearby outside fixture fell inside station polygon")
	var active_profile: Dictionary = npc_system.get_npc(ACTIVE_NPC_ID)
	var active_state_before: Dictionary = npc_system.get_npc_state(ACTIVE_NPC_ID)
	var attack_context: Dictionary = combat_system._calculate_npc_attack_context(ACTIVE_NPC_ID, active_profile, active_state_before)
	attack_context["strategy_id"] = "attack"
	attack_context["range"] = 100.0
	var station_only_target: Dictionary = combat_system._select_npc_attack_target(ACTIVE_NPC_ID, attack_context)
	_check(
		str(station_only_target.get("id", "")) == enemy_id,
		"T0188 proactive responder selected an outside enemy while station remained breached: %s" % station_only_target
	)
	combat_system._active_enemies.erase(outside_enemy_id)
	combat_system.debug_step_enemy_ai(0.1)
	var active_state: Dictionary = npc_system.get_npc_state(ACTIVE_NPC_ID)
	_check(
		str(active_state.get("current_action", "")).begins_with("moving_to_combat_strategy_attack"),
		"T0188 proactive responder did not pursue distant station enemy: %s" % active_state
	)
	_check(str(active_state.get("combat_target_enemy_id", "")) == enemy_id, "T0188 proactive responder did not lock station enemy")
	_set_enemy_position(combat_system, enemy_id, Vector3(5.0, 0.0, 86.0))
	combat_system.debug_step_enemy_ai(0.1)
	active_state = npc_system.get_npc_state(ACTIVE_NPC_ID)
	_check(str(active_state.get("current_action", "")) == "combat_ready", "T0188 responder kept global pursuit after station cleared: %s" % active_state)
	_check(str(active_state.get("movement_target", "")).is_empty(), "T0188 stale station pursuit movement survived range fallback")
	_set_enemy_position(combat_system, enemy_id, Vector3(0.0, 0.0, 30.0))

	# Assigned riders must enter combat but keep the horse pickup route as the only
	# action allowed before mounted readiness is reported.
	combat_system._complete_npc_avoidance(MOUNTED_NPC_ID, "t0188_mounted_fixture_reset")
	npc_system.set_npc_behavior_mode(MOUNTED_NPC_ID, "work", "t0188_mounted_fixture_reset", {
		"force_idle": true,
		"request_plan_reevaluation": false
	})
	npc_system.set_npc_recruited(MOUNTED_NPC_ID, true)
	_check(bool(equipment_system.equip_npc_main_weapon(MOUNTED_NPC_ID, "sword_shield", "private").get("ok", false)), "T0188 failed to arm mounted responder")
	var mount_result: Dictionary = equipment_system.equip_npc_mount(MOUNTED_NPC_ID, "", "private")
	_check(bool(mount_result.get("ok", false)), "T0188 failed to assign mount: %s" % mount_result)
	combat_system.set_npc_combat_strategy(MOUNTED_NPC_ID, "attack", "private")
	_set_npc_position(npc_system, MOUNTED_NPC_ID, Vector3(-35.0, 0.0, -25.0))
	combat_system._advance_behavior_mode_contacts()
	var mounting_state: Dictionary = npc_system.get_npc_state(MOUNTED_NPC_ID)
	_check(_mode(npc_system, MOUNTED_NPC_ID) == "combat", "T0188 mounted responder did not enter combat mode")
	_check(str(mounting_state.get("combat_mount_phase", "")) in ["going_to_stable_horse", "beside_stable_horse"], "T0188 mounted responder skipped stable pickup: %s" % mounting_state)
	_check(not bool(mounting_state.get("combat_mounted", false)), "T0188 rider attacked as mounted before pickup")
	var assigned_horse_id := str(mount_result.get("horse_id", mount_result.get("mount_id", "")))
	if assigned_horse_id.is_empty():
		assigned_horse_id = _find_assigned_horse(horse_system, MOUNTED_NPC_ID)
	_check(not assigned_horse_id.is_empty(), "T0188 assigned horse id missing")
	if not assigned_horse_id.is_empty():
		horse_system._complete_mount_rendezvous(assigned_horse_id)
		await process_frame
		var mounted_state: Dictionary = npc_system.get_npc_state(MOUNTED_NPC_ID)
		_check(bool(mounted_state.get("combat_mounted", false)), "T0188 rider did not become mounted at rendezvous completion")
		_check(str(mounted_state.get("combat_mount_phase", "")) == "mounted", "T0188 mounted phase did not become ready")
		combat_system.debug_step_enemy_ai(0.1)
		mounted_state = npc_system.get_npc_state(MOUNTED_NPC_ID)
		_check(
			str(mounted_state.get("current_action", "")).begins_with("moving_to_combat_strategy_attack"),
			"T0188 mounted rider did not enter normal combat pursuit: %s" % mounted_state
		)

	# A ranged threat at 13 m is outside the old 5 m contact range, but must
	# trigger avoidance before its authored 12 m attack boundary can be crossed.
	combat_system.clear_spawned_enemies()
	await process_frame
	enemy_id = _spawn_single_enemy(combat_system, Vector3(0.0, 0.0, 20.0))
	var ranged_enemy: Dictionary = combat_system.get_enemy(enemy_id)
	ranged_enemy["weapon_type"] = "bow"
	ranged_enemy["attack_range"] = 12.0
	combat_system._active_enemies[enemy_id] = ranged_enemy
	_set_npc_position(npc_system, AVOIDING_NPC_ID, Vector3(0.0, 0.0, 7.0))
	npc_system.set_npc_behavior_mode(AVOIDING_NPC_ID, "work", "t0188_avoidance_fixture", {"force_idle": true, "request_plan_reevaluation": false})
	combat_system._advance_behavior_mode_contacts()
	await process_frame
	var avoiding_state: Dictionary = npc_system.get_npc_state(AVOIDING_NPC_ID)
	var avoidance := _find_avoidance(combat_system.get_active_avoidances(), AVOIDING_NPC_ID)
	_check(_mode(npc_system, AVOIDING_NPC_ID) == "avoid_combat", "T0188 civilian did not avoid before ranged attack boundary")
	_check(float(avoidance.get("trigger_range", 0.0)) > 12.0, "T0188 avoidance trigger does not exceed ranged attack range: %s" % avoidance)
	_check(float(avoidance.get("safe_distance", 0.0)) > 12.0, "T0188 avoidance safe distance does not exceed ranged attack range: %s" % avoidance)
	var avoiding_node := _get_npc_node(npc_system, AVOIDING_NPC_ID)
	var motion: Dictionary = avoiding_node.debug_get_motion_snapshot() if avoiding_node != null and avoiding_node.has_method("debug_get_motion_snapshot") else {}
	var art: Dictionary = avoiding_node.debug_get_character_art_snapshot() if avoiding_node != null and avoiding_node.has_method("debug_get_character_art_snapshot") else {}
	_check(str(art.get("locomotion_state", "")) == "run", "T0188 avoidance locomotion is not run: motion=%s art=%s state=%s" % [motion, art, avoiding_state])
	_check(absf(float(motion.get("profile_base_speed", 0.0)) - 5.0) <= 0.05, "T0188 avoidance did not use run speed: %s" % motion)

	combat_system.clear_spawned_enemies()
	_finish()


func _spawn_single_enemy(combat_system: Node, position: Vector3) -> String:
	var spawned: Dictionary = combat_system.debug_spawn_wave(1, true)
	if not bool(spawned.get("ok", false)):
		return ""
	var enemy_ids: Array[String] = combat_system.get_active_enemy_ids()
	if enemy_ids.is_empty():
		return ""
	var enemy_id := enemy_ids[0]
	for index in range(1, enemy_ids.size()):
		combat_system._remove_enemy_from_combat(enemy_ids[index])
	_set_enemy_position(combat_system, enemy_id, position)
	return enemy_id


func _set_enemy_position(combat_system: Node, enemy_id: String, position: Vector3) -> void:
	var enemy: Dictionary = combat_system.get_enemy(enemy_id)
	enemy["position"] = position
	enemy["alive"] = true
	combat_system._active_enemies[enemy_id] = enemy
	var actor_path: NodePath = combat_system._formal_first_wave_node_paths.get(enemy_id, NodePath())
	var actor := combat_system.get_node_or_null(actor_path) as Node3D
	if actor != null:
		actor.global_position = position
	combat_system._refresh_enemy_node(enemy_id)


func _set_npc_position(npc_system: Node, npc_id: String, position: Vector3) -> void:
	var npc := _get_npc_node(npc_system, npc_id) as Node3D
	if npc != null:
		if npc.has_method("stop_movement"):
			npc.stop_movement()
		npc.global_position = position
	else:
		_failures.append("T0188 NPC node missing: %s" % npc_id)


func _get_npc_node(npc_system: Node, npc_id: String) -> Node:
	var paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(paths.get(npc_id, NodePath("")))


func _mode(npc_system: Node, npc_id: String) -> String:
	return str(npc_system.get_npc_behavior_mode_snapshot(npc_id).get("behavior_mode", ""))


func _find_assigned_horse(horse_system: Node, npc_id: String) -> String:
	for raw_horse_id in horse_system.get_horse_state_snapshot().keys():
		var horse_id := str(raw_horse_id)
		var horse: Dictionary = horse_system.get_horse_state_snapshot().get(horse_id, {})
		if str(horse.get("assigned_npc_id", "")) == npc_id:
			return horse_id
	return ""


func _find_avoidance(avoidances: Array[Dictionary], npc_id: String) -> Dictionary:
	for avoidance in avoidances:
		if str(avoidance.get("npc_id", "")) == npc_id:
			return avoidance
	return {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0188_FRIENDLY_STATION_RESPONSE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
