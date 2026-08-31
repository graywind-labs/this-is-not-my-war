extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")

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

	var combat := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var device_system := root.get_node_or_null("Main/Systems/DefenseDeviceSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	_check(combat != null and npc_system != null and device_system != null, "T0207 combat dependencies missing")
	_check(building_system != null and resource_system != null and time_system != null, "T0207 world dependencies missing")
	if not _failures.is_empty():
		_finish()
		return
	time_system.set_paused(true)

	var started: Dictionary = combat.debug_run_formal_dynamic_wave_slice(1, true)
	_check(bool(started.get("ok", false)), "T0207 formal wave failed to spawn: %s" % started)
	var enemy_ids: Array[String] = combat.get_active_enemy_ids()
	_check(enemy_ids.size() >= 2, "T0207 needs two production enemies")
	if not _failures.is_empty():
		_finish()
		return
	for index in range(2, enemy_ids.size()):
		combat._remove_enemy_from_combat(enemy_ids[index])
	var lease_profile_enemy_id := enemy_ids[0]
	var selecting_enemy_id := enemy_ids[1]
	var selecting_actor := root.get_node_or_null(combat._formal_first_wave_node_paths.get(selecting_enemy_id, NodePath())) as Node3D
	_check(selecting_actor != null, "T0207 selecting enemy actor missing")

	_set_building_level(building_system, "wall", 4)
	resource_system.add_resource("item_wall_ballista", 1)
	var deployed: Dictionary = device_system.deploy_device("wall_ballista", "wall_slot_01")
	_check(bool(deployed.get("ok", false)), "T0207 ballista deployment failed: %s" % deployed)
	var deployment_id := str(deployed.get("deployment_id", ""))
	var device_target: Dictionary = combat._make_defense_device_enemy_target(deployment_id, Vector3.ZERO)
	_check(not device_target.is_empty(), "T0207 defense-device target missing")
	if not _failures.is_empty():
		_finish()
		return
	if str(combat._formal_attack_position_policy.get("schema", "")) == "enemy_attack_guidance_zones_v2":
		var selecting_enemy: Dictionary = combat.get_enemy(selecting_enemy_id)
		var opportunity: Dictionary = combat._preview_enemy_target_opportunity(selecting_enemy_id, selecting_enemy, device_target)
		var guided: Dictionary = combat._ensure_enemy_attack_position(selecting_enemy_id, selecting_enemy, device_target, true)
		_check(bool(opportunity.get("available", false)) and str(opportunity.get("reason", "")) == "reachable_guidance_zone", "T0207/T0243 target was capacity-gated: %s" % opportunity)
		_check(str(guided.get("attack_position_status", "")) == "guiding", "T0207/T0243 target did not return guidance: %s" % guided)
		_check((combat._enemy_attack_wait_queues as Dictionary).is_empty(), "T0207/T0243 created a waiter from guidance")
		combat.clear_spawned_enemies()
		_finish()
		return

	var device_position: Vector3 = device_target.get("position", Vector3.ZERO)
	var outward: Vector3 = device_target.get("facing_direction", Vector3.FORWARD)
	outward.y = 0.0
	outward = outward.normalized() if outward.length_squared() > 0.0001 else Vector3.FORWARD
	_set_enemy_position(combat, selecting_enemy_id, selecting_actor, device_position + outward * 8.0)
	for npc_id in npc_system.get_npc_ids():
		npc_system.set_npc_equipment_slot(npc_id, "main_weapon", {})
		var npc_actor := root.get_node_or_null(npc_system._npc_nodes.get(npc_id, NodePath())) as Node3D
		if npc_actor != null:
			npc_actor.global_position = device_position + Vector3(80.0, 0.0, 80.0)

	var profile_enemy: Dictionary = combat.get_enemy(lease_profile_enemy_id)
	var target_key: String = combat._enemy_attack_target_key(device_target)
	var inserted_slots: Array[String] = []
	var candidate_index := 0
	for raw_candidate in combat._get_enemy_attack_position_candidates(lease_profile_enemy_id, profile_enemy, device_target):
		var lease := (raw_candidate as Dictionary).duplicate(true)
		var fake_slot_id := "t0207_reserved_%03d" % candidate_index
		lease["slot_id"] = fake_slot_id
		lease["enemy_id"] = "t0207_in_transit_%03d" % candidate_index
		lease["target_key"] = target_key
		lease["status"] = "reserved"
		combat._enemy_attack_position_leases[fake_slot_id] = lease
		inserted_slots.append(fake_slot_id)
		candidate_index += 1
	_check(not inserted_slots.is_empty(), "T0207 defense target produced no attack positions")

	var selecting_enemy: Dictionary = combat.get_enemy(selecting_enemy_id)
	var reserved_opportunity: Dictionary = combat._preview_enemy_target_opportunity(selecting_enemy_id, selecting_enemy, device_target)
	_check(bool(reserved_opportunity.get("available", false)), "T0207 in-transit reservations incorrectly removed the target: %s" % reserved_opportunity)
	_check(str(reserved_opportunity.get("reason", "")) == "reserved_in_transit", "T0207 reservation state was not distinguished from occupancy: %s" % reserved_opportunity)
	var selected_reserved := _fresh_select(combat, selecting_enemy_id)
	_check(str(selected_reserved.get("id", "")) == deployment_id, "T0207 reserved target was skipped during targeting: %s" % selected_reserved)
	var waiting: Dictionary = combat._ensure_enemy_attack_position(selecting_enemy_id, combat.get_enemy(selecting_enemy_id), selected_reserved, true)
	_check(str(waiting.get("attack_position_status", "")) == "waiting", "T0207 later enemy did not wait behind in-transit reservations: %s" % waiting)
	_check(str(waiting.get("attack_position_wait_reason", "")) == "reserved_in_transit", "T0207 waiter lost its in-transit reason: %s" % waiting)
	var wait_position: Vector3 = waiting.get("attack_position", selecting_actor.global_position)
	_check(not str(waiting.get("attack_position_wait_target_id", "")).is_empty(), "T0207 waiter did not retain a desired real attack position: %s" % waiting)
	_check(str(waiting.get("attack_position_wait_movement_policy", "")) == "pressure_assigned_attack_position", "T0207 waiter did not use attack-position pressure movement: %s" % waiting)
	_check(Vector2(wait_position.x, wait_position.z).distance_to(Vector2(selecting_actor.global_position.x, selecting_actor.global_position.z)) > 0.5, "T0207 in-transit waiter still held its entry position instead of advancing: %s" % waiting)
	_check(not combat._enemy_attack_position_by_enemy.has(selecting_enemy_id), "T0207 waiter incorrectly received an attack-position lease")

	# Partial arrival is still not full: at least one compatible slot remains only
	# reserved until its owning actor physically reaches it.
	for index in range(maxi(0, inserted_slots.size() - 1)):
		_set_fake_lease_status(combat, inserted_slots[index], "occupied")
	var partial_opportunity: Dictionary = combat._preview_enemy_target_opportunity(selecting_enemy_id, combat.get_enemy(selecting_enemy_id), device_target)
	_check(str(partial_opportunity.get("reason", "")) != "full", "T0207 partial physical occupancy was treated as full: %s" % partial_opportunity)

	_set_fake_lease_status(combat, inserted_slots[-1], "occupied")
	var occupied_opportunity: Dictionary = combat._preview_enemy_target_opportunity(selecting_enemy_id, combat.get_enemy(selecting_enemy_id), device_target)
	_check(not bool(occupied_opportunity.get("available", true)) and str(occupied_opportunity.get("reason", "")) == "full", "T0207 fully occupied target did not become full: %s" % occupied_opportunity)
	var selected_occupied := _fresh_select(combat, selecting_enemy_id)
	_check(str(selected_occupied.get("id", "")) == "front_gate", "T0207 fully occupied defense target did not leave the candidate pool: %s" % selected_occupied)

	print("T0207_ATTACK_POSITION_OCCUPANCY_DIAGNOSTICS %s" % JSON.stringify({
		"reserved_opportunity": reserved_opportunity,
		"partial_opportunity": partial_opportunity,
		"occupied_opportunity": occupied_opportunity,
		"reserved_selection": selected_reserved,
		"occupied_selection": selected_occupied,
		"slot_count": inserted_slots.size()
	}))
	for slot_id in inserted_slots:
		combat._enemy_attack_position_leases.erase(slot_id)
	combat.clear_spawned_enemies()
	_finish()


func _fresh_select(combat: Node, enemy_id: String) -> Dictionary:
	combat._release_enemy_attack_position(enemy_id, "t0207_fresh_select", false, false)
	combat._remove_enemy_from_attack_wait_queues(enemy_id)
	var enemy: Dictionary = combat.get_enemy(enemy_id)
	enemy["target"] = {}
	enemy["target_priority"] = 0
	enemy["target_selection_reason"] = ""
	combat._active_enemies[enemy_id] = enemy
	return combat._select_formal_dynamic_enemy_target(enemy_id, enemy)


func _set_fake_lease_status(combat: Node, slot_id: String, status: String) -> void:
	var lease := combat._enemy_attack_position_leases.get(slot_id, {}) as Dictionary
	lease["status"] = status
	combat._enemy_attack_position_leases[slot_id] = lease


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
		print("T0207_ATTACK_POSITION_ACTUAL_OCCUPANCY_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
