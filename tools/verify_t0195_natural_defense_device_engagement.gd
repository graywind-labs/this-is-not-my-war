extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const SAMPLE_FRAMES := 3000

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
	_check(combat_system != null and npc_system != null and device_system != null, "T0195 combat systems missing")
	_check(building_system != null and resource_system != null and time_system != null, "T0195 world systems missing")
	if not _failures.is_empty():
		_finish()
		return

	_set_building_level(building_system, "wall", 4)
	resource_system.add_resource("item_wall_ballista", 1)
	var deployed: Dictionary = device_system.deploy_device("wall_ballista", "wall_slot_01")
	_check(bool(deployed.get("ok", false)), "T0195 ballista deployment failed: %s" % deployed)
	if not _failures.is_empty():
		_finish()
		return
	var deployment_id := str(deployed.get("deployment_id", ""))
	for index in range(npc_system.get_npc_ids().size()):
		var npc_id := str(npc_system.get_npc_ids()[index])
		var npc_node := root.get_node_or_null(npc_system._npc_nodes.get(npc_id, NodePath())) as Node3D
		if npc_node != null:
			npc_node.global_position = Vector3(-42.0 + float(index) * 1.5, 0.0, 12.0)

	var gate_hp_before := int(building_system.get_building("front_gate").get("hp", 0))
	var device_hp_before := int(device_system.get_deployment(deployment_id).get("hp", 0))
	var started: Dictionary = combat_system.debug_run_formal_dynamic_wave_slice(1, true)
	_check(bool(started.get("ok", false)), "T0195 formal wave failed to spawn: %s" % started)
	_check(combat_system.get_active_enemy_ids().size() == 8, "T0195 expected full first wave")
	if not _failures.is_empty():
		_finish()
		return
	time_system.set_paused(false)

	var first_device_damage_frame := -1
	var device_damage_frames: Array[int] = []
	var previous_device_hp := device_hp_before
	var target_device_frames := 0
	var target_gate_frames := 0
	var minimum_attack_position_distance := INF
	var closest_enemy_id := ""
	var action_counts: Dictionary = {}
	var last_attack_positions: Dictionary = {}
	var observed_defense_waiter_reasons: Dictionary = {}
	for frame in range(SAMPLE_FRAMES):
		await physics_frame
		var deployment: Dictionary = device_system.get_deployment(deployment_id)
		var current_device_hp := int(deployment.get("hp", 0)) if not deployment.is_empty() else 0
		if current_device_hp < previous_device_hp:
			device_damage_frames.append(frame)
			previous_device_hp = current_device_hp
			if first_device_damage_frame < 0:
				first_device_damage_frame = frame
		if device_damage_frames.size() >= 3 or deployment.is_empty():
			break
		for enemy_id in combat_system.get_active_enemy_ids():
			var enemy: Dictionary = combat_system.get_enemy(enemy_id)
			var target := enemy.get("target", {}) as Dictionary
			var target_id := str(target.get("id", ""))
			if target_id == deployment_id:
				target_device_frames += 1
			elif target_id == "front_gate":
				target_gate_frames += 1
			var action := str(enemy.get("current_action", ""))
			action_counts[action] = int(action_counts.get(action, 0)) + 1
			if action == "waiting_for_attack_position" and target_id == deployment_id:
				observed_defense_waiter_reasons[enemy_id] = {
					"enemy_id": enemy_id,
					"reason": str(target.get("attack_position_wait_reason", "")),
					"movement_policy": str(target.get("attack_position_wait_movement_policy", "")),
					"desired_attack_position_id": str(target.get("attack_position_wait_target_id", ""))
				}
			if target.get("attack_position", null) is Vector3:
				var distance := Vector2((enemy.get("position", Vector3.ZERO) as Vector3).x, (enemy.get("position", Vector3.ZERO) as Vector3).z).distance_to(Vector2((target.get("attack_position") as Vector3).x, (target.get("attack_position") as Vector3).z))
				if distance < minimum_attack_position_distance:
					minimum_attack_position_distance = distance
					closest_enemy_id = enemy_id
				last_attack_positions[enemy_id] = {
					"enemy_position": enemy.get("position", Vector3.ZERO),
					"attack_position": target.get("attack_position", Vector3.ZERO),
					"distance": distance,
					"status": target.get("attack_position_status", ""),
					"action": action
				}

	var device: Dictionary = device_system.get_deployment(deployment_id)
	var device_hp_after := int(device.get("hp", 0)) if not device.is_empty() else 0
	var gate_hp_after := int(building_system.get_building("front_gate").get("hp", 0))
	var targeting_metrics := (combat_system.debug_get_enemy_targeting_snapshot().get("metrics", {}) as Dictionary).duplicate(true)
	var attack_position_snapshot: Dictionary = combat_system.debug_get_enemy_attack_position_snapshot()
	var defense_waiter_reasons: Array[Dictionary] = []
	for observed in observed_defense_waiter_reasons.values():
		defense_waiter_reasons.append((observed as Dictionary).duplicate(true))
	var full_defense_waiter_count := 0
	for raw_waiter in attack_position_snapshot.get("waiters", []):
		var waiter := raw_waiter as Dictionary
		if not str(waiter.get("target_key", "")).begins_with("defense_device:"):
			continue
		var waiter_enemy_id := str(waiter.get("enemy_id", ""))
		var waiter_enemy: Dictionary = combat_system.get_enemy(waiter_enemy_id)
		var waiter_target: Dictionary = combat_system._make_defense_device_enemy_target(
			deployment_id,
			waiter_enemy.get("position", Vector3.ZERO)
		)
		var waiter_opportunity: Dictionary = combat_system._preview_enemy_target_opportunity(
			waiter_enemy_id,
			waiter_enemy,
			waiter_target
		)
		var waiter_reason: String = str(waiter_opportunity.get("reason", ""))
		if not observed_defense_waiter_reasons.has(waiter_enemy_id):
			defense_waiter_reasons.append({"enemy_id": waiter_enemy_id, "reason": waiter_reason})
		if waiter_reason == "full":
			full_defense_waiter_count += 1
	var diagnostics := {
		"deployment_id": deployment_id,
		"device_hp_before": device_hp_before,
		"device_hp_after": device_hp_after,
		"gate_hp_before": gate_hp_before,
		"gate_hp_after": gate_hp_after,
		"first_device_damage_frame": first_device_damage_frame,
		"device_damage_frames": device_damage_frames,
		"target_device_frames": target_device_frames,
		"target_gate_frames": target_gate_frames,
		"minimum_attack_position_distance": minimum_attack_position_distance,
		"closest_enemy_id": closest_enemy_id,
		"action_counts": action_counts,
		"targeting_metrics": targeting_metrics,
		"last_attack_positions": last_attack_positions,
		"attack_position_snapshot": attack_position_snapshot,
		"defense_waiter_reasons": defense_waiter_reasons,
		"full_defense_waiter_count": full_defense_waiter_count,
		"last_melee": combat_system.debug_get_combat_snapshot().get("last_melee_contact_result", {})
	}
	print("T0195_NATURAL_ENGAGEMENT_DIAGNOSTICS %s" % JSON.stringify(diagnostics))
	_check(target_device_frames > 0, "T0195 enemies never selected the defense device: %s" % diagnostics)
	_check(target_gate_frames == 0, "T0195/T0207 in-transit reservations prematurely redirected enemies to the gate: %s" % diagnostics)
	_check(int(targeting_metrics.get("fixed_target_full_skips", 0)) == 0, "T0195/T0207 reserved attack positions were counted as actual full occupancy: %s" % diagnostics)
	var guided_schema := str(attack_position_snapshot.get("schema", "")) == "enemy_attack_guidance_zones_v2"
	_check(defense_waiter_reasons.is_empty() if guided_schema else not defense_waiter_reasons.is_empty() and full_defense_waiter_count == 0, "T0195/T0243 defense waiter contract mismatch: %s" % diagnostics)
	_check(first_device_damage_frame >= 0 and device_hp_after < device_hp_before, "T0195 enemies selected defense but never naturally damaged it: %s" % diagnostics)
	_check(device_damage_frames.size() >= 3, "T0195 natural melee stopped applying damage after the first device hit: %s" % diagnostics)
	if not guided_schema:
		_check(minimum_attack_position_distance <= 0.08, "T0195 melee navigation stopped at the ordinary arrival radius instead of the precise contact radius: %s" % diagnostics)
	combat_system.clear_spawned_enemies()
	_finish()


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
		print("T0195_NATURAL_DEFENSE_DEVICE_ENGAGEMENT_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
