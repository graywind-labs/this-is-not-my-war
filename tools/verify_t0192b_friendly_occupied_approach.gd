extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const NPC_ID := "veteran_deputy_01"
const SAMPLE_FRAMES := 1200
const FRAME_SECONDS := 1.0 / 60.0

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
	var event_bus := root.get_node_or_null("EventBus")
	_check(combat_system != null and npc_system != null and equipment_system != null, "T0192B combat actor systems missing")
	_check(resource_system != null and building_system != null and time_system != null and event_bus != null, "T0192B world systems missing")
	if not _failures.is_empty():
		_finish()
		return

	time_system.set_paused(true)
	resource_system.add_resource("item_sword_shield", 1)
	_check(bool(equipment_system.equip_npc_main_weapon(NPC_ID, "sword_shield", "private").get("ok", false)), "T0192B failed to arm Ada")
	combat_system.set_npc_combat_strategy(NPC_ID, "attack", "private")
	npc_system.set_npc_recruited(NPC_ID, true)
	var spawned: Dictionary = combat_system.debug_run_formal_dynamic_wave_slice(1, true)
	_check(bool(spawned.get("ok", false)), "T0192B failed to spawn production wave: %s" % spawned)
	var enemy_ids: Array[String] = combat_system.get_active_enemy_ids()
	_check(enemy_ids.size() >= 3, "T0192B needs three production enemies")
	if enemy_ids.size() < 3:
		_finish()
		return
	var attacker_ids: Array[String] = [enemy_ids[0], enemy_ids[1], enemy_ids[2]]
	for index in range(3, enemy_ids.size()):
		combat_system._remove_enemy_from_combat(enemy_ids[index])

	var gate: Dictionary = building_system._buildings.get("front_gate", {})
	gate["hp"] = 0
	building_system._buildings["front_gate"] = gate
	var warehouse: Dictionary = building_system._buildings.get("warehouse", {})
	warehouse["hp"] = 100000
	warehouse["max_hp"] = 100000
	building_system._buildings["warehouse"] = warehouse

	var attack_positions: Array[Vector3] = []
	var contact_positions: Array[Vector3] = []
	var enemy_actors: Dictionary = {}
	for enemy_id in attacker_ids:
		var enemy: Dictionary = combat_system._active_enemies.get(enemy_id, {})
		var target: Dictionary = combat_system._make_building_target("warehouse")
		target = combat_system._ensure_enemy_attack_position(enemy_id, enemy, target, true)
		_check(str(target.get("attack_position_status", "")) == "reserved", "T0192B warehouse lease missing for %s: %s" % [enemy_id, target])
		var actor := combat_system.get_node_or_null(combat_system._formal_first_wave_node_paths.get(enemy_id, NodePath())) as ActorMotionBody
		_check(actor != null, "T0192B enemy actor missing: %s" % enemy_id)
		if actor == null or str(target.get("attack_position_status", "")) != "reserved":
			continue
		var attack_position: Vector3 = target.get("attack_position", Vector3.ZERO)
		var contact_position: Vector3 = target.get("attack_contact_position", attack_position)
		actor.cancel_motion("t0192b_stationary_warehouse_attacker")
		actor.global_position = attack_position
		actor.velocity = Vector3.ZERO
		enemy["position"] = attack_position
		# Any of the three adjacent bodies can be the first legal model contact.
		# Give each one-shot fixture HP so this regression verifies handoff after
		# the first actual defeat instead of depending on an arbitrary spawn id.
		enemy["hp"] = 20
		enemy["max_hp"] = 20
		enemy["alive"] = true
		enemy["current_action"] = "attacking_warehouse"
		enemy["formal_route_phase"] = "attacking_warehouse"
		enemy["target"] = target.duplicate(true)
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
		slice["tactical_motion_paused"] = true
		combat_system._formal_first_wave_slices[enemy_id] = slice
		combat_system._set_formal_enemy_tactical_motion_paused(enemy_id, true)
		combat_system._refresh_enemy_node(enemy_id)
		attack_positions.append(attack_position)
		contact_positions.append(contact_position)
		enemy_actors[enemy_id] = actor
	if attack_positions.size() < 3:
		_finish()
		return

	var primary_enemy_id := attacker_ids[0]
	var primary_actor := enemy_actors.get(primary_enemy_id) as ActorMotionBody
	var primary_position := attack_positions[0]
	var outward := primary_position - contact_positions[0]
	outward.y = 0.0
	outward = outward.normalized() if outward.length_squared() > 0.0001 else Vector3(-1.0, 0.0, -1.0).normalized()
	# The lease probe can snap two raw facade candidates onto the same NavMesh
	# point in this isolated fixture. Keep the second real body in the adjacent
	# warehouse slot so it reproduces the screenshot without overlapping the
	# primary target and invalidating model-contact identity.
	var tangent := Vector3(-outward.z, 0.0, outward.x)
	var secondary_enemy_id := attacker_ids[1]
	var secondary_actor := enemy_actors.get(secondary_enemy_id) as ActorMotionBody
	var secondary_position := primary_position + tangent * 0.92
	if secondary_actor != null:
		secondary_actor.global_position = secondary_position
		secondary_actor.velocity = Vector3.ZERO
		var secondary_enemy: Dictionary = combat_system._active_enemies.get(secondary_enemy_id, {})
		secondary_enemy["position"] = secondary_position
		combat_system._active_enemies[secondary_enemy_id] = secondary_enemy
		combat_system._refresh_enemy_node(secondary_enemy_id)
		attack_positions[1] = secondary_position
		contact_positions[1] = contact_positions[0] + tangent * 0.92
	var tertiary_enemy_id := attacker_ids[2]
	var tertiary_actor := enemy_actors.get(tertiary_enemy_id) as ActorMotionBody
	var tertiary_position := primary_position - tangent * 0.92
	if tertiary_actor != null:
		tertiary_actor.global_position = tertiary_position
		tertiary_actor.velocity = Vector3.ZERO
		var tertiary_enemy: Dictionary = combat_system._active_enemies.get(tertiary_enemy_id, {})
		tertiary_enemy["position"] = tertiary_position
		combat_system._active_enemies[tertiary_enemy_id] = tertiary_enemy
		combat_system._refresh_enemy_node(tertiary_enemy_id)
		attack_positions[2] = tertiary_position
		contact_positions[2] = contact_positions[0] - tangent * 0.92
	var paths: Dictionary = npc_system.get("_npc_nodes")
	var ada := npc_system.get_node_or_null(paths.get(NPC_ID, NodePath())) as ActorMotionBody
	_check(ada != null and primary_actor != null, "T0192B Ada or primary enemy actor missing")
	if ada == null or primary_actor == null:
		_finish()
		return
	ada.cancel_motion("t0192b_fixture")
	ada.global_position = primary_position + outward * 7.0
	ada.velocity = Vector3.ZERO
	npc_system.set_npc_behavior_mode(NPC_ID, "combat", "verify_t0192b_occupied_approach", {
		"state_changes": {
			"hp": 10000,
			"max_hp": 10000,
			"unconscious": false,
			"escaped": false,
			"combat_mounted": false,
			"current_action": "combat_ready",
			"combat_target_enemy_id": primary_enemy_id,
			"combat_attack_cooldown": 0.0,
		},
		"request_plan_reevaluation": false,
	})

	# Keep all three production enemies stationary on their warehouse leases. Advance
	# only friendly combat so their RVO bodies remain the exact obstruction shown
	# in the report instead of retargeting Ada and walking out to meet her.
	var combat_tick := Callable(combat_system, "_on_logical_time_tick")
	if event_bus.logical_time_tick.is_connected(combat_tick):
		event_bus.logical_time_tick.disconnect(combat_tick)
	var hp_before := _enemy_hp_total(combat_system, attacker_ids)
	var survivor_ids: Array[String] = []
	var survivor_hp_before := -1
	var first_defeated_enemy_id := ""
	var closest_distance := INF
	var longest_stationary_move_frames := 0
	var stationary_move_frames := 0
	var request_ids: Array[String] = []
	var last_position := ada.global_position
	var last_sample := {}
	var first_attack_frame := -1
	var first_defeat_frame := -1
	var survivor_attack_frame := -1
	var post_defeat_stationary_move_frames := 0
	var longest_post_defeat_stationary_move_frames := 0
	var post_defeat_targets: Array[String] = []
	time_system.set_paused(false)
	for frame in range(SAMPLE_FRAMES):
		# Advance through the authoritative wrapper so the shared monotonic combat
		# clock used by both enemy and friendly cadence locks progresses as well.
		combat_system._advance_combat_ai(FRAME_SECONDS, false)
		await physics_frame
		var state: Dictionary = npc_system.get_npc_state(NPC_ID)
		var action := str(state.get("current_action", ""))
		var motion: Dictionary = ada.debug_get_motion_snapshot()
		var request_id := str(motion.get("request_id", ""))
		if not request_id.is_empty() and (request_ids.is_empty() or request_ids[-1] != request_id):
			request_ids.append(request_id)
		var distance := _nearest_active_enemy_distance(combat_system, ada.global_position, attacker_ids)
		closest_distance = minf(closest_distance, distance)
		if first_attack_frame < 0 and (action.begins_with("winding_up_") or action.begins_with("attacking_")):
			first_attack_frame = frame
		var displacement := ada.global_position.distance_to(last_position)
		if action.begins_with("moving_to_combat_strategy_attack") and displacement <= 0.0005:
			stationary_move_frames += 1
			longest_stationary_move_frames = maxi(longest_stationary_move_frames, stationary_move_frames)
		else:
			stationary_move_frames = 0
		if first_defeat_frame < 0:
			for enemy_id in attacker_ids:
				if not combat_system._active_enemies.has(enemy_id):
					first_defeat_frame = frame
					first_defeated_enemy_id = enemy_id
					break
			if first_defeat_frame >= 0:
				for enemy_id in attacker_ids:
					if combat_system._active_enemies.has(enemy_id):
						survivor_ids.append(enemy_id)
				survivor_hp_before = _enemy_hp_total(combat_system, survivor_ids)
		if first_defeat_frame >= 0:
			var target_enemy_id := str(state.get("combat_target_enemy_id", ""))
			if not target_enemy_id.is_empty() and (post_defeat_targets.is_empty() or post_defeat_targets[-1] != target_enemy_id):
				post_defeat_targets.append(target_enemy_id)
			if action.begins_with("moving_to_combat_strategy_attack") and displacement <= 0.0005:
				post_defeat_stationary_move_frames += 1
				longest_post_defeat_stationary_move_frames = maxi(
					longest_post_defeat_stationary_move_frames,
					post_defeat_stationary_move_frames
				)
			else:
				post_defeat_stationary_move_frames = 0
			if survivor_attack_frame < 0 and survivor_hp_before >= 0 and _enemy_hp_total(combat_system, survivor_ids) < survivor_hp_before:
				survivor_attack_frame = frame
		last_position = ada.global_position
		last_sample = {
			"frame": frame,
			"action": action,
			"distance": distance,
			"position": ada.global_position,
			"target_position": motion.get("target_position", Vector3.ZERO),
			"motion_state": motion.get("state", ""),
			"motion_active": motion.get("active", false),
			"remaining_path_distance": motion.get("remaining_path_distance", INF),
			"minimum_target_distance": motion.get("minimum_target_distance", INF),
			"stuck_elapsed_seconds": motion.get("stuck_elapsed_seconds", 0.0),
			"repath_count": motion.get("repath_count", 0),
			"last_sample_path_progress": motion.get("last_sample_path_progress", 0.0),
		}
		if survivor_attack_frame >= 0:
			break

	var final_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	var last_contact: Dictionary = combat_system.get("_last_melee_contact_result")
	var active_swings: Dictionary = combat_system.get("_active_melee_swings")
	var diagnostics := {
		"primary_enemy_id": primary_enemy_id,
		"attacker_ids": attacker_ids,
		"attack_positions": attack_positions,
		"contact_positions": contact_positions,
		"first_attack_frame": first_attack_frame,
		"closest_distance": closest_distance,
		"longest_stationary_move_frames": longest_stationary_move_frames,
		"request_ids": request_ids,
		"enemy_damage": hp_before - _enemy_hp_total(combat_system, attacker_ids),
		"first_defeat_frame": first_defeat_frame,
		"first_defeated_enemy_id": first_defeated_enemy_id,
		"survivor_attack_frame": survivor_attack_frame,
		"survivor_damage": survivor_hp_before - _enemy_hp_total(combat_system, survivor_ids),
		"post_defeat_targets": post_defeat_targets,
		"longest_post_defeat_stationary_move_frames": longest_post_defeat_stationary_move_frames,
		"last_sample": last_sample,
		"final_attack_phase": str(final_state.get("combat_attack_phase", "")),
		"final_attack_target_enemy_id": str(final_state.get("combat_attack_target_enemy_id", "")),
		"last_contact_status": str(last_contact.get("status", "")),
		"last_contact_source_side": str(last_contact.get("source_side", "")),
		"last_contact_actual_target_id": str(last_contact.get("actual_target_id", "")),
		"friendly_swing_active": active_swings.has("friendly:%s" % NPC_ID),
	}
	print("T0192B_OCCUPIED_APPROACH_DIAGNOSTICS %s" % JSON.stringify(diagnostics))
	_check(first_attack_frame >= 0, "T0192B Ada never handed off from the occupied approach to attack: %s" % diagnostics)
	_check(first_defeat_frame >= 0, "T0192B Ada never defeated any first warehouse attacker: %s" % diagnostics)
	_check(survivor_attack_frame >= 0, "T0192B Ada never handed off to either surviving warehouse attacker: %s" % diagnostics)
	_check(int(diagnostics.get("survivor_damage", 0)) > 0, "T0192B Ada never dealt model-contact damage after the target defeat: %s" % diagnostics)
	_check(longest_stationary_move_frames < 120, "T0192B Ada remained stationary in tactical movement for two seconds: %s" % diagnostics)
	_check(longest_post_defeat_stationary_move_frames < 120, "T0192B Ada remained stationary after defeating the first target: %s" % diagnostics)

	combat_system.clear_spawned_enemies()
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _nearest_active_enemy_distance(combat_system: Node, position: Vector3, enemy_ids: Array[String]) -> float:
	var nearest := INF
	for enemy_id in enemy_ids:
		var enemy: Dictionary = combat_system.get_enemy(enemy_id)
		if enemy.is_empty() or not bool(enemy.get("alive", true)):
			continue
		nearest = minf(nearest, position.distance_to(enemy.get("position", position)))
	return nearest


func _enemy_hp_total(combat_system: Node, enemy_ids: Array[String]) -> int:
	var total := 0
	for enemy_id in enemy_ids:
		total += int(combat_system.get_enemy(enemy_id).get("hp", 0))
	return total


func _finish() -> void:
	if _failures.is_empty():
		print("T0192B_FRIENDLY_OCCUPIED_APPROACH_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
