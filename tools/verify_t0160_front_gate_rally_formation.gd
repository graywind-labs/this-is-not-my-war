extends SceneTree


const EXPECTED_ROWS := ["melee_front", "ranged_rear", "cavalry_left", "cavalry_right"]


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn could not be loaded")
		return
	root.add_child(packed.instantiate())
	for _index in range(6):
		await physics_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	if combat_system == null or controller == null:
		_fail("T0160 formation verification dependencies are missing")
		return

	var rally_config: Dictionary = controller.get_friendly_rally_world_config()
	var center: Vector3 = rally_config.get("center", Vector3.ZERO)
	var forward: Vector3 = rally_config.get("enemy_direction", Vector3.FORWARD)
	forward.y = 0.0
	forward = forward.normalized()
	var lateral := Vector3(forward.z, 0.0, -forward.x).normalized()
	var eligible: Array[Dictionary] = [
		_entry("melee_01", "melee_infantry", false),
		_entry("melee_02", "melee_infantry", false),
		_entry("polearm_01", "polearm_infantry", false),
		_entry("archer_01", "archer", false),
		_entry("crossbow_01", "crossbowman", false),
		_entry("cavalry_01", "cavalry", true),
		_entry("cavalry_02", "cavalry", true),
		_entry("mounted_ranged_01", "mounted_ranged", true)
	]
	var formation: Array = combat_system.call("_build_rally_formation", eligible)
	if formation.size() != eligible.size():
		_fail("Formation lost eligible units: %s" % JSON.stringify(formation))
		return
	var rows: Dictionary = {}
	var positions: Array[Vector3] = []
	var melee_forward: Array[float] = []
	var ranged_forward: Array[float] = []
	var central_max_lateral := 0.0
	var wing_min_lateral := INF
	var area_size := _to_v2(rally_config.get("area_size", []))
	for raw_entry in formation:
		var entry := raw_entry as Dictionary
		var row := str(entry.get("formation_row", ""))
		rows[row] = int(rows.get(row, 0)) + 1
		var position := _to_v3(entry.get("position", {}))
		var relative := position - center
		var forward_distance := relative.dot(forward)
		var lateral_distance := relative.dot(lateral)
		if absf(forward_distance) > area_size.y * 0.5 + 0.5 or absf(lateral_distance) > area_size.x * 0.5 + 0.5:
			_fail("Rally slot left configured front-gate area: %s" % JSON.stringify(entry))
			return
		for other_position in positions:
			if position.distance_to(other_position) < 0.8:
				_fail("Rally slots overlap: %s and %s" % [position, other_position])
				return
		positions.append(position)
		if row == "melee_front":
			melee_forward.append(forward_distance)
			central_max_lateral = maxf(central_max_lateral, absf(lateral_distance))
		elif row == "ranged_rear":
			ranged_forward.append(forward_distance)
			central_max_lateral = maxf(central_max_lateral, absf(lateral_distance))
		elif row == "cavalry_left":
			if lateral_distance >= -4.0:
				_fail("Left cavalry wing is not on the left side: %s" % JSON.stringify(entry))
				return
			wing_min_lateral = minf(wing_min_lateral, absf(lateral_distance))
		elif row == "cavalry_right":
			if lateral_distance <= 4.0:
				_fail("Right cavalry wing is not on the right side: %s" % JSON.stringify(entry))
				return
			wing_min_lateral = minf(wing_min_lateral, absf(lateral_distance))
	for expected_row in EXPECTED_ROWS:
		if int(rows.get(expected_row, 0)) <= 0:
			_fail("Mixed force did not create %s: %s" % [expected_row, JSON.stringify(formation)])
			return
	if _average(melee_forward) <= _average(ranged_forward):
		_fail("Melee line is not ahead of the ranged line")
		return
	if wing_min_lateral <= central_max_lateral:
		_fail("Mounted units are not outside the central infantry/ranged block")
		return
	var actual_alarm: Dictionary = combat_system.trigger_combat_alarm("t0160_physical_arrival")
	if not bool(actual_alarm.get("ok", false)) or int(actual_alarm.get("rallied_count", 0)) <= 0:
		_fail("A real armed responder could not begin the configured rally: %s" % JSON.stringify(actual_alarm))
		return
	var actual_rallied := false
	for _frame in range(1800):
		await physics_frame
		actual_rallied = true
		for raw_rally in combat_system.get_active_rallies():
			if str((raw_rally as Dictionary).get("status", "")) != "rallied":
				actual_rallied = false
				break
		if actual_rallied:
			break
	if not actual_rallied:
		_fail("Uninterrupted foot responders did not physically complete the front-gate formation: %s" % JSON.stringify(combat_system.get_active_rallies()))
		return

	var gm_config: Dictionary = controller.get_gm_enemy_spawn_world_config()
	var gm_center: Vector3 = gm_config.get("area_center", Vector3.ZERO)
	var gm_size := _to_v2(gm_config.get("area_size", []))
	var gate_position := _route_stage_position(controller.get_enemy_route_world(), "front_gate")
	var normal_spawn: Dictionary = combat_system.spawn_wave(1, true, "t0160_normal_spawn_unchanged")
	if (
		not bool(normal_spawn.get("ok", false))
		or str(normal_spawn.get("spawn_stage_id", "")) != "spawn"
		or bool(normal_spawn.get("spawn_in_gm_staging_zone", true))
	):
		_fail("Normal runtime spawn no longer uses the distant route start: %s" % JSON.stringify(normal_spawn))
		return
	for raw_enemy_id in combat_system.get_active_enemy_ids():
		var enemy: Dictionary = combat_system.get_enemy(str(raw_enemy_id))
		if (enemy.get("position", Vector3.ZERO) as Vector3).distance_to(gate_position) < 200.0:
			_fail("Normal runtime enemy spawned inside the GM staging band")
			return
	combat_system.debug_clear_enemies()
	for wave_number in range(1, 6):
		var spawned: Dictionary = combat_system.debug_spawn_wave(wave_number, true, true)
		if (
			not bool(spawned.get("ok", false))
			or str(spawned.get("spawn_stage_id", "")) != "gm_front_gate_enemy_spawn_zone"
			or not bool(spawned.get("spawn_in_gm_staging_zone", false))
		):
			_fail("GM wave %d did not use the dedicated spawn zone: %s" % [wave_number, JSON.stringify(spawned)])
			return
		for raw_enemy_id in combat_system.get_active_enemy_ids():
			var enemy: Dictionary = combat_system.get_enemy(str(raw_enemy_id))
			var position: Vector3 = enemy.get("position", Vector3.ZERO)
			var relative := position - gm_center
			if absf(relative.x) > gm_size.x * 0.5 + 0.5 or absf(relative.z) > gm_size.y * 0.5 + 0.5:
				_fail("GM wave %d enemy left configured yellow-box area: %s" % [wave_number, position])
				return
			if position.distance_to(gate_position) < 25.0 or position.distance_to(center) < 10.0:
				_fail("GM wave %d spawned too close to the gate or friendly rally: %s" % [wave_number, position])
				return
	combat_system.debug_clear_enemies()

	print("T0160 front-gate rally formation and GM enemy spawn zone verification passed.")
	quit(0)


func _entry(npc_id: String, unit_type: String, has_mount: bool) -> Dictionary:
	return {
		"ok": true,
		"npc_id": npc_id,
		"npc_name": npc_id,
		"unit_type": unit_type,
		"unit_type_label": unit_type,
		"has_mount": has_mount,
		"main_weapon_id": unit_type,
		"main_weapon_name": unit_type
	}


func _route_stage_position(route: Dictionary, stage_id: String) -> Vector3:
	for raw_stage in route.get("stages", []):
		var stage := raw_stage as Dictionary
		if str(stage.get("id", "")) == stage_id:
			return stage.get("position", Vector3.ZERO)
	return Vector3.ZERO


func _average(values: Array[float]) -> float:
	var total := 0.0
	for value in values:
		total += value
	return total / float(values.size()) if not values.is_empty() else 0.0


func _to_v2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


func _to_v3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Dictionary:
		return Vector3(float(value.get("x", 0.0)), float(value.get("y", 0.0)), float(value.get("z", 0.0)))
	return Vector3.ZERO


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
