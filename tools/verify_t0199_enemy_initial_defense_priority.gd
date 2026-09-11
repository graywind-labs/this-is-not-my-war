extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const UNIFIED_RANGE := 37.2

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	for _frame in range(4):
		await process_frame
		await physics_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var device_system := root.get_node_or_null("Main/Systems/DefenseDeviceSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	_check(combat_system != null and npc_system != null and device_system != null, "T0199 combat systems missing")
	_check(building_system != null and resource_system != null, "T0199 world systems missing")
	if not _failures.is_empty():
		_finish()
		return

	var slot_id := OS.get_environment("T0199_SLOT")
	if slot_id.is_empty():
		slot_id = "wall_slot_01"
	_set_building_level(building_system, "wall", 6)
	_set_building_level(building_system, "main_hall", 6)
	resource_system.add_resource("item_wall_ballista", 1)
	var deployed: Dictionary = device_system.deploy_device("wall_ballista", slot_id)
	_check(bool(deployed.get("ok", false)), "T0199 ballista deployment failed for %s: %s" % [slot_id, deployed])
	if not _failures.is_empty():
		_finish()
		return
	var deployment_id := str(deployed.get("deployment_id", ""))
	var device_target: Dictionary = combat_system._make_defense_device_enemy_target(deployment_id, Vector3.ZERO)
	_check(not device_target.is_empty(), "T0199 deployed ballista absent from active enemy target source: %s" % deployed)
	if not _failures.is_empty():
		_finish()
		return

	for npc_id in npc_system.get_npc_ids():
		npc_system.set_npc_equipment_slot(str(npc_id), "main_weapon", {})
		var npc_node := root.get_node_or_null(npc_system._npc_nodes.get(str(npc_id), NodePath())) as Node3D
		if npc_node != null:
			npc_node.global_position = Vector3(-50.0, 0.0, -40.0)

	var started: Dictionary = combat_system.debug_run_formal_dynamic_wave_slice(1, true)
	_check(bool(started.get("ok", false)), "T0199 formal wave failed to spawn: %s" % started)
	var enemy_ids: Array[String] = combat_system.get_active_enemy_ids()
	_check(not enemy_ids.is_empty(), "T0199 needs a production enemy")
	if not _failures.is_empty():
		_finish()
		return
	for index in range(1, enemy_ids.size()):
		combat_system._remove_enemy_from_combat(enemy_ids[index])
	var enemy_id := enemy_ids[0]
	var actor := root.get_node_or_null(combat_system._formal_first_wave_node_paths.get(enemy_id, NodePath())) as Node3D
	var device_position: Vector3 = device_target.get("position", Vector3.ZERO)
	var outward: Vector3 = device_target.get("facing_direction", Vector3.FORWARD)
	outward.y = 0.0
	if outward.length_squared() <= 0.0001:
		outward = Vector3.FORWARD
	outward = outward.normalized()
	var enemy_position := device_position + outward * (UNIFIED_RANGE - 0.2)
	if actor != null:
		actor.global_position = enemy_position
	var enemy: Dictionary = combat_system.get_enemy(enemy_id)
	enemy["position"] = enemy_position
	enemy["target"] = combat_system._make_building_target("front_gate")
	enemy["target_priority"] = 3
	combat_system._active_enemies[enemy_id] = enemy
	combat_system._release_enemy_attack_position(enemy_id, "t0199_initial_priority", false, false)

	var refreshed_device: Dictionary = combat_system._make_defense_device_enemy_target(deployment_id, enemy_position)
	var candidate_paths: Array[Dictionary] = []
	if actor is ActorMotionBody:
		var actor_body := actor as ActorMotionBody
		var navigation_map := actor_body.get_navigation_map()
		for raw_candidate in combat_system._get_enemy_attack_position_candidates(enemy_id, enemy, refreshed_device):
			var candidate := raw_candidate as Dictionary
			var resolved: Dictionary = combat_system._resolve_reachable_enemy_attack_position(enemy_id, candidate)
			var resolved_position: Vector3 = resolved.get("position", candidate.get("position", actor_body.global_position))
			var path := NavigationServer3D.map_get_path(navigation_map, actor_body.global_position, resolved_position, true) if not resolved.is_empty() else PackedVector3Array()
			var minimum_path_z := INF
			for path_point in path:
				minimum_path_z = minf(minimum_path_z, path_point.z)
			candidate_paths.append({
				"slot_id": candidate.get("slot_id", ""),
				"raw_position": candidate.get("position", Vector3.ZERO),
				"resolved_position": resolved_position,
				"direct_distance": actor_body.global_position.distance_to(resolved_position),
				"path_distance": resolved.get("path_distance", INF),
				"minimum_path_z": minimum_path_z,
				"path": Array(path)
			})
	var opportunity: Dictionary = combat_system._preview_enemy_target_opportunity(enemy_id, enemy, refreshed_device)
	var groups: Dictionary = combat_system._collect_enemy_target_priority_groups(enemy_id, enemy)
	var selected: Dictionary = combat_system._select_formal_dynamic_enemy_target(enemy_id, enemy)
	var diagnostics := {
		"slot_id": slot_id,
		"deployment_id": deployment_id,
		"device_position": device_position,
		"enemy_position": enemy_position,
		"candidate_paths": candidate_paths,
		"device_distance": refreshed_device.get("distance", INF),
		"device_opportunity": opportunity,
		"high_candidates": groups.get(1, []),
		"selected": selected
	}
	print("T0199_INITIAL_PRIORITY_DIAGNOSTICS %s" % JSON.stringify(diagnostics))
	_check(is_equal_approx(float(refreshed_device.get("distance", INF)), UNIFIED_RANGE - 0.2), "T0199 device distance basis mismatch: %s" % diagnostics)
	_check((groups.get(1, []) as Array).any(func(target: Dictionary) -> bool: return str(target.get("id", "")) == deployment_id), "T0199 active ballista missing from initial high-priority pool: %s" % diagnostics)
	_check(str(selected.get("id", "")) == deployment_id, "T0199 gate lock was not preempted on initial range entry: %s" % diagnostics)
	var shortest_candidate: Dictionary = {}
	for raw_path in candidate_paths:
		var candidate_path := raw_path as Dictionary
		if shortest_candidate.is_empty() or float(candidate_path.get("path_distance", INF)) < float(shortest_candidate.get("path_distance", INF)):
			shortest_candidate = candidate_path
	_check(
		float(shortest_candidate.get("path_distance", INF)) <= float(shortest_candidate.get("direct_distance", 0.0)) * 1.15 + 0.5,
		"T0199 tower path is still being detoured through the front gate: %s" % diagnostics
	)
	_check(
		float(shortest_candidate.get("minimum_path_z", -INF)) >= 53.0,
		"T0199 tower path crossed into the station before returning to the exterior target: %s" % diagnostics
	)

	# The production AI dispatcher must not fall back to the obsolete preference
	# selector when a restored / compatibility slice lacks the dynamic marker.
	var compatibility_slice: Dictionary = combat_system._formal_first_wave_slices.get(enemy_id, {}).duplicate(true)
	compatibility_slice["movement_model"] = "fixed_attack_slots"
	compatibility_slice["phase"] = "front_gate_reached"
	combat_system._formal_first_wave_slices[enemy_id] = compatibility_slice
	enemy = combat_system.get_enemy(enemy_id)
	enemy["hp"] = maxi(100, int(enemy.get("hp", 0)))
	enemy["max_hp"] = maxi(100, int(enemy.get("max_hp", 0)))
	enemy["target"] = combat_system._make_building_target("front_gate")
	enemy["target_priority"] = 3
	combat_system._active_enemies[enemy_id] = enemy
	combat_system._apply_damage_to_enemy(enemy_id, 1, "", {
		"source_type": "defense_device",
		"deployment_id": deployment_id
	})
	_check(combat_system._enemy_high_threat_reacquire_requests.has(enemy_id), "T0199 compatibility enemy dropped defense-device damage rescan")
	combat_system._advance_enemy_ai(0.001, 0.001)
	var dispatched_target: Dictionary = combat_system.get_enemy(enemy_id).get("target", {})
	_check(str(dispatched_target.get("id", "")) == deployment_id, "T0199 compatibility enemy dispatcher bypassed unified defense priority: %s" % dispatched_target)
	combat_system.clear_spawned_enemies()
	_finish()


func _set_building_level(building_system: Node, building_id: String, level: int) -> void:
	var buildings: Dictionary = building_system.get("_buildings")
	var building: Dictionary = buildings.get(building_id, {})
	building["level"] = level
	buildings[building_id] = building
	building_system.set("_buildings", buildings)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0199_ENEMY_INITIAL_DEFENSE_PRIORITY_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
