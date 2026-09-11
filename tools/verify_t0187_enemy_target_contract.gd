extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const SAMPLE_FRAMES := 480

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
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	_check(combat_system != null and npc_system != null and device_system != null, "T0187 combat unit systems missing")
	_check(building_system != null and resource_system != null and time_system != null, "T0187 world systems missing")
	if not _failures.is_empty():
		_finish()
		return
	time_system.set_paused(true)

	# Only the three authored assault-route buildings may become enemy building targets.
	_check(combat_system._make_building_target("training_ground").is_empty(), "T0187 training ground entered the enemy building target API")
	_check(combat_system._make_building_target("kitchen").is_empty(), "T0187 ordinary building entered the enemy building target API")
	for building_id in ["front_gate", "warehouse", "main_hall"]:
		_check(not combat_system._make_building_target(building_id).is_empty(), "T0187 legal building target missing: %s" % building_id)

	_set_building_level(building_system, "wall", 4)
	resource_system.add_resource("item_wall_ballista", 1)
	var deployed: Dictionary = device_system.deploy_device("wall_ballista", "wall_slot_02")
	_check(bool(deployed.get("ok", false)), "T0187 wall-slot-02 fixture deployment failed: %s" % deployed)
	if not bool(deployed.get("ok", false)):
		_finish()
		return
	var deployment_id := str(deployed.get("deployment_id", ""))
	var device_target := _find_target(device_system.get_active_defense_targets(), deployment_id)
	_check(not device_target.is_empty(), "T0187 active wall defense target missing")

	var started: Dictionary = combat_system.debug_run_formal_dynamic_wave_slice(1, true)
	_check(bool(started.get("ok", false)), "T0187 formal enemy failed to spawn: %s" % started)
	var enemy_ids: Array[String] = combat_system.get_active_enemy_ids()
	_check(not enemy_ids.is_empty(), "T0187 spawned no enemy")
	if not _failures.is_empty():
		_finish()
		return
	var enemy_id := enemy_ids[0]
	for index in range(1, enemy_ids.size()):
		combat_system._remove_enemy_from_combat(enemy_ids[index])

	var actor := combat_system.get_node_or_null(combat_system._formal_first_wave_node_paths.get(enemy_id, NodePath())) as ActorMotionBody
	_check(actor != null, "T0187 production enemy actor missing")
	if actor == null:
		_finish()
		return
	var device_position := _to_vector3(device_target.get("position", {}))
	var outward := _to_vector3(device_target.get("facing_direction", {"z": 1.0}))
	outward.y = 0.0
	outward = outward.normalized() if outward.length_squared() > 0.0001 else Vector3.FORWARD
	_set_enemy_position(combat_system, enemy_id, actor, device_position + outward * 4.0)
	for index in range(npc_system.get_npc_ids().size()):
		var npc_id := str(npc_system.get_npc_ids()[index])
		var npc_node := combat_system.get_node_or_null(npc_system._npc_nodes.get(npc_id, NodePath())) as Node3D
		if npc_node != null:
			npc_node.global_position = Vector3(-30.0 + float(index) * 2.0, 0.0, 20.0)

	var selected := _fresh_select(combat_system, enemy_id)
	_check(str(selected.get("type", "")) == "defense_device", "T0187 wall defense was replaced by a building target: %s" % selected)
	_check(str(selected.get("id", "")) == deployment_id, "T0187 selected the wrong target near wall slot 02: %s" % selected)
	_check(int(selected.get("target_priority", 0)) == 1, "T0187 wall defense did not join the unified armed-NPC/device tier: %s" % selected)
	_check(combat_system._find_attackable_obstruction_target(enemy_id, device_target).is_empty(), "T0187 wall defense was still classified behind the front gate")
	if not _failures.is_empty():
		combat_system.clear_spawned_enemies()
		_finish()
		return

	var enemy: Dictionary = combat_system.get_enemy(enemy_id)
	enemy["hp"] = 10000
	enemy["max_hp"] = 10000
	combat_system._active_enemies[enemy_id] = enemy
	selected = combat_system._ensure_enemy_attack_position(enemy_id, enemy, selected, true)
	_check(str(selected.get("attack_position_status", "")) == "reserved", "T0187 wall defense produced no reachable attack position: %s" % selected)
	if str(selected.get("attack_position_status", "")) != "reserved":
		combat_system.clear_spawned_enemies()
		_finish()
		return
	var attack_position := _to_vector3(selected.get("attack_position", actor.global_position))
	var contact_position := _to_vector3(selected.get("attack_contact_position", device_position))
	var contact_outward := attack_position - contact_position
	contact_outward.y = 0.0
	contact_outward = contact_outward.normalized() if contact_outward.length_squared() > 0.0001 else outward
	actor.cancel_motion("t0187_device_damage_fixture")
	_set_enemy_position(combat_system, enemy_id, actor, attack_position + contact_outward * 0.30)
	combat_system.debug_step_enemy_ai(0.01)
	var hp_before := int(device_system.get_deployment(deployment_id).get("hp", 0))
	var sequence_before := int(combat_system.get_enemy(enemy_id).get("attack_sequence", 0))
	time_system.set_paused(false)
	for _frame in range(SAMPLE_FRAMES):
		await physics_frame
	var final_enemy: Dictionary = combat_system.get_enemy(enemy_id)
	var final_deployment: Dictionary = device_system.get_deployment(deployment_id)
	var hp_after := int(final_deployment.get("hp", 0)) if not final_deployment.is_empty() else 0
	var diagnostics := {
		"selected_target": selected.get("id", ""),
		"priority": selected.get("target_priority", 0),
		"attack_sequence_delta": int(final_enemy.get("attack_sequence", 0)) - sequence_before,
		"device_hp_before": hp_before,
		"device_hp_after": hp_after,
		"enemy_action": final_enemy.get("current_action", ""),
		"last_melee": combat_system.debug_get_combat_snapshot().get("last_melee_contact_result", {}),
	}
	print("T0187_TARGET_DAMAGE_DIAGNOSTICS %s" % JSON.stringify(diagnostics))
	_check(int(diagnostics.get("attack_sequence_delta", 0)) >= 2, "T0187 enemy did not sustain attacks against wall defense: %s" % diagnostics)
	_check(hp_after < hp_before, "T0187 enemy animated against wall defense without reducing device HP: %s" % diagnostics)
	time_system.set_paused(true)
	if not final_deployment.is_empty():
		device_system.apply_damage_to_device(deployment_id, 100000, {"attacker_id": "t0187_cleanup"})
	await physics_frame
	var fallback := _fresh_select(combat_system, enemy_id)
	_check(str(fallback.get("id", "")) == "front_gate", "T0187 destroyed wall defense did not fall back to front gate: %s" % fallback)
	_check(int(fallback.get("target_priority", 0)) == 3, "T0187 front-gate fallback priority was not 3: %s" % fallback)

	combat_system.clear_spawned_enemies()
	_finish()


func _fresh_select(combat_system: Node, enemy_id: String) -> Dictionary:
	combat_system._release_enemy_attack_position(enemy_id, "t0187_fresh_select", false, false)
	var enemy: Dictionary = combat_system.get_enemy(enemy_id)
	enemy["target"] = {}
	enemy["target_priority"] = 0
	enemy["target_lock_until_frame"] = 0
	enemy["target_last_evaluated_frame"] = -100
	enemy["attack_cycle_phase"] = "idle"
	enemy["attack_impact_committed"] = false
	combat_system._active_enemies[enemy_id] = enemy
	return combat_system._select_formal_dynamic_enemy_target(enemy_id, enemy)


func _set_enemy_position(combat_system: Node, enemy_id: String, actor: ActorMotionBody, position: Vector3) -> void:
	actor.global_position = position
	actor.velocity = Vector3.ZERO
	var enemy: Dictionary = combat_system.get_enemy(enemy_id)
	enemy["position"] = position
	combat_system._active_enemies[enemy_id] = enemy


func _set_building_level(building_system: Node, building_id: String, level: int) -> void:
	var building: Dictionary = building_system._buildings.get(building_id, {})
	building["level"] = level
	building_system._buildings[building_id] = building


func _find_target(targets: Array[Dictionary], target_id: String) -> Dictionary:
	for target in targets:
		if str(target.get("id", "")) == target_id:
			return target
	return {}


func _to_vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Dictionary:
		return Vector3(float(value.get("x", 0.0)), float(value.get("y", 0.0)), float(value.get("z", 0.0)))
	return Vector3.ZERO


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0187_ENEMY_TARGET_CONTRACT_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
