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
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var device_system := root.get_node_or_null("Main/Systems/DefenseDeviceSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	_check(not [combat, npc_system, device_system, building_system, resource_system, time_system].has(null), "T0243 dependencies missing")
	if not _failures.is_empty():
		_finish()
		return
	time_system.set_paused(true)

	var started: Dictionary = combat.debug_run_formal_dynamic_wave_slice(1, true)
	_check(bool(started.get("ok", false)), "T0243 could not spawn production enemies: %s" % started)
	var enemy_ids: Array[String] = combat.get_active_enemy_ids()
	_check(enemy_ids.size() >= 2, "T0243 needs two live enemy bodies")
	if enemy_ids.size() < 2:
		_finish()
		return
	for index in range(2, enemy_ids.size()):
		combat._remove_enemy_from_combat(enemy_ids[index])
	var selector_id := enemy_ids[0]
	var occupant_id := enemy_ids[1]
	var selector_actor := root.get_node_or_null(combat._formal_first_wave_node_paths.get(selector_id, NodePath())) as ActorMotionBody
	var occupant_actor := root.get_node_or_null(combat._formal_first_wave_node_paths.get(occupant_id, NodePath())) as Node3D
	_check(selector_actor != null and occupant_actor != null, "T0243 production enemy actors missing")
	if selector_actor == null or occupant_actor == null:
		_finish()
		return

	var target: Dictionary = combat._make_building_target("front_gate")
	var selector: Dictionary = combat.get_enemy(selector_id)
	var candidates: Array[Dictionary] = combat._get_enemy_attack_position_candidates(selector_id, selector, target)
	_check(str(combat._formal_attack_position_policy.get("schema", "")) == "enemy_attack_guidance_zones_v2", "T0243 guidance schema is not active")
	_check(candidates.size() == 5, "T0243 front gate melee guidance expected five zones, got %d" % candidates.size())
	_verify_zone_contract(candidates, float(selector.get("attack_range", 0.0)), "front_gate")
	if candidates.is_empty():
		_finish()
		return

	# A real capsule intersecting the vertical zone cylinder counts; no reservation
	# or target intent is written for the occupant.
	var crowded_zone := candidates[0]
	_set_enemy_position(combat, occupant_id, occupant_actor, crowded_zone.get("position", Vector3.ZERO))
	var crowded_occupancy: Dictionary = combat._get_enemy_guidance_zone_occupancy(crowded_zone)
	_check(int(crowded_occupancy.get("count", 0)) >= 1, "T0243 physical cylinder overlap was not counted: %s" % crowded_occupancy)
	_check((crowded_occupancy.get("enemy_ids", []) as Array).has(occupant_id), "T0243 overlapping enemy id missing from occupancy: %s" % crowded_occupancy)

	var crowded_position: Vector3 = crowded_zone.get("position", Vector3.ZERO)
	var selector_start := crowded_position + Vector3(0.0, 0.0, 0.15)
	_set_enemy_position(combat, selector_id, selector_actor, selector_start)
	var self_excluded_occupancy: Dictionary = combat._get_enemy_guidance_zone_occupancy(crowded_zone, selector_id)
	_check(int(self_excluded_occupancy.get("count", -1)) == 1, "T0243 selector was counted in its own guidance zone: %s" % self_excluded_occupancy)
	_check(not (self_excluded_occupancy.get("enemy_ids", []) as Array).has(selector_id), "T0243 selector id remained in self-excluded occupancy: %s" % self_excluded_occupancy)
	_check((self_excluded_occupancy.get("enemy_ids", []) as Array).has(occupant_id), "T0243 self exclusion also removed the other physical occupant: %s" % self_excluded_occupancy)

	# Enemy combat requests may be superseded by a moving guide or a target refresh.
	# The continuous-stall clock must survive that handoff instead of restarting.
	selector_actor.set("_stationary_elapsed_seconds", 1.5)
	var preserve_options: Dictionary = combat._get_combat_motion_options("enemy_building_approach")
	selector_actor.request_motion(selector_start + Vector3(0.4, 0.0, 0.0), "t0249_stationary_supersede_probe", preserve_options)
	var preserve_snapshot: Dictionary = selector_actor.debug_get_motion_snapshot()
	_check(float(preserve_snapshot.get("stationary_elapsed_seconds", 0.0)) >= 1.49, "T0243 combat supersede reset the stationary timer: %s" % preserve_snapshot)
	_check(int(preserve_snapshot.get("stationary_supersede_preserve_count", 0)) >= 1, "T0243 combat supersede preservation was not observable: %s" % preserve_snapshot)
	selector_actor.cancel_motion("t0249_probe_complete")
	selector = combat.get_enemy(selector_id)
	var first_guidance: Dictionary = combat._ensure_enemy_attack_position(selector_id, selector, target, true)
	_check(str(first_guidance.get("attack_position_status", "")) == "guiding", "T0243 selector entered a lease/wait state: %s" % first_guidance)
	_check(str(first_guidance.get("attack_position_id", "")) != str(crowded_zone.get("slot_id", "")), "T0243 chose the nearest crowded zone instead of an empty zone: %s" % first_guidance)
	_check(int(first_guidance.get("attack_guidance_occupancy_count", -1)) == 0, "T0243 did not choose a minimum-occupancy zone: %s" % first_guidance)
	_check((combat._enemy_attack_wait_queues as Dictionary).is_empty(), "T0243 guidance unexpectedly created a waiter queue")

	# Move the other real body into the selected zone. The next authoritative
	# selection must immediately change the motion guide while retaining the same
	# combat target identity.
	var first_slot_id := str(first_guidance.get("attack_position_id", ""))
	var first_position: Vector3 = first_guidance.get("attack_position", selector_start)
	_set_enemy_position(combat, occupant_id, occupant_actor, first_position)
	selector = combat.get_enemy(selector_id)
	var second_guidance: Dictionary = combat._ensure_enemy_attack_position(selector_id, selector, target, true)
	_check(str(second_guidance.get("id", "")) == "front_gate", "T0243 density switch changed the locked target")
	_check(str(second_guidance.get("attack_position_id", "")) != first_slot_id, "T0243 did not switch after the selected zone became crowded: %s" % second_guidance)
	_check(int(combat._enemy_attack_position_metrics.get("guidance_zone_switches", 0)) >= 1, "T0243 guidance switch metric was not recorded")

	# Enter the range of a real contact surface while the least-crowded guide is a
	# different circle. The combat step must stop chasing the circle and attack.
	candidates = combat._get_enemy_attack_position_candidates(selector_id, combat.get_enemy(selector_id), target)
	var handoff_candidate := candidates[0]
	var handoff_contact: Vector3 = handoff_candidate.get("contact_position", Vector3.ZERO)
	var handoff_center: Vector3 = handoff_candidate.get("position", handoff_contact + Vector3.FORWARD)
	var outward := handoff_center - handoff_contact
	outward.y = 0.0
	outward = outward.normalized() if outward.length_squared() > 0.0001 else Vector3.FORWARD
	var handoff_position := handoff_contact + outward * minf(1.0, float(selector.get("attack_range", 1.5)) * 0.75)
	_set_enemy_position(combat, selector_id, selector_actor, handoff_position)
	_set_enemy_position(combat, occupant_id, occupant_actor, handoff_center)
	selector = combat.get_enemy(selector_id)
	selector["target"] = target.duplicate(true)
	selector["target_priority"] = 3
	selector["target_selection_reason"] = "t0243_locked_front_gate"
	selector["current_action"] = "pressing_to_front_gate"
	combat._active_enemies[selector_id] = selector
	_move_npcs_away(npc_system, handoff_position)
	var single_enemy: Array[String] = [selector_id]
	combat._advance_enemy_ai(0.05, 0.05, single_enemy)
	var after_handoff: Dictionary = combat.get_enemy(selector_id)
	var handoff_target := after_handoff.get("target", {}) as Dictionary
	var selected_center: Vector3 = handoff_target.get("attack_position", handoff_position)
	var center_distance := Vector2(handoff_position.x, handoff_position.z).distance_to(Vector2(selected_center.x, selected_center.z))
	var handoff_action := str(after_handoff.get("current_action", ""))
	_check(handoff_action in ["attacking_front_gate", "winding_up_front_gate", "recovering_from_front_gate_attack"], "T0243 remained in pressing state despite hurtbox range: %s" % handoff_action)
	_check(str(handoff_target.get("attack_position_status", "")) == "in_range", "T0243 range handoff did not replace guiding state: %s" % handoff_target)
	_check(center_distance > float(combat._formal_attack_position_policy.get("arrival_tolerance", 0.32)), "T0243 handoff probe accidentally reached the guidance center: %.3f" % center_distance)

	# A deployed defense target uses the same guide contract.
	_set_building_level(building_system, "wall", 4)
	resource_system.add_resource("item_wall_ballista", 1)
	var deployed: Dictionary = device_system.deploy_device("wall_ballista", "wall_slot_01")
	_check(bool(deployed.get("ok", false)), "T0243 representative defense deployment failed: %s" % deployed)
	var deployment_id := str(deployed.get("deployment_id", ""))
	var device_target: Dictionary = combat._make_defense_device_enemy_target(deployment_id, handoff_position)
	var device_candidates: Array[Dictionary] = combat._get_enemy_attack_position_candidates(selector_id, combat.get_enemy(selector_id), device_target)
	_check(not device_candidates.is_empty(), "T0243 defense target has no guidance zones")
	_verify_zone_contract(device_candidates, float(selector.get("attack_range", 0.0)), "defense_device")
	var device_guidance: Dictionary = combat._ensure_enemy_attack_position(selector_id, combat.get_enemy(selector_id), device_target, true)
	_check(str(device_guidance.get("attack_position_status", "")) == "guiding", "T0243 defense target did not use guidance: %s" % device_guidance)

	var snapshot: Dictionary = combat.debug_get_enemy_attack_position_snapshot()
	_check(str(snapshot.get("schema", "")) == "enemy_attack_guidance_zones_v2", "T0243 GM snapshot schema missing")
	_check(int(snapshot.get("waiter_count", -1)) == 0, "T0243 snapshot still contains attack-position waiters: %s" % snapshot)
	_check(int(snapshot.get("guidance_count", 0)) >= 1, "T0243 snapshot has no live guidance assignment: %s" % snapshot)
	print("T0243_GUIDED_ATTACK_ZONE_DIAGNOSTICS %s" % JSON.stringify({
		"first_zone": first_slot_id,
		"second_zone": str(second_guidance.get("attack_position_id", "")),
		"handoff_center_distance": center_distance,
		"metrics": snapshot.get("metrics", {}),
		"device_zone_count": device_candidates.size()
	}))
	combat.clear_spawned_enemies()
	_finish()


func _verify_zone_contract(candidates: Array[Dictionary], attack_range: float, label: String) -> void:
	for index in range(candidates.size()):
		var candidate := candidates[index]
		_check(str(candidate.get("guidance_class", "")) in ["melee", "ranged"], "T0243 %s zone lacks melee/ranged class: %s" % [label, candidate])
		var radius := float(candidate.get("guidance_zone_radius", 0.0))
		_check(radius >= 0.4 and radius <= 0.7, "T0243 %s zone is not one body radius: %.3f" % [label, radius])
		_check(float(candidate.get("guidance_zone_height", 0.0)) >= 2.25, "T0243 %s cylinder is too short" % label)
		var position: Vector3 = candidate.get("position", Vector3.ZERO)
		var contact: Vector3 = candidate.get("contact_position", position)
		_check(Vector2(position.x, position.z).distance_to(Vector2(contact.x, contact.z)) <= attack_range + 0.001, "T0243 %s zone center cannot attack its contact surface" % label)
		for other_index in range(index + 1, candidates.size()):
			var other := candidates[other_index]
			var other_position: Vector3 = other.get("position", Vector3.ZERO)
			var minimum_distance := radius + float(other.get("guidance_zone_radius", 0.0))
			_check(Vector2(position.x, position.z).distance_to(Vector2(other_position.x, other_position.z)) + 0.0001 >= minimum_distance, "T0243 %s guidance circles overlap: %s / %s" % [label, candidate.get("slot_id", ""), other.get("slot_id", "")])


func _move_npcs_away(npc_system: Node, origin: Vector3) -> void:
	for raw_npc_id in npc_system.get_npc_ids():
		var npc_id := str(raw_npc_id)
		npc_system.set_npc_equipment_slot(npc_id, "main_weapon", {})
		var actor := root.get_node_or_null(npc_system._npc_nodes.get(npc_id, NodePath())) as Node3D
		if actor != null:
			actor.global_position = origin + Vector3(100.0, 0.0, 100.0)


func _set_enemy_position(combat: Node, enemy_id: String, actor: Node3D, position: Vector3) -> void:
	actor.global_position = position
	var enemy: Dictionary = combat.get_enemy(enemy_id)
	enemy["position"] = position
	combat._active_enemies[enemy_id] = enemy


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
		print("T0243_GUIDED_ATTACK_ZONES_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
