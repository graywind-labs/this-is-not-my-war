extends SceneTree

const MOTION_SANDBOX := preload("res://scenes/debug/ActorMotionSandbox.tscn")
const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const NPC_ID := "veteran_deputy_01"

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var motion_diagnostics := await _verify_motion_contract()
	var combat_diagnostics := await _verify_combat_contract()
	var diagnostics := {
		"motion": motion_diagnostics,
		"combat": combat_diagnostics
	}
	print("T0200_SHARED_COMBAT_NAVIGATION_DIAGNOSTICS %s" % JSON.stringify(diagnostics))
	_finish()


func _verify_motion_contract() -> Dictionary:
	var sandbox := MOTION_SANDBOX.instantiate()
	root.add_child(sandbox)
	for _frame in range(16):
		await physics_frame
	var route := sandbox.debug_get_actor("route") as ActorMotionBody
	var direct := sandbox.debug_get_actor("avoid_left") as ActorMotionBody
	var stuck := sandbox.debug_get_actor("stuck") as ActorMotionBody
	_check(route != null and direct != null and stuck != null, "T0200 motion sandbox actors missing")
	if route == null or direct == null or stuck == null:
		sandbox.queue_free()
		await process_frame
		return {}
	var route_snapshot := route.debug_get_motion_snapshot()
	var direct_snapshot := direct.debug_get_motion_snapshot()
	_check(str(route_snapshot.get("path_plan_mode", "")) == "detour", "T0200 static obstacle did not produce a shortest-path detour: %s" % route_snapshot)
	_check(str(direct_snapshot.get("path_plan_mode", "")) == "direct", "T0200 unobstructed route did not prefer the direct path: %s" % direct_snapshot)

	var blocked_target: Vector3 = stuck.debug_get_motion_snapshot().get("target_position", stuck.global_position)
	stuck.request_motion(blocked_target, "t0200_persistent_block", {
		"movement_purpose": "combat_unexpected_block",
		"persistent_repath": true,
		"target_update_distance": 0.35
	})
	for _frame in range(720):
		await physics_frame
	var persistent_snapshot := stuck.debug_get_motion_snapshot()
	_check(bool(persistent_snapshot.get("active", false)), "T0200 persistent combat path incorrectly ended while its target was still valid: %s" % persistent_snapshot)
	_check(int(persistent_snapshot.get("repath_count", 0)) > 4, "T0200 unexpected obstruction did not continue replanning: %s" % persistent_snapshot)
	_check(bool(persistent_snapshot.get("persistent_repath", false)), "T0200 persistent motion option was not authoritative: %s" % persistent_snapshot)
	var result := {
		"unobstructed_route_mode": direct_snapshot.get("path_plan_mode", ""),
		"static_route_mode": route_snapshot.get("path_plan_mode", ""),
		"static_route_length": route_snapshot.get("path_length", 0.0),
		"static_direct_distance": route_snapshot.get("direct_distance", 0.0),
		"persistent_active_after_12s": persistent_snapshot.get("active", false),
		"persistent_repath_count": persistent_snapshot.get("repath_count", 0),
		"persistent_last_result": persistent_snapshot.get("last_result", "")
	}
	sandbox.queue_free()
	await process_frame
	await physics_frame
	return result


func _verify_combat_contract() -> Dictionary:
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
	_check(combat != null and npc_system != null and equipment != null and resources != null and time_system != null, "T0200 Main combat dependencies missing")
	if combat == null or npc_system == null or equipment == null or resources == null or time_system == null:
		return {}

	time_system.set_paused(true)
	resources.add_resource("item_sword_shield", 1)
	_check(bool(equipment.equip_npc_main_weapon(NPC_ID, "sword_shield", "private").get("ok", false)), "T0200 failed to arm Ada")
	npc_system.set_npc_recruited(NPC_ID, true)
	combat.set_npc_combat_strategy(NPC_ID, "attack", "private")
	var spawned: Dictionary = combat.debug_run_formal_dynamic_wave_slice(1, true)
	_check(bool(spawned.get("ok", false)), "T0200 formal wave failed to spawn: %s" % spawned)
	var enemy_ids: Array[String] = combat.get_active_enemy_ids()
	_check(not enemy_ids.is_empty(), "T0200 formal wave has no enemies")
	if enemy_ids.is_empty():
		return {}
	var enemy_id := enemy_ids[0]
	for index in range(1, enemy_ids.size()):
		combat._remove_enemy_from_combat(enemy_ids[index])

	var ada := npc_system.get_node_or_null(npc_system._npc_nodes.get(NPC_ID, NodePath())) as ActorMotionBody
	var enemy_actor := combat.get_node_or_null(combat._formal_first_wave_node_paths.get(enemy_id, NodePath())) as ActorMotionBody
	_check(ada != null and enemy_actor != null, "T0200 formal combat actors missing")
	if ada == null or enemy_actor == null:
		return {}
	var navigation_map := ada.get_navigation_map()
	var ada_position := NavigationServer3D.map_get_closest_point(navigation_map, Vector3(-8.0, 0.0, 70.0))
	var enemy_position := NavigationServer3D.map_get_closest_point(navigation_map, ada_position + Vector3(8.0, 0.0, 0.0))
	ada.cancel_motion("t0200_fixture")
	ada.global_position = ada_position
	ada.velocity = Vector3.ZERO
	enemy_actor.cancel_motion("t0200_fixture")
	enemy_actor.global_position = enemy_position
	enemy_actor.velocity = Vector3.ZERO
	var enemy: Dictionary = combat._active_enemies.get(enemy_id, {})
	enemy["position"] = enemy_position
	enemy["hp"] = 10000
	enemy["max_hp"] = 10000
	enemy["alive"] = true
	enemy["target"] = {}
	combat._active_enemies[enemy_id] = enemy
	npc_system.set_npc_behavior_mode(NPC_ID, "combat", "verify_t0200", {
		"state_changes": {
			"hp": 10000,
			"max_hp": 10000,
			"unconscious": false,
			"escaped": false,
			"combat_target_enemy_id": enemy_id,
			"current_action": "combat_ready"
		},
		"request_plan_reevaluation": false
	})
	var encounter: Dictionary = combat._make_friendly_enemy_target(enemy_id, ada_position)
	var melee_point: Dictionary = combat._select_approach_target(NPC_ID, encounter, 1.5)
	var ranged_point: Dictionary = combat._select_approach_target(NPC_ID, encounter, 12.0)
	var melee_standoff := (melee_point.get("position", enemy_position) as Vector3).distance_to(enemy_position)
	var ranged_standoff := (ranged_point.get("position", enemy_position) as Vector3).distance_to(enemy_position)
	_check(ranged_standoff > melee_standoff + 5.0, "T0200 ranged and melee engagement goals did not honor different weapon ranges: melee=%s ranged=%s" % [melee_point, ranged_point])

	combat._advance_single_npc_combat_attack(NPC_ID, 0.1)
	var friendly_before := ada.debug_get_motion_snapshot()
	var friendly_request_id := str(friendly_before.get("request_id", ""))
	_check(bool(friendly_before.get("active", false)) and bool(friendly_before.get("persistent_repath", false)), "T0200 friendly combat did not start persistent navigation: %s" % friendly_before)

	var moved_enemy_position := NavigationServer3D.map_get_closest_point(navigation_map, enemy_position + Vector3(0.0, 0.0, 2.0))
	enemy_actor.global_position = moved_enemy_position
	enemy["position"] = moved_enemy_position
	combat._active_enemies[enemy_id] = enemy
	combat._advance_single_npc_combat_attack(NPC_ID, 0.1)
	var friendly_after := ada.debug_get_motion_snapshot()
	_check(str(friendly_after.get("request_id", "")) == friendly_request_id, "T0200 friendly target movement replaced the authority request instead of updating it: %s -> %s" % [friendly_before, friendly_after])
	_check(int(friendly_after.get("target_update_count", 0)) > int(friendly_before.get("target_update_count", 0)), "T0200 friendly pursuit kept walking to the stale engagement point: %s" % friendly_after)

	ada.apply_external_displacement(moved_enemy_position + Vector3(-1.0, 0.0, 0.0), "t0200_attack_range")
	combat._advance_single_npc_combat_attack(NPC_ID, 0.1)
	var friendly_in_range := ada.debug_get_motion_snapshot()
	_check(not bool(friendly_in_range.get("active", true)), "T0200 friendly movement did not hand off when the target entered melee range: %s" % friendly_in_range)

	ada.global_position = ada_position
	ada.velocity = Vector3.ZERO
	enemy_actor.global_position = enemy_position
	enemy_actor.velocity = Vector3.ZERO
	enemy = combat._active_enemies.get(enemy_id, {})
	enemy["position"] = enemy_position
	enemy["target"] = {}
	combat._active_enemies[enemy_id] = enemy
	combat._advance_enemy_ai(0.1, 0.1)
	var enemy_before := enemy_actor.debug_get_motion_snapshot()
	var enemy_request_id := str(enemy_before.get("request_id", ""))
	_check(bool(enemy_before.get("active", false)) and bool(enemy_before.get("persistent_repath", false)), "T0200 enemy combat did not start persistent navigation: %s" % enemy_before)

	var moved_ada_position := NavigationServer3D.map_get_closest_point(navigation_map, ada_position + Vector3(0.0, 0.0, 2.0))
	ada.global_position = moved_ada_position
	combat._advance_enemy_ai(0.1, 0.1)
	var enemy_after := enemy_actor.debug_get_motion_snapshot()
	_check(str(enemy_after.get("request_id", "")) == enemy_request_id, "T0200 enemy target movement replaced the authority request instead of updating it: %s -> %s" % [enemy_before, enemy_after])
	_check(int(enemy_after.get("target_update_count", 0)) > int(enemy_before.get("target_update_count", 0)), "T0200 enemy pursuit kept walking to the stale target position: %s" % enemy_after)

	var enemy_target: Dictionary = combat.debug_get_enemy_target(enemy_id)
	var policy := combat.debug_get_enemy_targeting_snapshot().get("combat_navigation_policy", {}) as Dictionary
	_check(str(enemy_target.get("id", "")) == NPC_ID, "T0200 navigation update changed the enemy's authority target: %s" % enemy_target)
	_check(str(policy.get("schema", "")) == "shared_combat_navigation_v1", "T0200 shared navigation policy missing: %s" % policy)
	_check(not bool(policy.get("roads_affect_navigation", true)), "T0200 roads entered combat path cost: %s" % policy)

	var result := {
		"policy": policy,
		"friendly_request_preserved": str(friendly_after.get("request_id", "")) == friendly_request_id,
		"friendly_target_updates": friendly_after.get("target_update_count", 0),
		"friendly_stopped_in_range": not bool(friendly_in_range.get("active", true)),
		"enemy_request_preserved": str(enemy_after.get("request_id", "")) == enemy_request_id,
		"enemy_target_updates": enemy_after.get("target_update_count", 0),
		"enemy_locked_target": enemy_target.get("id", ""),
		"melee_standoff": melee_standoff,
		"ranged_standoff": ranged_standoff
	}
	combat.clear_spawned_enemies()
	return result


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0200_SHARED_COMBAT_NAVIGATION_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
