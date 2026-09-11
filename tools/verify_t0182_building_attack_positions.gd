extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")

var _failures: PackedStringArray = []
var _damage_sources: Dictionary = {}


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
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var layout := root.get_node_or_null("Main/Presentation/StationLayoutController")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var event_bus := root.get_node_or_null("EventBus")
	_check(combat_system != null and building_system != null and layout != null and time_system != null, "T0182 systems missing")
	if not _failures.is_empty():
		_finish()
		return
	if event_bus != null:
		event_bus.event_recorded.connect(_on_event_recorded)

	var warehouse_geometry: Dictionary = layout.get_building_combat_geometry("warehouse")
	var main_hall_geometry: Dictionary = layout.get_building_combat_geometry("main_hall")
	_check(str(warehouse_geometry.get("schema", "")) == "oriented_building_combat_geometry_v1", "T0182 warehouse combat geometry missing")
	_check(str(main_hall_geometry.get("schema", "")) == "oriented_building_combat_geometry_v1", "T0182 main-hall combat geometry missing")
	_check(absf((_to_vector3(warehouse_geometry.get("right_direction", Vector3.RIGHT)) as Vector3).dot(Vector3.RIGHT)) < 0.9, "T0182 warehouse rotation was flattened")

	time_system.set_paused(true)
	var started: Dictionary = combat_system.debug_run_formal_dynamic_wave_slice(1, true)
	_check(bool(started.get("ok", false)), "T0182 first wave failed to spawn: %s" % started)
	combat_system._formal_enemy_targeting_policy["detection_range"] = 0.1
	_set_building_hp(building_system, "front_gate", 0, 100)
	_set_building_hp(building_system, "warehouse", 100000, 100000)
	_set_building_hp(building_system, "main_hall", 100000, 100000)
	combat_system.debug_step_enemy_ai(0.1)
	combat_system.debug_step_enemy_ai(0.1)
	var warehouse_holders := _verify_target_leases(combat_system, "warehouse", warehouse_geometry, Vector3(29.0, 0.0, 15.0))
	_move_lease_holders_to_positions(combat_system, warehouse_holders)
	combat_system.debug_step_enemy_ai(0.1)
	time_system.set_paused(false)
	await _wait_for_damage_sources("warehouse", warehouse_holders, 720)
	_check(_count_expected_sources("warehouse", warehouse_holders) == warehouse_holders.size(), "T0182 not every warehouse perimeter attacker produced a physical hit: expected=%s observed=%s" % [warehouse_holders, (_damage_sources.get("warehouse", {}) as Dictionary).keys()])

	time_system.set_paused(true)
	_set_building_hp(building_system, "warehouse", 0, 100000)
	combat_system.debug_step_enemy_ai(0.1)
	combat_system.debug_step_enemy_ai(0.1)
	var main_hall_holders := _verify_target_leases(combat_system, "main_hall", main_hall_geometry, Vector3(0.0, 0.0, 2.0))
	_move_lease_holders_to_positions(combat_system, main_hall_holders)
	combat_system.debug_step_enemy_ai(0.1)
	time_system.set_paused(false)
	await _wait_for_damage_sources("main_hall", main_hall_holders, 720)
	_check(_count_expected_sources("main_hall", main_hall_holders) == main_hall_holders.size(), "T0182 not every main-hall perimeter attacker produced a physical hit: expected=%s observed=%s diagnostics=%s" % [main_hall_holders, (_damage_sources.get("main_hall", {}) as Dictionary).keys(), _get_holder_diagnostics(combat_system, main_hall_holders)])

	combat_system.clear_spawned_enemies()
	_finish()


func _verify_target_leases(combat_system: Node, building_id: String, geometry: Dictionary, legacy_stage: Vector3) -> Array[String]:
	var snapshot: Dictionary = combat_system.debug_get_enemy_attack_position_snapshot()
	var leases: Array[Dictionary] = []
	for raw_lease in snapshot.get("leases", []):
		var lease := raw_lease as Dictionary
		if str(lease.get("target_id", "")) == building_id:
			leases.append(lease)
	_check(leases.size() == combat_system.get_active_enemy_ids().size(), "T0182 %s did not lease every first-wave attacker: %s" % [building_id, snapshot])
	var center := _to_vector3(geometry.get("center", Vector3.ZERO))
	var size: Vector2 = geometry.get("size", Vector2.ZERO)
	var right := _to_vector3(geometry.get("right_direction", Vector3.RIGHT)).normalized()
	var forward := _to_vector3(geometry.get("forward_direction", Vector3.FORWARD)).normalized()
	var door_half := float(geometry.get("front_door_clear_width", 0.0)) * 0.5
	_check(_horizontal_distance(center, legacy_stage) > 5.0, "T0182 %s test no longer distinguishes route stage from building center" % building_id)
	var holders: Array[String] = []
	for lease in leases:
		var holder_id := str(lease.get("enemy_id", ""))
		var contact := _to_vector3(lease.get("contact_position", Vector3.ZERO))
		var attack_position := _to_vector3(lease.get("position", contact))
		var local_delta := contact - center
		var local_x := local_delta.dot(right)
		var local_z := local_delta.dot(forward)
		var on_x_face := absf(absf(local_x) - size.x * 0.5) <= 0.03 and absf(local_z) <= size.y * 0.5 + 0.03
		var on_z_face := absf(absf(local_z) - size.y * 0.5) <= 0.03 and absf(local_x) <= size.x * 0.5 + 0.03
		_check(on_x_face or on_z_face, "T0182 %s contact is not on the oriented exterior: %s" % [building_id, lease])
		if local_z > 0.0 and absf(absf(local_z) - size.y * 0.5) <= 0.03:
			_check(absf(local_x) >= door_half, "T0182 %s assigned an attack contact inside the front doorway: %s" % [building_id, lease])
		var outward := attack_position - contact
		outward.y = 0.0
		_check(outward.length() > 0.4, "T0182 %s attack position was not outside its wall contact: %s" % [building_id, lease])
		_check(_horizontal_distance(contact, legacy_stage) > 0.35 or _horizontal_distance(center, legacy_stage) < 5.0, "T0182 %s retained the old route-stage contact: %s" % [building_id, lease])
		holders.append(holder_id)
	return holders


func _move_lease_holders_to_positions(combat_system: Node, holder_ids: Array[String]) -> void:
	var leases_by_enemy: Dictionary = {}
	for raw_lease in combat_system.debug_get_enemy_attack_position_snapshot().get("leases", []):
		var lease := raw_lease as Dictionary
		leases_by_enemy[str(lease.get("enemy_id", ""))] = lease
	for enemy_id in holder_ids:
		var lease := leases_by_enemy.get(enemy_id, {}) as Dictionary
		var actor := combat_system.get_node_or_null(combat_system._formal_first_wave_node_paths.get(enemy_id, NodePath())) as ActorMotionBody
		if actor == null or lease.is_empty():
			_check(false, "T0182 lease holder actor missing: %s" % enemy_id)
			continue
		var position := _to_vector3(lease.get("position", actor.global_position))
		actor.cancel_motion("superseded")
		actor.global_position = position
		actor.velocity = Vector3.ZERO
		var enemy: Dictionary = combat_system._active_enemies.get(enemy_id, {})
		enemy["position"] = position
		combat_system._active_enemies[enemy_id] = enemy


func _get_holder_diagnostics(combat_system: Node, holder_ids: Array[String]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for enemy_id in holder_ids:
		var enemy: Dictionary = combat_system._active_enemies.get(enemy_id, {})
		var target := enemy.get("target", {}) as Dictionary
		var actor := combat_system.get_node_or_null(combat_system._formal_first_wave_node_paths.get(enemy_id, NodePath())) as ActorMotionBody
		result.append({
			"enemy_id": enemy_id,
			"action": str(enemy.get("current_action", "")),
			"target_id": str(target.get("id", "")),
			"position": actor.global_position if actor != null else enemy.get("position", Vector3.ZERO),
			"attack_position": target.get("attack_position", null),
			"contact": target.get("attack_contact_position", null),
			"sequence": int(enemy.get("attack_sequence", 0)),
			"last_melee_status": str((enemy.get("last_attack_result", {}) as Dictionary).get("melee_status", ""))
		})
	return result


func _wait_for_damage_sources(building_id: String, expected_ids: Array[String], frame_limit: int) -> void:
	for _frame in range(frame_limit):
		await physics_frame
		if _count_expected_sources(building_id, expected_ids) == expected_ids.size():
			return


func _count_expected_sources(building_id: String, expected_ids: Array[String]) -> int:
	var observed := _damage_sources.get(building_id, {}) as Dictionary
	var count := 0
	for enemy_id in expected_ids:
		if observed.has(enemy_id):
			count += 1
	return count


func _set_building_hp(building_system: Node, building_id: String, hp: int, max_hp: int) -> void:
	var building: Dictionary = building_system._buildings.get(building_id, {})
	building["hp"] = hp
	building["max_hp"] = max_hp
	building_system._buildings[building_id] = building


func _on_event_recorded(event: Dictionary) -> void:
	if str(event.get("type", "")) != "building_damaged":
		return
	var payload := event.get("payload", {}) as Dictionary
	var building_id := str(payload.get("building_id", ""))
	if not building_id in ["warehouse", "main_hall"]:
		return
	var sources := _damage_sources.get(building_id, {}) as Dictionary
	for raw_actor_id in event.get("actor_ids", []):
		sources[str(raw_actor_id)] = true
	_damage_sources[building_id] = sources


func _horizontal_distance(left: Vector3, right: Vector3) -> float:
	return Vector2(left.x, left.z).distance_to(Vector2(right.x, right.z))


func _to_vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	var data := value as Dictionary if value is Dictionary else {}
	return Vector3(float(data.get("x", 0.0)), float(data.get("y", 0.0)), float(data.get("z", 0.0)))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0182_BUILDING_ATTACK_POSITIONS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
