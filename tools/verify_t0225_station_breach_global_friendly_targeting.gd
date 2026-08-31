extends SceneTree


const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const OUTSIDE_DEFENDER_ORIGIN := Vector3(0.0, 0.0, 82.0)
const STATION_INTRUDER_POSITION := Vector3(0.0, 0.0, 40.0)
const NEAR_OUTSIDE_ENEMY_POSITION := Vector3(0.0, 0.0, 84.0)

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	for _frame in range(6):
		await process_frame
		await physics_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var station_controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	_check(combat_system != null and npc_system != null, "T0225 combat or NPC system missing")
	_check(equipment_system != null and station_controller != null and time_system != null, "T0225 equipment, station, or time system missing")
	if not _failures.is_empty():
		_finish()
		return
	time_system.set_paused(true)

	var preset: Dictionary = equipment_system.debug_apply_combat_loadout_preset()
	_check(bool(preset.get("ok", false)), "T0225 GM recruit/equip preset failed: %s" % preset)
	var spawn: Dictionary = combat_system.debug_spawn_wave(5, true, true)
	_check(bool(spawn.get("ok", false)), "T0225 fifth wave spawn failed: %s" % spawn)
	var enemy_ids: Array = combat_system.get_active_enemy_ids()
	_check(enemy_ids.size() == 48, "T0225 fifth wave fixture must contain 48 enemies: %s" % enemy_ids.size())
	if not _failures.is_empty():
		combat_system.debug_clear_enemies()
		_finish()
		return

	var station_intruder_id := str(enemy_ids[0])
	var near_outside_enemy_id := str(enemy_ids[1])
	for index in range(enemy_ids.size()):
		_set_enemy_position(combat_system, str(enemy_ids[index]), Vector3(float(index % 8) * 2.0, 0.0, 150.0 + float(index / 8) * 2.0))
	_set_enemy_position(combat_system, station_intruder_id, STATION_INTRUDER_POSITION)
	_set_enemy_position(combat_system, near_outside_enemy_id, NEAR_OUTSIDE_ENEMY_POSITION)
	_check(station_controller.is_world_position_inside_station(STATION_INTRUDER_POSITION), "T0225 intruder fixture is outside the station")
	_check(not station_controller.is_world_position_inside_station(NEAR_OUTSIDE_ENEMY_POSITION), "T0225 nearer outside enemy fixture is inside the station")

	var npc_ids: Array = npc_system.get_npc_ids()
	_check(npc_ids.size() == 8, "T0225 expected all eight initial NPCs")
	for index in range(npc_ids.size()):
		var npc_id := str(npc_ids[index])
		_set_npc_position(npc_system, npc_id, OUTSIDE_DEFENDER_ORIGIN + Vector3(float(index) * 0.4, 0.0, 0.0))
		npc_system.set_npc_behavior_mode(npc_id, "work", "t0225_outside_fixture", {
			"force_idle": true,
			"request_plan_reevaluation": false,
			"state_changes": {
				"unconscious": false,
				"escaped": false,
				"combat_target_enemy_id": "",
				"combat_attack_target_enemy_id": "",
				"combat_strategy_move_enemy_id": ""
			}
		})
		_check(not station_controller.is_world_position_inside_station(npc_system.get_npc_world_position(npc_id)), "T0225 outside defender fixture was classified inside: %s" % npc_id)

	combat_system._advance_behavior_mode_contacts()
	var globally_locked := 0
	var mounting_count := 0
	for raw_npc_id in npc_ids:
		var npc_id := str(raw_npc_id)
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		var scope: Dictionary = combat_system._get_friendly_target_scope(npc_id)
		var selected: Dictionary = combat_system._select_friendly_combat_target_lock(npc_id, state)
		_check(str(state.get("behavior_mode", "")) == "combat", "T0225 outside armed recruit did not enter combat: %s" % npc_id)
		_check(str(state.get("combat_target_enemy_id", "")) == station_intruder_id, "T0225 outside armed recruit did not seed the station target: %s state=%s" % [npc_id, state])
		_check(str(scope.get("scope", "")) == "station_breach_global", "T0225 global station scope missing: %s scope=%s" % [npc_id, scope])
		_check(bool(scope.get("station_enemy_only", false)), "T0225 station-only target filter missing: %s" % npc_id)
		_check(str(selected.get("id", "")) == station_intruder_id, "T0225 nearer outside enemy stole station-breach target: %s selected=%s" % [npc_id, selected])
		if str(state.get("combat_target_enemy_id", "")) == station_intruder_id:
			globally_locked += 1
		if bool((equipment_system.get_unit_type_snapshot(npc_id) as Dictionary).get("has_mount", false)):
			_check(str(state.get("combat_mount_phase", "")) in ["going_to_stable_horse", "beside_stable_horse"], "T0225 assigned rider skipped horse pickup: %s state=%s" % [npc_id, state])
			mounting_count += 1

	# Every proactive foot unit must receive physical movement authority when its
	# locked station intruder is outside weapon range. Ranged units select a
	# reachable point on the 95%-range attack circle instead of holding combat_ready.
	combat_system.debug_step_enemy_ai(0.1)
	for npc_id in ["cook_01", "gardener_01"]:
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		_check(str(state.get("combat_target_enemy_id", "")) == station_intruder_id, "T0225 proactive melee target changed unexpectedly: %s" % npc_id)
		_check(str(state.get("current_action", "")).begins_with("moving_to_combat_strategy_attack"), "T0225 proactive melee responder did not start pursuit: %s state=%s" % [npc_id, state])
		_check(npc_system.is_npc_world_movement_active(npc_id), "T0225 proactive melee movement request is inactive: %s" % npc_id)
	for npc_id in ["priest_01", "doctor_01"]:
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		var attack_context: Dictionary = combat_system._calculate_npc_attack_context(
			npc_id,
			npc_system.get_npc(npc_id),
			state
		)
		var target_position: Vector3 = combat_system._vector3_from_dict(
			state.get("combat_strategy_move_target_position", {}),
			OUTSIDE_DEFENDER_ORIGIN
		)
		var expected_radius := float(attack_context.get("range", 0.0)) * 0.95
		var selected_radius := Vector2(target_position.x, target_position.z).distance_to(
			Vector2(STATION_INTRUDER_POSITION.x, STATION_INTRUDER_POSITION.z)
		)
		_check(str(state.get("combat_target_enemy_id", "")) == station_intruder_id, "T0225 ranged foot target changed unexpectedly: %s" % npc_id)
		_check(str(state.get("current_action", "")).begins_with("moving_to_combat_strategy_"), "T0225 ranged foot responder held still instead of selecting an attack point: %s state=%s" % [npc_id, state])
		_check(npc_system.is_npc_world_movement_active(npc_id), "T0225 ranged foot attack-point movement is inactive: %s" % npc_id)
		_check(absf(selected_radius - expected_radius) <= 0.7, "T0225 ranged attack point is not on the 95%% range circle: %s selected=%.3f expected=%.3f" % [npc_id, selected_radius, expected_radius])

	# Reproduce the original split-brain state: the label still says tactical
	# movement while the actor request has disappeared. The next combat tick must
	# settle the stale label and issue a fresh attack-point route automatically.
	var stale_ranged_id := "priest_01"
	var stale_actor := npc_system.get_node_or_null(npc_system._npc_nodes.get(stale_ranged_id, NodePath()))
	if stale_actor != null and stale_actor.has_method("stop_movement"):
		stale_actor.stop_movement()
	_check(not npc_system.is_npc_world_movement_active(stale_ranged_id), "T0225 stale ranged fixture failed to cancel physical movement")
	combat_system.debug_step_enemy_ai(0.1)
	var recovered_state: Dictionary = npc_system.get_npc_state(stale_ranged_id)
	_check(npc_system.is_npc_world_movement_active(stale_ranged_id), "T0225 ranged stale movement did not self-recover")
	_check(str(recovered_state.get("current_action", "")).begins_with("moving_to_combat_strategy_"), "T0225 ranged stale movement recovered without a tactical route: %s" % recovered_state)

	# Once the last station intruder leaves, the same outside defender must fall
	# back to the ordinary radius and may acquire the nearby outside enemy again.
	_set_enemy_position(combat_system, station_intruder_id, Vector3(0.0, 0.0, 150.0))
	var fallback_npc_id := "cook_01"
	var fallback_scope: Dictionary = combat_system._get_friendly_target_scope(fallback_npc_id)
	var fallback_target: Dictionary = combat_system._select_friendly_combat_target_lock(
		fallback_npc_id,
		npc_system.get_npc_state(fallback_npc_id)
	)
	_check(str(fallback_scope.get("scope", "")) == "unified_radius", "T0225 did not restore outside radius after station cleared: %s" % fallback_scope)
	_check(not bool(fallback_scope.get("station_enemy_only", true)), "T0225 station-only filter survived after station cleared")
	_check(str(fallback_target.get("id", "")) == near_outside_enemy_id, "T0225 ordinary radius did not reacquire the nearby outside enemy: %s" % fallback_target)

	var snapshot: Dictionary = combat_system.debug_get_friendly_targeting_snapshot()
	_check(str(snapshot.get("station_breach_target_scope", "")) == "station_breach_global", "T0225 runtime diagnostic scope missing: %s" % snapshot)
	print("T0225_STATION_BREACH_GLOBAL_TARGETING_OK %s" % JSON.stringify({
		"fifth_wave_enemy_count": enemy_ids.size(),
		"globally_locked": globally_locked,
		"mounting_count": mounting_count,
		"fallback_target": str(fallback_target.get("id", ""))
	}))
	combat_system.debug_clear_enemies()
	_finish()


func _set_enemy_position(combat_system: Node, enemy_id: String, position: Vector3) -> void:
	var enemy: Dictionary = combat_system.get_enemy(enemy_id)
	enemy["position"] = position
	enemy["alive"] = true
	enemy["hp"] = maxi(10000, int(enemy.get("hp", 0)))
	enemy["max_hp"] = maxi(10000, int(enemy.get("max_hp", 0)))
	combat_system._active_enemies[enemy_id] = enemy
	var actor := combat_system.get_node_or_null(combat_system._enemy_nodes.get(enemy_id, NodePath())) as Node3D
	if actor != null:
		if actor.has_method("stop_movement"):
			actor.stop_movement()
		actor.global_position = position


func _set_npc_position(npc_system: Node, npc_id: String, position: Vector3) -> void:
	var actor := npc_system.get_node_or_null(npc_system._npc_nodes.get(npc_id, NodePath())) as Node3D
	if actor == null:
		_failures.append("T0225 NPC actor missing: %s" % npc_id)
		return
	if actor.has_method("stop_movement"):
		actor.stop_movement()
	actor.global_position = position


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
