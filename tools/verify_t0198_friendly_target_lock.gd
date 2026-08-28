extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const NPC_ID := "veteran_deputy_01"
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
	for _frame in range(5):
		await process_frame
		await physics_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var station_controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	_check(combat_system != null and npc_system != null, "T0198 combat or NPC system missing")
	_check(equipment_system != null and resource_system != null and time_system != null, "T0198 equipment or time system missing")
	_check(station_controller != null, "T0198 station controller missing")
	if not _failures.is_empty():
		_finish()
		return
	time_system.set_paused(true)

	resource_system.add_resource("item_sword_shield", 1)
	npc_system.set_npc_recruited(NPC_ID, true)
	_check(
		bool(equipment_system.equip_npc_main_weapon(NPC_ID, "sword_shield", "private").get("ok", false)),
		"T0198 failed to arm friendly NPC"
	)
	combat_system.set_npc_combat_strategy(NPC_ID, "attack", "private")
	var spawned: Dictionary = combat_system.debug_run_formal_dynamic_wave_slice(1, true)
	_check(bool(spawned.get("ok", false)), "T0198 formal wave failed to spawn: %s" % spawned)
	var enemy_ids: Array[String] = combat_system.get_active_enemy_ids()
	_check(enemy_ids.size() >= 3, "T0198 needs three production enemies")
	if not _failures.is_empty():
		_finish()
		return
	for index in range(3, enemy_ids.size()):
		combat_system._remove_enemy_from_combat(enemy_ids[index])
	enemy_ids = combat_system.get_active_enemy_ids()
	var enemy_a := enemy_ids[0]
	var enemy_b := enemy_ids[1]
	var enemy_c := enemy_ids[2]
	npc_system.set_npc_behavior_mode(NPC_ID, "combat", "verify_t0198", {
		"state_changes": {
			"hp": 10000,
			"max_hp": 10000,
			"unconscious": false,
			"escaped": false,
			"current_action": "combat_ready",
			"combat_target_enemy_id": ""
		},
		"request_plan_reevaluation": false
	})

	var response: Dictionary = combat_system.debug_get_friendly_targeting_snapshot()
	_check(str(response.get("schema_version", "")) == "friendly_station_response_runtime_v2", "T0198 runtime schema mismatch: %s" % response)
	_check(str(response.get("combat_targeting_schema", "")) == "friendly_enemy_presence_lock_v1", "T0198 targeting schema missing: %s" % response)
	_check(absf(float(response.get("combat_target_detection_range", 0.0)) - UNIFIED_RANGE) <= 0.0001, "T0198 outside detection range mismatch: %s" % response)

	# Outside: acquire the nearest enemy once, then keep it while still in the
	# exact 37.2 m circle even if a peer becomes nearer.
	var outside_origin := Vector3(0.0, 0.0, 80.0)
	_check(not station_controller.is_world_position_inside_station(outside_origin), "T0198 outside NPC fixture is inside station")
	_set_npc_position(npc_system, NPC_ID, outside_origin)
	_set_enemy_position(combat_system, enemy_a, outside_origin + Vector3(7.0, 0.0, 0.0))
	_set_enemy_position(combat_system, enemy_b, outside_origin + Vector3(2.0, 0.0, 0.0))
	_set_enemy_position(combat_system, enemy_c, outside_origin + Vector3(UNIFIED_RANGE + 0.1, 0.0, 0.0))
	var selected := _select_and_store(combat_system, npc_system)
	_check(str(selected.get("id", "")) == enemy_b, "T0198 outside initial lock was not nearest: %s" % selected)
	_set_enemy_position(combat_system, enemy_a, outside_origin + Vector3(1.0, 0.0, 0.0))
	selected = combat_system._select_friendly_combat_target_lock(NPC_ID, npc_system.get_npc_state(NPC_ID))
	_check(str(selected.get("id", "")) == enemy_b and str(selected.get("target_selection_reason", "")) == "locked_enemy_present", "T0198 nearer outside peer stole presence lock: %s" % selected)
	_set_enemy_position(combat_system, enemy_b, outside_origin + Vector3(UNIFIED_RANGE + 0.1, 0.0, 0.0))
	selected = _select_and_store(combat_system, npc_system)
	_check(str(selected.get("id", "")) == enemy_a, "T0198 outside lock did not reacquire after leaving circle: %s" % selected)

	# Exact boundary: 37.1 m is eligible and 37.3 m is not.
	_clear_lock(combat_system, npc_system)
	_set_enemy_position(combat_system, enemy_a, outside_origin + Vector3(UNIFIED_RANGE - 0.1, 0.0, 0.0))
	_set_enemy_position(combat_system, enemy_b, outside_origin + Vector3(UNIFIED_RANGE + 0.1, 0.0, 0.0))
	_set_enemy_position(combat_system, enemy_c, outside_origin + Vector3(UNIFIED_RANGE + 2.0, 0.0, 0.0))
	selected = _select_and_store(combat_system, npc_system)
	_check(str(selected.get("id", "")) == enemy_a, "T0198 37.1 m boundary target missing: %s" % selected)
	npc_system.set_npc_behavior_mode(NPC_ID, "work", "t0198_outside_contact", {"force_idle": true, "request_plan_reevaluation": false})
	combat_system._advance_behavior_mode_contacts()
	_check(str(npc_system.get_npc_behavior_mode_snapshot(NPC_ID).get("behavior_mode", "")) == "combat", "T0198 outside armed NPC did not enter combat within unified range")
	_check(str(npc_system.get_npc_state(NPC_ID).get("combat_target_enemy_id", "")) == enemy_a, "T0198 outside contact did not seed the nearest enemy")
	_clear_lock(combat_system, npc_system)
	_set_enemy_position(combat_system, enemy_a, outside_origin + Vector3(UNIFIED_RANGE + 0.1, 0.0, 0.0))
	npc_system.set_npc_behavior_mode(NPC_ID, "work", "t0198_outside_no_contact", {"force_idle": true, "request_plan_reevaluation": false})
	combat_system._advance_behavior_mode_contacts()
	_check(str(npc_system.get_npc_behavior_mode_snapshot(NPC_ID).get("behavior_mode", "")) == "work", "T0198 outside armed NPC entered combat beyond unified range")
	selected = combat_system._select_friendly_combat_target_lock(NPC_ID, npc_system.get_npc_state(NPC_ID))
	_check(selected.is_empty(), "T0198 37.3 m target incorrectly entered outside scope: %s" % selected)
	_set_enemy_position(combat_system, enemy_a, Vector3(0.0, 0.0, 40.0))
	npc_system.set_npc_behavior_mode(NPC_ID, "work", "t0198_outside_station_breach", {"force_idle": true, "request_plan_reevaluation": false})
	combat_system._advance_behavior_mode_contacts()
	_check(str(npc_system.get_npc_behavior_mode_snapshot(NPC_ID).get("behavior_mode", "")) == "combat", "T0198 outside armed NPC did not wake for station breach")
	_check(str(npc_system.get_npc_state(NPC_ID).get("combat_target_enemy_id", "")).is_empty(), "T0198 outside NPC cross-map locked station enemy beyond its domain")

	# Inside: the entire station is one scope. The far enemy remains eligible
	# beyond 37.2 m, while an enemy outside the polygon is never a candidate.
	var inside_origin := Vector3(0.0, 0.0, -30.0)
	_check(station_controller.is_world_position_inside_station(inside_origin), "T0198 inside NPC fixture is outside station")
	_set_npc_position(npc_system, NPC_ID, inside_origin)
	npc_system.set_npc_behavior_mode(NPC_ID, "combat", "t0198_inside_scope", {"state_changes": {"current_action": "combat_ready"}, "request_plan_reevaluation": false})
	_clear_lock(combat_system, npc_system)
	_set_enemy_position(combat_system, enemy_a, Vector3(0.0, 0.0, 40.0))
	_set_enemy_position(combat_system, enemy_b, Vector3(10.0, 0.0, 0.0))
	_set_enemy_position(combat_system, enemy_c, Vector3(0.0, 0.0, 60.0))
	_check(_horizontal_distance(inside_origin, Vector3(0.0, 0.0, 40.0)) > UNIFIED_RANGE, "T0198 station-wide fixture is not beyond outside range")
	_check(station_controller.is_world_position_inside_station(Vector3(0.0, 0.0, 40.0)), "T0198 far station enemy fixture is outside")
	_check(not station_controller.is_world_position_inside_station(Vector3(0.0, 0.0, 60.0)), "T0198 outside enemy fixture is inside")
	selected = _select_and_store(combat_system, npc_system)
	_check(str(selected.get("id", "")) == enemy_b, "T0198 inside initial lock was not nearest station enemy: %s" % selected)
	_set_enemy_position(combat_system, enemy_a, inside_origin + Vector3(1.0, 0.0, 0.0))
	selected = combat_system._select_friendly_combat_target_lock(NPC_ID, npc_system.get_npc_state(NPC_ID))
	_check(str(selected.get("id", "")) == enemy_b, "T0198 nearer station enemy stole presence lock: %s" % selected)

	# A real HP loss from a different enemy creates one request. Selection rescans
	# the current scope by distance; it is not an exact retaliation shortcut.
	var damage_result := _enemy_damage_npc(combat_system, enemy_a)
	_check(int(damage_result.get("damage", 0)) == 1, "T0198 different enemy did not commit NPC HP damage: %s" % damage_result)
	_check(combat_system._friendly_enemy_reacquire_requests.has(NPC_ID), "T0198 different attacker did not create request")
	selected = _select_and_store(combat_system, npc_system)
	_check(str(selected.get("id", "")) == enemy_a, "T0198 station damage rescan did not select nearest: %s" % selected)
	_check(str(selected.get("target_selection_reason", "")) == "different_attacker_damage_nearest_enemy_reacquire", "T0198 damage rescan reason missing: %s" % selected)
	_check(not combat_system._friendly_enemy_reacquire_requests.has(NPC_ID), "T0198 request was not consumed once")

	_enemy_damage_npc(combat_system, enemy_a)
	_check(not combat_system._friendly_enemy_reacquire_requests.has(NPC_ID), "T0198 current target damage incorrectly unlocked itself")
	_set_enemy_position(combat_system, enemy_a, inside_origin + Vector3(4.0, 0.0, 0.0))
	_set_enemy_position(combat_system, enemy_c, Vector3(0.0, 0.0, 60.0))
	_check(not station_controller.is_world_position_inside_station(combat_system.get_enemy(enemy_c).get("position", Vector3.ZERO)), "T0198 external attacker moved inside unexpectedly")
	damage_result = _enemy_damage_npc(combat_system, enemy_c)
	_check(combat_system._friendly_enemy_reacquire_requests.has(NPC_ID), "T0198 external different attacker did not request station rescan")
	selected = _select_and_store(combat_system, npc_system)
	_check(str(selected.get("id", "")) == enemy_a, "T0198 outside damage source was forced into station candidate set: %s" % selected)

	# Target change during windup cancels the phase but preserves the T0193
	# earliest-next-start lock.
	_set_enemy_position(combat_system, enemy_a, inside_origin + Vector3(1.0, 0.0, 0.0))
	_set_enemy_position(combat_system, enemy_b, inside_origin + Vector3(1.2, 0.0, 0.0))
	npc_system.update_npc_state(NPC_ID, {
		"combat_target_enemy_id": enemy_b,
		"combat_attack_target_enemy_id": enemy_b,
		"combat_attack_phase": "windup",
		"combat_attack_elapsed_seconds": 0.1,
		"combat_attack_cycle_seconds": 2.5,
		"combat_attack_impact_seconds": 0.8,
		"combat_attack_sequence": 3,
		"combat_attack_next_sequence_time": float(combat_system._combat_timeline_seconds) + 2.0,
		"combat_attack_sequence_lock_remaining": 2.0,
		"current_action": "winding_up_%s" % enemy_b
	})
	var next_sequence_time := float(npc_system.get_npc_state(NPC_ID).get("combat_attack_next_sequence_time", 0.0))
	_enemy_damage_npc(combat_system, enemy_a)
	combat_system._advance_single_npc_combat_attack(NPC_ID, 0.1)
	var cadence_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	_check(str(cadence_state.get("combat_target_enemy_id", "")) == enemy_a, "T0198 windup rescan did not change authority target: %s" % cadence_state)
	_check(int(cadence_state.get("combat_attack_sequence", 0)) == 3, "T0198 windup rescan started an early sequence: %s" % cadence_state)
	_check(is_equal_approx(float(cadence_state.get("combat_attack_next_sequence_time", 0.0)), next_sequence_time), "T0198 windup rescan cleared cadence lock: %s" % cadence_state)

	# Requests are transient: visible in runtime diagnostics, absent from the
	# formal spatial checkpoint, and not consumed by snapshot capture.
	npc_system.update_npc_state(NPC_ID, {"combat_target_enemy_id": enemy_b})
	_enemy_damage_npc(combat_system, enemy_a)
	response = combat_system.debug_get_friendly_targeting_snapshot()
	_check((response.get("different_attacker_damage_reacquire_requests", []) as Array).size() == 1, "T0198 pending request missing from runtime snapshot: %s" % response)
	var checkpoint: Dictionary = combat_system.create_formal_spatial_checkpoint()
	_check(not JSON.stringify(checkpoint).contains("friendly_enemy_damage_reacquire_request"), "T0198 transient request leaked into checkpoint")
	_check(combat_system._friendly_enemy_reacquire_requests.has(NPC_ID), "T0198 checkpoint unexpectedly consumed request")
	combat_system._select_friendly_combat_target_lock(NPC_ID, npc_system.get_npc_state(NPC_ID))
	response = combat_system.debug_get_friendly_targeting_snapshot()
	var metrics := response.get("metrics", {}) as Dictionary
	_check(int(metrics.get("different_attacker_damage_signals", 0)) >= 3, "T0198 damage signal metric missing: %s" % metrics)
	_check(int(metrics.get("different_attacker_damage_reacquisitions", 0)) >= 3, "T0198 damage reacquisition metric missing: %s" % metrics)
	print("T0198_FRIENDLY_TARGET_LOCK_DIAGNOSTICS %s" % JSON.stringify({
		"metrics": metrics,
		"last_target": selected,
		"cadence_next_sequence_time": next_sequence_time
	}))

	combat_system.clear_spawned_enemies()
	_finish()


func _select_and_store(combat_system: Node, npc_system: Node) -> Dictionary:
	var selected: Dictionary = combat_system._select_friendly_combat_target_lock(
		NPC_ID,
		npc_system.get_npc_state(NPC_ID)
	)
	npc_system.update_npc_state(NPC_ID, {
		"combat_target_enemy_id": str(selected.get("id", "")),
		"combat_target_selection_reason": str(selected.get("target_selection_reason", "")),
		"combat_target_scope": str(selected.get("target_scope", ""))
	})
	return selected


func _clear_lock(combat_system: Node, npc_system: Node) -> void:
	combat_system._friendly_enemy_reacquire_requests.erase(NPC_ID)
	npc_system.update_npc_state(NPC_ID, {"combat_target_enemy_id": ""})


func _enemy_damage_npc(combat_system: Node, enemy_id: String) -> Dictionary:
	var result: Dictionary = combat_system._apply_enemy_attack_to_npc(
		combat_system.get_enemy(enemy_id),
		NPC_ID,
		1,
		1.0,
		0.0,
		0.0,
		0.0
	)
	return result.get("result", {}) as Dictionary


func _set_enemy_position(combat_system: Node, enemy_id: String, position: Vector3) -> void:
	var enemy: Dictionary = combat_system.get_enemy(enemy_id)
	enemy["position"] = position
	enemy["alive"] = true
	enemy["hp"] = maxi(10000, int(enemy.get("hp", 0)))
	enemy["max_hp"] = maxi(10000, int(enemy.get("max_hp", 0)))
	combat_system._active_enemies[enemy_id] = enemy
	var actor := combat_system.get_node_or_null(
		combat_system._formal_first_wave_node_paths.get(enemy_id, NodePath())
	) as Node3D
	if actor != null:
		actor.global_position = position


func _set_npc_position(npc_system: Node, npc_id: String, position: Vector3) -> void:
	var node := npc_system.get_node_or_null(npc_system._npc_nodes.get(npc_id, NodePath())) as Node3D
	if node == null:
		_failures.append("T0198 NPC actor missing")
		return
	if node.has_method("stop_movement"):
		node.stop_movement()
	node.global_position = position


func _horizontal_distance(left: Vector3, right: Vector3) -> float:
	return Vector2(left.x, left.z).distance_to(Vector2(right.x, right.z))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0198_FRIENDLY_TARGET_LOCK_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
