extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const ADA_ID := "veteran_deputy_01"
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
	for _frame in range(6):
		await process_frame
		await physics_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var event_bus := root.get_node_or_null("EventBus")
	_check(combat_system != null and npc_system != null, "T0215 combat/NPC systems missing")
	_check(building_system != null and time_system != null and event_bus != null, "T0215 world systems missing")
	if not _failures.is_empty():
		_finish()
		return

	time_system.set_paused(true)
	var started: Dictionary = combat_system.debug_run_formal_dynamic_wave_slice(1, true)
	_check(bool(started.get("ok", false)), "T0215 production wave failed to spawn: %s" % started)
	var enemy_ids: Array[String] = combat_system.get_active_enemy_ids()
	_check(enemy_ids.size() >= 3, "T0215 needs three production enemy bodies")
	if not _failures.is_empty():
		_finish()
		return

	var subject_id := enemy_ids[0]
	var side_ids := [enemy_ids[1], enemy_ids[2]]
	for index in range(3, enemy_ids.size()):
		combat_system._remove_enemy_from_combat(enemy_ids[index])
	var subject := combat_system.get_node_or_null(
		combat_system._formal_first_wave_node_paths.get(subject_id, NodePath())
	) as ActorMotionBody
	var ada := npc_system.get_node_or_null(npc_system._npc_nodes.get(ADA_ID, NodePath())) as ActorMotionBody
	_check(subject != null and ada != null, "T0215 production subject/Ada body missing")
	if not _failures.is_empty():
		_finish()
		return

	var gate_hp := int(building_system.get_building("front_gate").get("hp", 0))
	if gate_hp > 0:
		building_system.apply_damage_to_building("front_gate", gate_hp, "t0215_fixture", "system")
	for npc_id in npc_system.get_npc_ids():
		npc_system.set_npc_equipment_slot(npc_id, "main_weapon", {})
		if npc_id != ADA_ID:
			_set_npc_position(npc_system, npc_id, Vector3(55.0 + float(npc_id.hash() % 7), 0.2, 55.0))

	var warehouse_target: Dictionary = combat_system._make_building_target("warehouse")
	var warehouse_position: Vector3 = warehouse_target.get("position", Vector3.ZERO)
	var navigation_map := subject.get_navigation_map()
	var fixture_center := Vector3(0.0, subject.global_position.y, 18.0)
	if navigation_map.is_valid():
		fixture_center = NavigationServer3D.map_get_closest_point(navigation_map, fixture_center)
	fixture_center.y = subject.global_position.y
	var toward_warehouse := warehouse_position - fixture_center
	toward_warehouse.y = 0.0
	if toward_warehouse.length_squared() <= 0.0001:
		toward_warehouse = Vector3.FORWARD
	toward_warehouse = toward_warehouse.normalized()
	var side_direction := Vector3(-toward_warehouse.z, 0.0, toward_warehouse.x)
	var subject_position := fixture_center - toward_warehouse * 0.77

	subject.cancel_motion("t0215_fixture")
	subject.global_position = subject_position
	_set_enemy_position(combat_system, subject_id, subject_position)
	for side_index in range(side_ids.size()):
		var side_id := str(side_ids[side_index])
		var side_actor := combat_system.get_node_or_null(
			combat_system._formal_first_wave_node_paths.get(side_id, NodePath())
		) as ActorMotionBody
		_check(side_actor != null, "T0215 side blocker missing: %s" % side_id)
		if side_actor == null:
			continue
		side_actor.cancel_motion("t0215_stationary_crowd")
		var side_sign := -1.0 if side_index == 0 else 1.0
		var side_position := subject_position + side_direction * 0.82 * side_sign
		side_actor.global_position = side_position
		_set_enemy_position(combat_system, side_id, side_position)
		combat_system._set_formal_enemy_tactical_motion_paused(side_id, true)

	_set_npc_position(npc_system, ADA_ID, fixture_center)
	npc_system.set_npc_behavior_mode(ADA_ID, "combat", "verify_t0215_fixture", {
		"state_changes": {
			"hp": 1,
			"max_hp": 120,
			"unconscious": false,
			"escaped": false,
			"current_action": "combat_ready",
		},
		"request_plan_reevaluation": false,
	})
	for _frame in range(3):
		await physics_frame

	var subject_enemy: Dictionary = combat_system.get_enemy(subject_id)
	subject_enemy["position"] = subject.global_position
	subject_enemy["attack_power"] = 1000.0
	subject_enemy["stagger_remaining"] = 0.0
	subject_enemy["target"] = {}
	combat_system._cancel_enemy_attack_timeline(subject_enemy)
	combat_system._active_enemies[subject_id] = subject_enemy
	var ada_target: Dictionary = combat_system._select_formal_dynamic_enemy_target(subject_id, subject_enemy)
	_check(str(ada_target.get("id", "")) == ADA_ID, "T0215 enemy did not acquire conscious Ada: %s" % ada_target)
	var damage_result: Dictionary = combat_system._apply_enemy_attack_to_npc(
		subject_enemy,
		ADA_ID,
		1000,
		1000.0,
		0.0,
		0.0,
		0.0
	)
	_check(bool((damage_result.get("result", {}) as Dictionary).get("unconscious", false)), "T0215 authority hit did not knock Ada unconscious: %s" % damage_result)
	await physics_frame
	var ada_state: Dictionary = npc_system.get_npc_state(ADA_ID)
	var ada_attachment: Dictionary = ada.debug_get_spatial_attachment_snapshot()
	_check(bool(ada_state.get("unconscious", false)), "T0215 Ada unconscious state missing")
	_check(bool(ada_attachment.get("body_collision_disabled", false)), "T0215 unconscious Ada kept her physical body collider")
	_check(not bool(ada_attachment.get("navigation_avoidance_enabled", true)), "T0215 unconscious Ada remained an RVO avoidance body")
	_check(bool(ada_attachment.get("interaction_enabled", false)), "T0215 unconscious Ada lost her interaction entity")

	var combat_tick := Callable(combat_system, "_on_logical_time_tick")
	if event_bus.logical_time_tick.is_connected(combat_tick):
		event_bus.logical_time_tick.disconnect(combat_tick)
	time_system.set_paused(false)
	var subject_only: Array[String] = [subject_id]
	combat_system._advance_enemy_ai(0.1, 0.1, subject_only)
	var handoff_enemy: Dictionary = combat_system.get_enemy(subject_id)
	var handoff_target: Dictionary = handoff_enemy.get("target", {})
	var handoff_motion: Dictionary = subject.debug_get_motion_snapshot()
	_check(str(handoff_target.get("id", "")) == "warehouse", "T0215 enemy did not hand off from unconscious Ada to warehouse: %s" % handoff_target)
	_check(str(handoff_enemy.get("current_action", "")).begins_with("pressing_to_warehouse"), "T0215 visible handoff action mismatch: %s" % handoff_enemy)
	_check(bool(handoff_motion.get("active", false)) and not bool(handoff_motion.get("paused", true)), "T0215 warehouse motion was inactive or retained tactical pause: %s" % handoff_motion)

	var movement_start := subject.global_position
	var minimum_warehouse_distance := movement_start.distance_to(warehouse_position)
	for _frame in range(600):
		await physics_frame
		minimum_warehouse_distance = minf(minimum_warehouse_distance, subject.global_position.distance_to(warehouse_position))
		if subject.global_position.distance_to(movement_start) >= 1.25:
			break
	var final_motion: Dictionary = subject.debug_get_motion_snapshot()
	var displacement := subject.global_position.distance_to(movement_start)
	_check(displacement >= 1.25, "T0215 enemy kept running in place against the unconscious/crowd contact: %s" % final_motion)
	_check(minimum_warehouse_distance <= movement_start.distance_to(warehouse_position) - 0.35, "T0215 local release never rejoined warehouse route: %s" % final_motion)
	_check(float(final_motion.get("maximum_observed_speed", INF)) <= float(final_motion.get("profile_base_speed", 0.0)) + 0.01, "T0215 local recovery exceeded profile speed: %s" % final_motion)
	_check(bool(ada.debug_get_spatial_attachment_snapshot().get("body_collision_disabled", false)), "T0215 movement restored the still-unconscious NPC body too early")

	ada.attach_to_spatial_anchor(ada.global_position, ada.global_transform.basis.z, "lying_supine")
	await physics_frame
	ada.detach_from_spatial_anchor()
	for _frame in range(2):
		await physics_frame
	var detached_while_unconscious: Dictionary = ada.debug_get_spatial_attachment_snapshot()
	_check(bool(detached_while_unconscious.get("body_collision_disabled", false)), "T0215 detaching an unconscious NPC restored body collision too early: %s" % detached_while_unconscious)
	_check(not bool(detached_while_unconscious.get("navigation_avoidance_enabled", true)), "T0215 detaching an unconscious NPC restored RVO presence too early: %s" % detached_while_unconscious)

	var revive_result: Dictionary = npc_system._revive_npc_from_unconscious(ADA_ID, 0, 36, "t0215_verification")
	_check(bool(revive_result.get("revived", false)), "T0215 fixture failed to revive Ada: %s" % revive_result)
	for _frame in range(3):
		await physics_frame
	var revived_attachment: Dictionary = ada.debug_get_spatial_attachment_snapshot()
	_check(not bool(revived_attachment.get("body_collision_disabled", true)), "T0215 revived Ada did not restore body collision: %s" % revived_attachment)
	_check(bool(revived_attachment.get("navigation_avoidance_enabled", false)), "T0215 revived Ada did not restore RVO presence: %s" % revived_attachment)

	if _failures.is_empty():
		print("T0215_UNCONSCIOUS_TARGET_HANDOFF_MOTION_OK %s" % JSON.stringify({
			"subject_id": subject_id,
			"target_after_knockout": str(handoff_target.get("id", "")),
			"motion_request": str(handoff_motion.get("request_id", "")),
			"displacement": displacement,
			"warehouse_progress": movement_start.distance_to(warehouse_position) - minimum_warehouse_distance,
			"maximum_speed": float(final_motion.get("maximum_observed_speed", 0.0)),
			"unconscious_body_collision_disabled": bool(ada_attachment.get("body_collision_disabled", false)),
			"unconscious_interaction_enabled": bool(ada_attachment.get("interaction_enabled", false)),
			"detached_while_unconscious_body_collision_disabled": bool(detached_while_unconscious.get("body_collision_disabled", false)),
			"revived_body_collision_disabled": bool(revived_attachment.get("body_collision_disabled", true)),
		}))
	combat_system.clear_spawned_enemies()
	_finish()


func _set_enemy_position(combat_system: Node, enemy_id: String, position: Vector3) -> void:
	var enemy: Dictionary = combat_system.get_enemy(enemy_id)
	enemy["position"] = position
	enemy["hp"] = maxi(10000, int(enemy.get("hp", 0)))
	enemy["max_hp"] = maxi(10000, int(enemy.get("max_hp", 0)))
	enemy["alive"] = true
	combat_system._active_enemies[enemy_id] = enemy


func _set_npc_position(npc_system: Node, npc_id: String, position: Vector3) -> void:
	var npc_node := npc_system.get_node_or_null(npc_system._npc_nodes.get(npc_id, NodePath())) as ActorMotionBody
	if npc_node == null:
		return
	npc_node.stop_movement()
	npc_node.global_position = Vector3(position.x, npc_node.global_position.y, position.z)


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
