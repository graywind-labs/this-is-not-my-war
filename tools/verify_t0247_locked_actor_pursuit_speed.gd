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
	for _frame in range(6):
		await process_frame
		await physics_frame

	var combat := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var equipment := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var resources := root.get_node_or_null("Main/Systems/ResourceSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	_check(not [combat, npc_system, equipment, resources, time_system, controller].has(null), "T0247 production dependencies missing")
	if not _failures.is_empty():
		_finish()
		return
	time_system.set_paused(false)

	resources.add_resource("item_sword_shield", 1)
	npc_system.set_npc_recruited(NPC_ID, true)
	var equipped: Dictionary = equipment.equip_npc_main_weapon(NPC_ID, "sword_shield", "private")
	_check(bool(equipped.get("ok", false)), "T0247 failed to arm Ada: %s" % equipped)
	combat.set_npc_combat_strategy(NPC_ID, "attack", "private")
	var spawned: Dictionary = combat.debug_run_formal_dynamic_wave_slice(1, true)
	_check(bool(spawned.get("ok", false)), "T0247 first wave failed to spawn: %s" % spawned)
	var enemy_ids: Array[String] = combat.get_active_enemy_ids()
	_check(enemy_ids.size() >= 2, "T0247 needs two configured enemy actors")
	if not _failures.is_empty():
		_finish()
		return

	var enemy_id := enemy_ids[0]
	var peer_enemy_id := enemy_ids[1]
	var enemy_actor := _get_enemy_actor(combat, enemy_id)
	var peer_enemy_actor := _get_enemy_actor(combat, peer_enemy_id)
	var npc_actor := npc_system.get_node_or_null(npc_system._npc_nodes.get(NPC_ID, NodePath()))
	_check(enemy_actor != null and peer_enemy_actor != null and npc_actor != null, "T0247 combat actors missing")
	if not _failures.is_empty():
		_finish()
		return

	var enemy_group: Dictionary = enemy_actor.debug_get_motion_snapshot()
	var peer_group: Dictionary = peer_enemy_actor.debug_get_motion_snapshot()
	var npc_group: Dictionary = npc_actor.debug_get_motion_snapshot()
	_check(int(enemy_group.get("avoidance_layers", 0)) == int(peer_group.get("avoidance_layers", -1)), "T0247 same-side enemies lost a shared RVO layer")
	_check((int(enemy_group.get("avoidance_mask", 0)) & int(enemy_group.get("avoidance_layers", 0))) != 0, "T0247 enemies no longer avoid their own side")
	_check((int(npc_group.get("avoidance_mask", 0)) & int(npc_group.get("avoidance_layers", 0))) != 0, "T0247 NPCs no longer avoid their own side")
	_check((int(enemy_group.get("avoidance_layers", 0)) & int(npc_group.get("avoidance_mask", 0))) == 0, "T0247 NPC RVO still treats enemies as pedestrians")
	_check((int(npc_group.get("avoidance_layers", 0)) & int(enemy_group.get("avoidance_mask", 0))) == 0, "T0247 enemy RVO still treats NPCs as pedestrians")

	for index in range(1, enemy_ids.size()):
		combat._remove_enemy_from_combat(enemy_ids[index])
	await process_frame

	var navigation_map: RID = controller.get_production_navigation_map_rid()
	var npc_position := NavigationServer3D.map_get_closest_point(navigation_map, Vector3(-3.0, 0.0, 22.0))
	var enemy_position := NavigationServer3D.map_get_closest_point(navigation_map, Vector3(-3.0, 0.0, 36.0))
	npc_actor.stop_movement()
	npc_actor.global_position = npc_position
	npc_system.set_npc_behavior_mode(NPC_ID, "combat", "verify_t0247", {
		"state_changes": {
			"satiety": 100,
			"hp": 10000,
			"max_hp": 10000,
			"unconscious": false,
			"escaped": false,
			"combat_mounted": false,
			"current_action": "combat_ready",
			"combat_target_enemy_id": enemy_id
		},
		"request_plan_reevaluation": false
	})
	var enemy: Dictionary = combat.get_enemy(enemy_id)
	enemy["position"] = enemy_position
	enemy["alive"] = true
	enemy["hp"] = 10000
	enemy["max_hp"] = 10000
	enemy["combat_target_id"] = NPC_ID
	enemy["combat_target_type"] = "npc"
	combat._active_enemies[enemy_id] = enemy
	enemy_actor.cancel_motion("t0247_setup")
	enemy_actor.apply_external_displacement(enemy_position, "t0247_setup")
	combat._refresh_enemy_node(enemy_id)

	var enemy_full_speed_samples := 0
	var npc_full_speed_samples := 0
	var enemy_target_updates := 0
	var npc_target_updates := 0
	var minimum_sampled_separation := INF
	var enemy_bad_reasons: Array[String] = []
	var npc_bad_reasons: Array[String] = []
	var enemy_minimum_cruise_ratio := INF
	var npc_minimum_cruise_ratio := INF
	var attack_handoff_seen := false
	for frame in range(240):
		await physics_frame
		var current_enemy: Dictionary = combat.get_enemy(enemy_id)
		var npc_state: Dictionary = npc_system.get_npc_state(NPC_ID)
		var separation := _horizontal_distance(enemy_actor.global_position, npc_actor.global_position)
		minimum_sampled_separation = minf(minimum_sampled_separation, separation)
		var enemy_motion: Dictionary = enemy_actor.debug_get_motion_snapshot()
		var npc_motion: Dictionary = npc_actor.debug_get_motion_snapshot()
		enemy_target_updates = maxi(enemy_target_updates, int(enemy_motion.get("target_update_count", 0)))
		npc_target_updates = maxi(npc_target_updates, int(npc_motion.get("target_update_count", 0)))
		if frame >= 8 and separation > 1.75:
			if bool(enemy_motion.get("active", false)):
				enemy_full_speed_samples += 1
				var enemy_reason := str(enemy_motion.get("speed_limit_reason", ""))
				if enemy_reason == "final_target_braking":
					enemy_bad_reasons.append(enemy_reason)
				_check(float(enemy_motion.get("desired_speed", 0.0)) >= float(enemy_motion.get("profile_base_speed", 0.0)) * 0.98, "T0247 enemy desired speed dipped during live pursuit: %s" % enemy_motion)
				if float(enemy_motion.get("maximum_observed_speed", 0.0)) >= float(enemy_motion.get("profile_base_speed", 0.0)) * 0.95:
					enemy_minimum_cruise_ratio = minf(enemy_minimum_cruise_ratio, float(enemy_motion.get("actual_speed", 0.0)) / maxf(0.001, float(enemy_motion.get("profile_base_speed", 0.0))))
			if bool(npc_motion.get("active", false)):
				npc_full_speed_samples += 1
				var npc_reason := str(npc_motion.get("speed_limit_reason", ""))
				if npc_reason == "final_target_braking":
					npc_bad_reasons.append(npc_reason)
				_check(float(npc_motion.get("desired_speed", 0.0)) >= float(npc_motion.get("profile_base_speed", 0.0)) * 0.98, "T0247 NPC desired speed dipped during live pursuit: %s" % npc_motion)
				if float(npc_motion.get("maximum_observed_speed", 0.0)) >= float(npc_motion.get("profile_base_speed", 0.0)) * 0.95:
					npc_minimum_cruise_ratio = minf(npc_minimum_cruise_ratio, float(npc_motion.get("actual_speed", 0.0)) / maxf(0.001, float(npc_motion.get("profile_base_speed", 0.0))))
		if (
			str(current_enemy.get("current_action", "")).begins_with("winding_up_")
			and str(npc_state.get("current_action", "")).begins_with("winding_up_")
		):
			attack_handoff_seen = true
			break

	_check(enemy_full_speed_samples >= 3, "T0247 did not observe enough enemy pursuit samples")
	_check(npc_full_speed_samples >= 3, "T0247 did not observe enough NPC pursuit samples")
	_check(enemy_target_updates >= 2 and npc_target_updates >= 2, "T0247 moving-target refresh was not exercised: enemy=%d npc=%d" % [enemy_target_updates, npc_target_updates])
	_check(enemy_bad_reasons.is_empty(), "T0247 enemy repeatedly slowed before handoff: %s" % [enemy_bad_reasons])
	_check(npc_bad_reasons.is_empty(), "T0247 NPC repeatedly slowed before handoff: %s" % [npc_bad_reasons])
	_check(enemy_minimum_cruise_ratio >= 0.90, "T0247 enemy materially lost speed during live pursuit: %.3f" % enemy_minimum_cruise_ratio)
	_check(npc_minimum_cruise_ratio >= 0.90, "T0247 NPC materially lost speed during live pursuit: %.3f" % npc_minimum_cruise_ratio)
	_check(attack_handoff_seen, "T0247 full-speed pursuit did not hand off to both attack timelines")
	_check(minimum_sampled_separation >= 0.75, "T0247 actors penetrated one another before attack handoff: %.3f" % minimum_sampled_separation)
	print("T0247_LOCKED_ACTOR_PURSUIT_SPEED_DIAGNOSTICS %s" % JSON.stringify({
		"enemy_target_updates": enemy_target_updates,
		"npc_target_updates": npc_target_updates,
		"enemy_full_speed_samples": enemy_full_speed_samples,
		"npc_full_speed_samples": npc_full_speed_samples,
		"enemy_minimum_cruise_ratio": enemy_minimum_cruise_ratio,
		"npc_minimum_cruise_ratio": npc_minimum_cruise_ratio,
		"minimum_separation": minimum_sampled_separation,
		"enemy_avoidance_layer": enemy_group.get("avoidance_layers", 0),
		"npc_avoidance_layer": npc_group.get("avoidance_layers", 0)
	}))
	combat.clear_spawned_enemies()
	_finish()


func _get_enemy_actor(combat: Node, enemy_id: String) -> Node:
	return combat.get_node_or_null(combat._formal_first_wave_node_paths.get(enemy_id, NodePath()))


func _horizontal_distance(left: Vector3, right: Vector3) -> float:
	return Vector2(left.x, left.z).distance_to(Vector2(right.x, right.z))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0247_LOCKED_ACTOR_PURSUIT_SPEED_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
