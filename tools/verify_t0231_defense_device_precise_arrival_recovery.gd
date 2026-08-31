extends SceneTree


const MAIN_SCENE := preload("res://scenes/main/Main.tscn")

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup.set("_startup_running", true)
	root.add_child(main)
	for _frame in range(4):
		await process_frame
		await physics_frame

	var combat := root.get_node_or_null("Main/Systems/CombatSystem")
	var devices := root.get_node_or_null("Main/Systems/DefenseDeviceSystem")
	var buildings := root.get_node_or_null("Main/Systems/BuildingSystem")
	var resources := root.get_node_or_null("Main/Systems/ResourceSystem")
	var npcs := root.get_node_or_null("Main/Systems/NPCSystem")
	var time := root.get_node_or_null("Main/Systems/TimeSystem")
	_check(not [combat, devices, buildings, resources, npcs, time].has(null), "T0231 required production systems are missing")
	if not _failures.is_empty():
		_finish()
		return
	time.set_paused(true)
	_set_building_level(buildings, "main_hall", 6)
	resources.add_resource("item_wall_ballista", 1)
	var deployed: Dictionary = devices.deploy_device("wall_ballista", "main_hall_slot_03")
	_check(bool(deployed.get("ok", false)), "T0231 main-hall slot03 ballista deployment failed: %s" % deployed)
	var deployment_id := str(deployed.get("deployment_id", ""))
	for index in range(npcs.get_npc_ids().size()):
		var npc_id := str(npcs.get_npc_ids()[index])
		var npc_node := root.get_node_or_null(npcs.get("_npc_nodes").get(npc_id, NodePath())) as Node3D
		if npc_node != null:
			npc_node.global_position = Vector3(45.0 + index * 1.5, 0.0, -40.0)

	var started: Dictionary = combat.debug_run_formal_dynamic_wave_slice(1, true)
	_check(bool(started.get("ok", false)), "T0231 formal enemies failed to spawn: %s" % started)
	if not _failures.is_empty():
		_finish()
		return
	var enemy_id := _find_melee_enemy_id(combat)
	var enemy: Dictionary = combat.get_enemy(enemy_id)
	var node_paths: Dictionary = combat.get("_formal_first_wave_node_paths")
	var actor := root.get_node_or_null(node_paths.get(enemy_id, NodePath())) as ActorMotionBody
	_check(not enemy_id.is_empty() and actor != null, "T0231 could not find a formal melee ActorMotionBody")
	if not _failures.is_empty():
		_finish()
		return

	var slices: Dictionary = combat.get("_formal_first_wave_slices")
	var slice: Dictionary = slices.get(enemy_id, {})
	slice["phase"] = "main_hall_reached"
	slice["movement_model"] = "dynamic_combat_pressure"
	slice["attack_unlocked"] = true
	slices[enemy_id] = slice
	combat.set("_formal_first_wave_slices", slices)
	var raw_target: Dictionary = combat._make_defense_device_enemy_target(deployment_id, enemy.get("position", Vector3.ZERO))
	var target: Dictionary = combat._ensure_enemy_attack_position(enemy_id, enemy, raw_target)
	if str(combat._formal_attack_position_policy.get("schema", "")) == "enemy_attack_guidance_zones_v2":
		_check(str(target.get("attack_position_status", "")) == "guiding", "T0231/T0243 defense target did not receive guidance: %s" % target)
		_check(combat._has_enemy_reached_attack_position(enemy_id, target), "T0231/T0243 guidance was incorrectly used as attack permission")
		_check((combat.debug_get_enemy_attack_position_snapshot().get("precise_arrival_recoveries", []) as Array).is_empty(), "T0231/T0243 guidance entered obsolete precise-arrival recovery")
		_check((combat._enemy_attack_wait_queues as Dictionary).is_empty(), "T0231/T0243 guidance created a waiter queue")
		combat.clear_spawned_enemies()
		_finish()
		return
	_check(str(target.get("attack_position_status", "")) == "reserved", "T0231 did not reserve a main-hall defense-device attack point: %s" % target)
	_check(str(target.get("attack_host_proxy_building_segment_id", "")) in ["front_left", "left_wall"], "T0231 slot03 lease did not use either authorized wall region: %s" % target)
	if not _failures.is_empty():
		_finish()
		return

	var attack_position: Vector3 = target.get("attack_position", actor.global_position)
	var outward: Vector3 = target.get("attack_host_proxy_outward_direction", Vector3.FORWARD)
	outward.y = 0.0
	outward = outward.normalized()
	actor.global_position = attack_position + outward * 0.25
	enemy["position"] = actor.global_position
	enemy["target"] = target.duplicate(true)
	var active: Dictionary = combat.get("_active_enemies")
	active[enemy_id] = enemy
	combat.set("_active_enemies", active)
	combat._ensure_formal_dynamic_pressure_motion(enemy_id, target)
	actor.set_motion_paused(false)
	actor.set("_stuck_elapsed_seconds", 1.0)

	var prematurely_reached: bool = combat._has_enemy_reached_attack_position(enemy_id, target)
	var recovery_snapshot: Dictionary = combat.debug_get_enemy_attack_position_snapshot()
	var motion_during: Dictionary = actor.debug_get_motion_snapshot()
	_check(not prematurely_reached, "T0231 safe-radius recovery incorrectly granted attack permission before precise contact")
	_check(not bool(motion_during.get("avoidance_enabled", true)), "T0231 stalled final approach did not suppress RVO avoidance: %s" % motion_during)
	_check((recovery_snapshot.get("precise_arrival_recoveries", []) as Array).size() == 1, "T0231 recovery was not exposed in diagnostics: %s" % recovery_snapshot)
	_check(int((recovery_snapshot.get("metrics", {}) as Dictionary).get("precise_arrival_recoveries_started", 0)) == 1, "T0231 recovery start metric missing: %s" % recovery_snapshot)

	actor.global_position = attack_position + outward * 0.03
	enemy["position"] = actor.global_position
	active = combat.get("_active_enemies")
	active[enemy_id] = enemy
	combat.set("_active_enemies", active)
	var precisely_reached: bool = combat._has_enemy_reached_attack_position(enemy_id, target)
	var completed_snapshot: Dictionary = combat.debug_get_enemy_attack_position_snapshot()
	var motion_after: Dictionary = actor.debug_get_motion_snapshot()
	var completed_lease := _find_enemy_lease(completed_snapshot, enemy_id)
	_check(precisely_reached, "T0231 precise arrival was not accepted")
	_check(bool(motion_after.get("avoidance_enabled", false)), "T0231 RVO avoidance was not restored after precise arrival: %s" % motion_after)
	_check(str(completed_lease.get("status", "")) == "occupied", "T0231 lease was not promoted to occupied: %s" % completed_lease)
	_check(str(completed_lease.get("arrival_mode", "")) == "precise_after_avoidance_recovery", "T0231 lease lost its recovery handoff diagnostic: %s" % completed_lease)
	_check(int((completed_snapshot.get("metrics", {}) as Dictionary).get("precise_arrival_recoveries_completed", 0)) == 1, "T0231 completion metric missing: %s" % completed_snapshot)

	var selected_ids: Array[String] = [enemy_id]
	combat._advance_enemy_ai(0.1, 0.1, selected_ids)
	var action_after := str(combat.get_enemy(enemy_id).get("current_action", ""))
	_check(not action_after.begins_with("pressing_to_"), "T0231 precise attacker stayed in pressing after handoff: %s" % action_after)

	combat._release_enemy_attack_position(enemy_id, "t0231_far_guard")
	enemy = combat.get_enemy(enemy_id)
	target = combat._ensure_enemy_attack_position(enemy_id, enemy, raw_target, true)
	attack_position = target.get("attack_position", actor.global_position)
	actor.global_position = attack_position + outward * 0.60
	combat._ensure_formal_dynamic_pressure_motion(enemy_id, target)
	actor.set_motion_paused(false)
	actor.set("_stuck_elapsed_seconds", 2.0)
	_check(not combat._has_enemy_reached_attack_position(enemy_id, target), "T0231 far attacker incorrectly reached its point")
	_check(bool(actor.debug_get_motion_snapshot().get("avoidance_enabled", false)), "T0231 far attacker incorrectly disabled avoidance")
	_check((combat.debug_get_enemy_attack_position_snapshot().get("precise_arrival_recoveries", []) as Array).is_empty(), "T0231 far attacker incorrectly entered precise recovery")

	combat.clear_spawned_enemies()
	_finish()


func _find_melee_enemy_id(combat: Node) -> String:
	for enemy_id in combat.get_active_enemy_ids():
		var enemy: Dictionary = combat.get_enemy(enemy_id)
		if str(enemy.get("weapon_type", "")) in ["unarmed", "sword_shield", "polearm"]:
			return enemy_id
	return ""


func _find_enemy_lease(snapshot: Dictionary, enemy_id: String) -> Dictionary:
	for raw_lease in snapshot.get("leases", []):
		var lease := raw_lease as Dictionary
		if str(lease.get("enemy_id", "")) == enemy_id:
			return lease
	return {}


func _set_building_level(building_system: Node, building_id: String, level: int) -> void:
	var all_buildings: Dictionary = building_system.get("_buildings")
	var building: Dictionary = all_buildings.get(building_id, {})
	building["level"] = level
	all_buildings[building_id] = building
	building_system.set("_buildings", all_buildings)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0231_DEFENSE_DEVICE_PRECISE_ARRIVAL_RECOVERY_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
