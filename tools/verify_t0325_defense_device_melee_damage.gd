extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const MAX_FRAMES_PER_GUIDE := 300
const REQUIRED_COMPLETED_ATTACKS := 2

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

	var combat := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var device_system := root.get_node_or_null("Main/Systems/DefenseDeviceSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	_check(combat != null and npc_system != null and device_system != null, "T0325 combat systems missing")
	_check(building_system != null and resource_system != null and time_system != null, "T0325 world systems missing")
	if not _failures.is_empty():
		_finish()
		return

	_set_building_level(building_system, "wall", 4)
	resource_system.add_resource("item_wall_ballista", 1)
	var deployed: Dictionary = device_system.deploy_device("wall_ballista", "wall_slot_01")
	_check(bool(deployed.get("ok", false)), "T0325 ballista deployment failed: %s" % deployed)
	if not _failures.is_empty():
		_finish()
		return
	var deployment_id := str(deployed.get("deployment_id", ""))
	for index in range(npc_system.get_npc_ids().size()):
		var npc_id := str(npc_system.get_npc_ids()[index])
		var npc_node := root.get_node_or_null(npc_system._npc_nodes.get(npc_id, NodePath())) as Node3D
		if npc_node != null:
			npc_node.global_position = Vector3(-42.0 + float(index) * 1.5, 0.0, 12.0)

	var started: Dictionary = combat.debug_run_formal_dynamic_wave_slice(1, true)
	_check(bool(started.get("ok", false)), "T0325 formal wave failed to spawn: %s" % started)
	var enemy_ids: Array[String] = combat.get_active_enemy_ids()
	_check(not enemy_ids.is_empty(), "T0325 formal wave has no enemy")
	if not _failures.is_empty():
		_finish()
		return
	var enemy_id := enemy_ids[0]
	for index in range(1, enemy_ids.size()):
		combat._remove_enemy_from_combat(enemy_ids[index])
	var actor := combat.get_node_or_null(combat._formal_first_wave_node_paths.get(enemy_id, NodePath())) as ActorMotionBody
	_check(actor != null, "T0325 formal enemy actor missing")
	if actor == null:
		_finish()
		return

	var enemy: Dictionary = combat._active_enemies.get(enemy_id, {})
	enemy["hp"] = 10000
	enemy["max_hp"] = 10000
	combat._active_enemies[enemy_id] = enemy
	var base_target: Dictionary = combat._make_defense_device_enemy_target(deployment_id, enemy.get("position", Vector3.ZERO))
	var candidates: Array[Dictionary] = combat._get_enemy_attack_position_candidates(enemy_id, enemy, base_target)
	var reachable: Array[Dictionary] = []
	for candidate in candidates:
		var resolved: Dictionary = combat._resolve_reachable_enemy_attack_position(enemy_id, candidate)
		if not resolved.is_empty():
			reachable.append(resolved)
	_check(not reachable.is_empty(), "T0325 wall ballista has no reachable melee guidance zones")
	if not _failures.is_empty():
		_finish()
		return

	time_system.set_paused(false)
	var guide_results: Array[Dictionary] = []
	for candidate in reachable:
		var result := await _verify_guide_damage(combat, device_system, actor, enemy_id, deployment_id, candidate)
		guide_results.append(result)
		_check(bool(result.get("damaged", false)), "T0325 attacker completed device melee attacks without damage: %s" % JSON.stringify(result))

	var wall_hp := int(building_system.get_building("wall").get("hp", 0))
	var diagnostics := {
		"deployment_id": deployment_id,
		"enemy_id": enemy_id,
		"reachable_guide_count": reachable.size(),
		"guide_results": guide_results,
		"wall_hp_after": wall_hp,
		"last_melee_status": str((combat.debug_get_combat_snapshot().get("last_melee_contact_result", {}) as Dictionary).get("status", ""))
	}
	print("T0325_DEFENSE_DEVICE_MELEE_DAMAGE_DIAGNOSTICS %s" % JSON.stringify(diagnostics))
	_check(wall_hp == int(building_system.get_building("wall").get("max_hp", wall_hp)), "T0325 device proxy damage leaked into wall HP: %s" % diagnostics)
	combat.clear_spawned_enemies()
	_finish()


func _verify_guide_damage(
	combat: Node,
	device_system: Node,
	actor: ActorMotionBody,
	enemy_id: String,
	deployment_id: String,
	candidate: Dictionary
) -> Dictionary:
	combat._release_enemy_attack_position(enemy_id, "t0325_guide_reset", false, false)
	var enemy: Dictionary = combat._active_enemies.get(enemy_id, {})
	combat._cancel_enemy_attack_timeline(enemy)
	var position: Vector3 = candidate.get("position", actor.global_position)
	position.y = actor.global_position.y
	actor.cancel_motion("t0325_guide_reset")
	actor.global_position = position
	actor.velocity = Vector3.ZERO
	enemy["position"] = position
	enemy["hp"] = 10000
	enemy["max_hp"] = 10000
	enemy["alive"] = true
	enemy["target"] = {}
	enemy["current_action"] = "combat_ready"
	combat._active_enemies[enemy_id] = enemy

	var deployment: Dictionary = device_system._deployments.get(deployment_id, {})
	deployment["hp"] = 5000
	deployment["max_hp"] = 5000
	device_system._deployments[deployment_id] = deployment
	var hp_before := int(deployment.get("hp", 0))
	var sequence_before := int(enemy.get("attack_sequence", 0))
	var completed_attacks := 0
	var observed_slot_ids := PackedStringArray()
	for _frame in range(MAX_FRAMES_PER_GUIDE):
		await physics_frame
		var live_enemy: Dictionary = combat.get_enemy(enemy_id)
		var live_target: Dictionary = live_enemy.get("target", {}) if live_enemy.get("target", {}) is Dictionary else {}
		var slot_id := str(live_target.get("attack_position_id", ""))
		if not slot_id.is_empty() and not observed_slot_ids.has(slot_id):
			observed_slot_ids.append(slot_id)
		var last_attack: Dictionary = live_enemy.get("last_attack_result", {}) if live_enemy.get("last_attack_result", {}) is Dictionary else {}
		completed_attacks = maxi(completed_attacks, int(last_attack.get("attack_sequence", sequence_before)) - sequence_before)
		var live_deployment: Dictionary = device_system.get_deployment(deployment_id)
		var hp_after := int(live_deployment.get("hp", 0))
		if hp_after < hp_before:
			var last_melee: Dictionary = combat.debug_get_combat_snapshot().get("last_melee_contact_result", {})
			return {
				"slot_id": str(candidate.get("slot_id", "")),
				"observed_slot_ids": observed_slot_ids,
				"completed_attacks": completed_attacks,
				"hp_before": hp_before,
				"hp_after": hp_after,
				"damaged": true,
				"attack_position_id": str(live_target.get("attack_position_id", "")),
				"last_melee_status": str(last_melee.get("status", "")),
				"last_melee_reason": str(last_melee.get("reason", "")),
				"last_melee_collision_position": last_melee.get("collision_position", Vector3.ZERO)
			}
		if completed_attacks >= REQUIRED_COMPLETED_ATTACKS:
			break
	var live_enemy: Dictionary = combat.get_enemy(enemy_id)
	var live_deployment: Dictionary = device_system.get_deployment(deployment_id)
	var live_target: Dictionary = live_enemy.get("target", {}) if live_enemy.get("target", {}) is Dictionary else {}
	var last_melee: Dictionary = combat.debug_get_combat_snapshot().get("last_melee_contact_result", {})
	return {
		"slot_id": str(candidate.get("slot_id", "")),
		"observed_slot_ids": observed_slot_ids,
		"completed_attacks": completed_attacks,
		"hp_before": hp_before,
		"hp_after": int(live_deployment.get("hp", 0)),
		"damaged": int(live_deployment.get("hp", 0)) < hp_before,
		"attack_position_id": str(live_target.get("attack_position_id", "")),
		"last_melee_status": str(last_melee.get("status", "")),
		"last_melee_reason": str(last_melee.get("reason", "")),
		"last_melee_collision_identity": last_melee.get("collision_identity", {}),
		"last_melee_collision_position": last_melee.get("collision_position", Vector3.ZERO)
	}


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
		print("T0325_DEFENSE_DEVICE_MELEE_DAMAGE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
