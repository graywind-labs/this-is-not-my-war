extends SceneTree


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("T0232 failed to load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await physics_frame

	var combat := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var equipment := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var resources := root.get_node_or_null("Main/Systems/ResourceSystem")
	var station := root.get_node_or_null("Main/Presentation/StationLayoutController")
	if combat == null or npc_system == null or equipment == null or resources == null or station == null:
		_fail("T0232 required systems are missing")
		return

	var npc_id := "veteran_deputy_01"
	resources.add_resource("item_bow", 1)
	if not bool(equipment.equip_npc_main_weapon(npc_id, "bow", "local_public").get("ok", false)):
		_fail("T0232 failed to equip bow")
		return
	combat.set_npc_combat_strategy(npc_id, "keep_distance", "private")
	combat.debug_clear_enemies()
	if not bool(combat.debug_spawn_wave(1, true).get("ok", false)):
		_fail("T0232 failed to spawn enemies")
		return
	var enemy_ids: Array = combat.get_active_enemy_ids()
	if enemy_ids.size() < 2:
		_fail("T0232 needs at least two wave enemies")
		return

	# Use the production combat-world spawn, which is already snapped to the
	# outdoor NavigationMap and outside authored building envelopes.
	var origin: Vector3 = npc_system.get_npc_world_position(npc_id)
	var context: Dictionary = combat._calculate_npc_attack_context(
		npc_id,
		npc_system.get_npc(npc_id),
		npc_system.get_npc_state(npc_id)
	)
	var attack_range := float(context.get("range", 0.0))
	if attack_range <= 0.0:
		_fail("T0232 ranged attack context has no range")
		return
	var trigger_range := attack_range / 3.0
	var segment_distance := attack_range * 2.0 / 3.0
	var enemy_a := str(enemy_ids[0])
	var enemy_b := str(enemy_ids[1])
	_set_enemy(combat, enemy_a, origin + Vector3(0.0, 0.0, minf(1.2, trigger_range * 0.3)), 200)
	_set_enemy(combat, enemy_b, origin + Vector3(minf(2.4, trigger_range * 0.6), 0.0, 0.0), 200)
	npc_system.set_npc_behavior_mode(npc_id, "combat", "verify_t0232_foot", {
		"state_changes": {
			"current_action": "combat_ready",
			"combat_mounted": false,
			"combat_mount_phase": "unmounted",
			"combat_target_enemy_id": enemy_a,
			"combat_attack_target_enemy_id": enemy_a,
			"combat_attack_phase": "windup"
		},
		"request_plan_reevaluation": false
	})
	_set_npc_world_position(npc_id, origin)
	var expected_field: Dictionary = combat._build_avoidance_threat_field(origin, trigger_range, npc_id)
	var expected_direction: Vector3 = expected_field.get("direction", Vector3.ZERO)
	var first_hp_a := int(combat.get_enemy(enemy_a).get("hp", 0))
	var first_hp_b := int(combat.get_enemy(enemy_b).get("hp", 0))
	var first: Dictionary = combat._advance_single_npc_combat_attack(npc_id, 0.25)
	var first_state: Dictionary = npc_system.get_npc_state(npc_id)
	if (
		not bool(first_state.get("keep_distance_retreat_active", false))
		or not str(first_state.get("combat_target_enemy_id", "")).is_empty()
		or not str(first_state.get("combat_attack_target_enemy_id", "")).is_empty()
		or str(first_state.get("combat_attack_phase", "")) != "idle"
	):
		_fail("T0232 close threat did not preempt target/windup: %s" % JSON.stringify(first_state))
		return
	var first_move: Dictionary = first.get("strategy_movement", {})
	if not is_equal_approx(float(first_move.get("desired_travel_distance", 0.0)), segment_distance):
		_fail("T0232 first leg is not exactly two-thirds attack range: %s" % JSON.stringify(first_move))
		return
	var first_direction := _dict_to_v3(first_move.get("direction", {}))
	if first_direction.dot(expected_direction) < 0.999:
		_fail("T0232 retreat direction does not reuse weighted avoidance: actual=%s expected=%s" % [first_direction, expected_direction])
		return
	if int(combat.get_enemy(enemy_a).get("hp", 0)) != first_hp_a or int(combat.get_enemy(enemy_b).get("hp", 0)) != first_hp_b:
		_fail("T0232 retreat start dealt damage")
		return
	var committed_target := _dict_to_v3(first_state.get("keep_distance_retreat_target_position", {}))
	var committed_id := str(first_state.get("keep_distance_retreat_target_id", ""))

	# Move old threats and introduce a different close angle during the leg. The
	# endpoint and empty attack lock must remain unchanged until arrival.
	_set_enemy(combat, enemy_a, origin + Vector3(-1.0, 0.0, 0.0), 200)
	_set_enemy(combat, enemy_b, origin + Vector3(0.0, 0.0, -1.0), 200)
	var in_transit: Dictionary = combat._advance_single_npc_combat_attack(npc_id, 0.25)
	var transit_state: Dictionary = npc_system.get_npc_state(npc_id)
	if (
		str(transit_state.get("keep_distance_retreat_target_id", "")) != committed_id
		or _dict_to_v3(transit_state.get("keep_distance_retreat_target_position", {})).distance_to(committed_target) > 0.01
		or not str(transit_state.get("combat_target_enemy_id", "")).is_empty()
		or int(in_transit.get("attack_count", 0)) != 0
	):
		_fail("T0232 changed orders or attacked during a committed leg: %s" % JSON.stringify(transit_state))
		return

	# Cancelling navigation must restore the exact endpoint, not rescan the now
	# different threat field.
	npc_system.stop_npc_movement_with_state(npc_id, {"current_action": "combat_ready"})
	var recovered: Dictionary = combat._advance_single_npc_combat_attack(npc_id, 0.25)
	var recovered_state: Dictionary = npc_system.get_npc_state(npc_id)
	if (
		str(recovered.get("reason", "")) != "keep_distance_retreat_movement_recovered"
		or str(recovered_state.get("keep_distance_retreat_target_id", "")) != committed_id
		or _dict_to_v3(recovered_state.get("keep_distance_retreat_target_position", {})).distance_to(committed_target) > 0.01
		or int(recovered_state.get("keep_distance_retreat_recovery_count", 0)) < 1
	):
		_fail("T0232 did not recover the same committed leg: %s" % JSON.stringify(recovered_state))
		return

	# Arrive, leave one enemy close to the arrival point, and require a fresh leg.
	npc_system.stop_npc_movement_with_state(npc_id, {"current_action": "combat_ready"})
	_set_npc_world_position(npc_id, committed_target)
	_set_enemy(combat, enemy_a, committed_target + Vector3(0.0, 0.0, 1.0), 200)
	_set_enemy(combat, enemy_b, committed_target + Vector3(10.0, 0.0, 0.0), 200)
	var repeated: Dictionary = combat._advance_single_npc_combat_attack(npc_id, 0.25)
	var repeated_state: Dictionary = npc_system.get_npc_state(npc_id)
	var repeated_target := _dict_to_v3(repeated_state.get("keep_distance_retreat_target_position", {}))
	if (
		str(repeated.get("reason", "")) != "keep_distance_retreat_repeated"
		or int(repeated_state.get("keep_distance_retreat_sequence", 0)) < 2
		or repeated_target.distance_to(committed_target) <= 0.35
	):
		_fail("T0232 arrival rescan did not start the next leg: %s" % JSON.stringify(repeated_state))
		return
	if not bool(station.is_world_position_inside_station(repeated_target)):
		_fail("T0232 corrected retreat target left the station: %s" % repeated_target)
		return

	# Arrive safely. The same step must leave retreat and reacquire through the
	# ordinary target/attack-position chain.
	npc_system.stop_npc_movement_with_state(npc_id, {"current_action": "combat_ready"})
	_set_npc_world_position(npc_id, repeated_target)
	_set_enemy(combat, enemy_a, repeated_target + Vector3(0.0, 0.0, minf(attack_range * 0.7, 6.0)), 200)
	_set_enemy(combat, enemy_b, repeated_target + Vector3(20.0, 0.0, 0.0), 200)
	var safe_result: Dictionary = combat._advance_single_npc_combat_attack(npc_id, 0.05)
	var safe_state: Dictionary = npc_system.get_npc_state(npc_id)
	if bool(safe_state.get("keep_distance_retreat_active", true)) or str(safe_state.get("combat_target_enemy_id", "")) != enemy_a:
		_fail("T0232 safe arrival did not return to ordinary target acquisition: result=%s state=%s" % [JSON.stringify(safe_result), JSON.stringify(safe_state)])
		return

	# Regression for a weighted direction that runs directly into the main-hall
	# envelope: the primary resolver can collapse to the origin, so the strategy
	# must side-offset to another station-valid point instead of looping in place.
	var blocked_origin := Vector3(-0.64676094, 0.2, 1.75)
	_set_enemy(combat, enemy_a, blocked_origin + Vector3(0.0, 0.0, 1.0), 200)
	_set_enemy(combat, enemy_b, blocked_origin + Vector3(20.0, 0.0, 0.0), 200)
	var blocked_field: Dictionary = combat._build_avoidance_threat_field(blocked_origin, trigger_range, npc_id)
	var offset_target: Dictionary = combat._select_keep_distance_retreat_target(npc_id, blocked_origin, attack_range, blocked_field)
	var offset_position: Vector3 = offset_target.get("position", blocked_origin)
	if (
		offset_target.is_empty()
		or Vector2(offset_position.x, offset_position.z).distance_to(Vector2(blocked_origin.x, blocked_origin.z)) <= 0.35
		or not bool(station.is_world_position_inside_station(offset_position))
		or not station.get_building_area_overlap(offset_position, 0.4).is_empty()
	):
		_fail("T0232 obstacle correction did not offset to a nearby reachable point: %s" % JSON.stringify(offset_target))
		return

	# The same policy must apply after mounting; unit presentation must not select
	# a separate distance band.
	npc_system.set_npc_behavior_mode(npc_id, "work", "verify_t0232_prepare_mount", {
		"request_plan_reevaluation": false
	})
	var mount_result: Dictionary = equipment.equip_npc_mount(npc_id, "", "local_public")
	if not bool(mount_result.get("ok", false)):
		_fail("T0232 failed to assign mount: %s" % JSON.stringify(mount_result))
		return
	combat.set_npc_combat_strategy(npc_id, "keep_distance", "private")
	npc_system.set_npc_behavior_mode(npc_id, "combat", "verify_t0232_mounted", {
		"state_changes": {
			"current_action": "combat_ready",
			"combat_mounted": true,
			"combat_mount_phase": "mounted",
			"keep_distance_retreat_active": false,
			"combat_target_enemy_id": enemy_a
		},
		"request_plan_reevaluation": false
	})
	var mounted_origin := _get_npc_world_position(npc_id)
	_set_enemy(combat, enemy_a, mounted_origin + Vector3(1.0, 0.0, 0.0), 200)
	var mounted: Dictionary = combat._advance_single_npc_combat_attack(npc_id, 0.25)
	var mounted_state: Dictionary = npc_system.get_npc_state(npc_id)
	if (
		not bool(mounted_state.get("keep_distance_retreat_active", false))
		or not str(mounted_state.get("combat_target_enemy_id", "")).is_empty()
		or not is_equal_approx(float((mounted.get("strategy_movement", {}) as Dictionary).get("desired_travel_distance", 0.0)), segment_distance)
	):
		_fail("T0232 mounted ranged unit did not use the unified retreat policy: %s" % JSON.stringify(mounted_state))
		return

	print("T0232 keep-distance retreat cycle verification passed.")
	quit(0)


func _set_enemy(combat: Node, enemy_id: String, position: Vector3, hp: int) -> void:
	var active: Dictionary = combat.get("_active_enemies")
	var enemy: Dictionary = active.get(enemy_id, {})
	enemy["position"] = position
	enemy["hp"] = hp
	enemy["max_hp"] = maxi(hp, int(enemy.get("max_hp", hp)))
	enemy["alive"] = true
	active[enemy_id] = enemy
	combat.set("_active_enemies", active)
	combat._refresh_enemy_node(enemy_id)


func _set_npc_world_position(npc_id: String, position: Vector3) -> void:
	var npc_root := root.get_node_or_null("Main/WorldRoot/Station/NPCs")
	for child in npc_root.get_children():
		if child is Node3D and str(child.get_meta("npc_id", "")) == npc_id:
			(child as Node3D).global_position = position
			return
	_fail("T0232 NPC node missing: %s" % npc_id)


func _get_npc_world_position(npc_id: String) -> Vector3:
	var npc_system := root.get_node("Main/Systems/NPCSystem")
	return npc_system.get_npc_world_position(npc_id)


func _dict_to_v3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	var data: Dictionary = value if value is Dictionary else {}
	return Vector3(float(data.get("x", 0.0)), float(data.get("y", 0.0)), float(data.get("z", 0.0)))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
