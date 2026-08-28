extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const NPC_ID := "veteran_deputy_01"
const SAMPLE_FRAMES := 900

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
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	_check(combat_system != null and npc_system != null, "T0192 combat or NPC system missing")
	_check(equipment_system != null and resource_system != null and building_system != null and time_system != null, "T0192 equipment, resource, building or time system missing")
	if not _failures.is_empty():
		_finish()
		return

	time_system.set_paused(true)
	resource_system.add_resource("item_sword_shield", 1)
	_check(bool(equipment_system.equip_npc_main_weapon(NPC_ID, "sword_shield", "private").get("ok", false)), "T0192 failed to arm Ada")
	combat_system.set_npc_combat_strategy(NPC_ID, "attack", "private")
	npc_system.set_npc_recruited(NPC_ID, true)

	var spawned: Dictionary = combat_system.debug_run_formal_dynamic_wave_slice(1, true)
	_check(bool(spawned.get("ok", false)), "T0192 failed to spawn production wave: %s" % spawned)
	var enemy_ids: Array[String] = combat_system.get_active_enemy_ids()
	_check(not enemy_ids.is_empty(), "T0192 production wave has no enemies")
	if enemy_ids.is_empty():
		_finish()
		return
	var enemy_id := enemy_ids[0]
	for index in range(1, enemy_ids.size()):
		combat_system._remove_enemy_from_combat(enemy_ids[index])

	var paths: Dictionary = npc_system.get("_npc_nodes")
	var ada := npc_system.get_node_or_null(paths.get(NPC_ID, NodePath())) as ActorMotionBody
	var enemy_actor := combat_system.get_node_or_null(combat_system._formal_first_wave_node_paths.get(enemy_id, NodePath())) as ActorMotionBody
	_check(ada != null and enemy_actor != null, "T0192 formal actors missing")
	if ada == null or enemy_actor == null:
		_finish()
		return

	# Advance the authored assault chain to the warehouse, reserve the real
	# rotated-wall attack point, and keep the final enemy on that production
	# geometry instead of using an arbitrary nearby coordinate.
	var gate: Dictionary = building_system._buildings.get("front_gate", {})
	gate["hp"] = 0
	building_system._buildings["front_gate"] = gate
	var warehouse: Dictionary = building_system._buildings.get("warehouse", {})
	warehouse["hp"] = 100000
	warehouse["max_hp"] = 100000
	building_system._buildings["warehouse"] = warehouse
	var enemy: Dictionary = combat_system._active_enemies.get(enemy_id, {})
	var warehouse_target: Dictionary = combat_system._make_building_target("warehouse")
	warehouse_target = combat_system._ensure_enemy_attack_position(enemy_id, enemy, warehouse_target, true)
	_check(str(warehouse_target.get("attack_position_status", "")) == "reserved", "T0192 did not reserve a production warehouse attack point: %s" % warehouse_target)
	if str(warehouse_target.get("attack_position_status", "")) != "reserved":
		_finish()
		return
	var enemy_position: Vector3 = warehouse_target.get("attack_position", Vector3.ZERO)
	var contact_position: Vector3 = warehouse_target.get("attack_contact_position", enemy_position)
	var outward := enemy_position - contact_position
	outward.y = 0.0
	outward = outward.normalized() if outward.length_squared() > 0.0001 else Vector3(-1.0, 0.0, -1.0).normalized()
	var ada_position := enemy_position + outward * 7.0
	ada.cancel_motion("t0192_fixture")
	ada.global_position = ada_position
	ada.velocity = Vector3.ZERO
	npc_system.set_npc_behavior_mode(NPC_ID, "combat", "verify_t0192_warehouse_intercept", {
		"state_changes": {
			"hp": 10000,
			"max_hp": 10000,
			"unconscious": false,
			"escaped": false,
			"combat_mounted": false,
			"current_action": "combat_ready",
			"combat_target_enemy_id": enemy_id,
			"combat_attack_cooldown": 0.0,
		},
		"request_plan_reevaluation": false,
	})

	enemy_actor.cancel_motion("t0192_fixture")
	enemy_actor.global_position = enemy_position
	enemy_actor.velocity = Vector3.ZERO
	enemy["position"] = enemy_position
	enemy["hp"] = 10000
	enemy["max_hp"] = 10000
	enemy["alive"] = true
	enemy["current_action"] = "attacking_warehouse"
	enemy["formal_route_phase"] = "attacking_warehouse"
	enemy["target"] = warehouse_target.duplicate(true)
	combat_system._cancel_enemy_attack_timeline(enemy)
	combat_system._active_enemies[enemy_id] = enemy
	var slice: Dictionary = combat_system._formal_first_wave_slices.get(enemy_id, {})
	slice["phase"] = "attacking_warehouse"
	slice["current_stage_id"] = "warehouse"
	slice["target_stage_id"] = "warehouse"
	slice["attack_target_building_id"] = "warehouse"
	slice["attack_unlocked"] = true
	slice["front_gate_combat_authority_committed"] = true
	slice["warehouse_combat_authority_committed"] = true
	combat_system._formal_first_wave_slices[enemy_id] = slice
	combat_system._set_formal_enemy_tactical_motion_paused(enemy_id, true)
	combat_system._refresh_enemy_node(enemy_id)

	var enemy_hp_before := int(enemy.get("hp", 0))
	var first_move_frame := -1
	var first_attack_frame := -1
	var closest_distance := INF
	var longest_stationary_move_frames := 0
	var stationary_move_frames := 0
	var last_ada_position := ada.global_position
	var last_sample := {}
	var interrupted_move := false
	var stale_move_recovered := false
	time_system.set_paused(false)
	for frame in range(SAMPLE_FRAMES):
		await physics_frame
		var state: Dictionary = npc_system.get_npc_state(NPC_ID)
		var action := str(state.get("current_action", ""))
		var handoff: Dictionary = state.get("combat_strategy_last_handoff", {}) if state.get("combat_strategy_last_handoff", {}) is Dictionary else {}
		if str(handoff.get("reason", "")) == "combat_strategy_stale_movement_recovered":
			stale_move_recovered = true
		# Reproduce the reported split-brain state: the presentation/state still
		# says tactical movement after its physical navigation request disappeared.
		# Combat must notice this and reacquire the moving enemy by itself.
		if not interrupted_move and frame >= 30 and action.begins_with("moving_to_combat_strategy_attack"):
			ada.cancel_motion("t0192_interrupted_warehouse_intercept")
			interrupted_move = true
		var distance := ada.global_position.distance_to(enemy_actor.global_position)
		closest_distance = minf(closest_distance, distance)
		if first_move_frame < 0 and action.begins_with("moving_to_combat_strategy_attack"):
			first_move_frame = frame
		if first_attack_frame < 0 and (action.begins_with("winding_up_") or action.begins_with("attacking_")):
			first_attack_frame = frame
		var moved_distance := ada.global_position.distance_to(last_ada_position)
		if action.begins_with("moving_to_combat_strategy_attack") and moved_distance <= 0.0005:
			stationary_move_frames += 1
			longest_stationary_move_frames = maxi(longest_stationary_move_frames, stationary_move_frames)
		else:
			stationary_move_frames = 0
		last_ada_position = ada.global_position
		last_sample = {
			"frame": frame,
			"action": action,
			"distance": distance,
			"position": ada.global_position,
			"movement_target": state.get("movement_target", ""),
			"combat_target_enemy_id": state.get("combat_target_enemy_id", ""),
			"motion": ada.debug_get_motion_snapshot(),
		}
		if int(combat_system.get_enemy(enemy_id).get("hp", enemy_hp_before)) < enemy_hp_before:
			break

	var diagnostics := {
		"enemy_id": enemy_id,
		"warehouse_attack_position": enemy_position,
		"warehouse_contact_position": contact_position,
		"interrupted_move": interrupted_move,
		"stale_move_recovered": stale_move_recovered,
		"first_move_frame": first_move_frame,
		"first_attack_frame": first_attack_frame,
		"closest_distance": closest_distance,
		"longest_stationary_move_frames": longest_stationary_move_frames,
		"enemy_damage": enemy_hp_before - int(combat_system.get_enemy(enemy_id).get("hp", enemy_hp_before)),
		"last_sample": last_sample,
	}
	print("T0192_WAREHOUSE_INTERCEPT_DIAGNOSTICS %s" % JSON.stringify(diagnostics))
	_check(first_move_frame >= 0, "T0192 Ada never entered the production pursuit path: %s" % diagnostics)
	_check(interrupted_move, "T0192 regression fixture did not interrupt the tactical move: %s" % diagnostics)
	_check(stale_move_recovered, "T0192 combat did not detect and recover the missing physical movement request: %s" % diagnostics)
	_check(first_attack_frame >= 0, "T0192 Ada reached the warehouse enemy but never handed off to attack: %s" % diagnostics)
	_check(int(diagnostics.get("enemy_damage", 0)) > 0, "T0192 Ada attack did not produce model-contact damage: %s" % diagnostics)
	_check(longest_stationary_move_frames < 120, "T0192 Ada remained stationary in tactical movement for two seconds: %s" % diagnostics)

	combat_system.clear_spawned_enemies()
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0192_FRIENDLY_WAREHOUSE_INTERCEPT_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
