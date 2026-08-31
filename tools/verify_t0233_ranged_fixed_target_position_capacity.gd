extends SceneTree


const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const EXPECTED_RATIOS := [0.90, 0.76, 0.62, 0.48, 0.34, 0.20]

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup.set("_startup_running", true)
	root.add_child(main)
	for _frame in range(4):
		await process_frame
		await physics_frame

	var combat := root.get_node_or_null("Main/Systems/CombatSystem")
	var devices := root.get_node_or_null("Main/Systems/DefenseDeviceSystem")
	var buildings := root.get_node_or_null("Main/Systems/BuildingSystem")
	var resources := root.get_node_or_null("Main/Systems/ResourceSystem")
	var time := root.get_node_or_null("Main/Systems/TimeSystem")
	_check(not [combat, devices, buildings, resources, time].has(null), "T0233 required production systems are missing")
	if not _failures.is_empty():
		_finish()
		return
	time.set_paused(true)

	var started: Dictionary = combat.debug_run_formal_dynamic_wave_slice(3, true)
	_check(bool(started.get("ok", false)), "T0233 could not spawn a production ranged wave: %s" % started)
	await physics_frame
	var enemy_id := _find_ranged_enemy_id(combat)
	_check(not enemy_id.is_empty(), "T0233 wave contains no ranged enemy")
	if enemy_id.is_empty():
		combat.clear_spawned_enemies()
		_finish()
		return
	for raw_enemy_id in combat.get_active_enemy_ids().duplicate():
		if str(raw_enemy_id) != enemy_id:
			combat._remove_enemy_from_combat(str(raw_enemy_id))
	await process_frame
	var enemy: Dictionary = combat.get_enemy(enemy_id)

	var building_counts := {}
	for building_id in ["front_gate", "warehouse", "main_hall"]:
		var target: Dictionary = combat._make_building_target(building_id)
		var candidates: Array[Dictionary] = combat._get_enemy_attack_position_candidates(enemy_id, enemy, target)
		building_counts[building_id] = candidates.size()
		_verify_ranged_capacity(combat, enemy, "building:%s" % building_id, candidates)
		if building_id == "front_gate":
			_check(candidates.size() == 30, "T0233 front gate expected 5 x 6 positions, got %d" % candidates.size())
		else:
			_check(candidates.size() > 60, "T0233 %s did not exceed the former 60-position capacity: %d" % [building_id, candidates.size()])

	_set_building_level(buildings, "main_hall", 6)
	resources.add_resource("item_wall_ballista", 2)
	var wall_deploy: Dictionary = devices.deploy_device("wall_ballista", "wall_slot_01")
	var hall_deploy: Dictionary = devices.deploy_device("wall_ballista", "main_hall_slot_03")
	_check(bool(wall_deploy.get("ok", false)) and bool(hall_deploy.get("ok", false)), "T0233 could not deploy representative wall/main-hall devices: %s / %s" % [wall_deploy, hall_deploy])
	await process_frame

	var device_counts := {}
	for deployment_id in [str(wall_deploy.get("deployment_id", "")), str(hall_deploy.get("deployment_id", ""))]:
		if deployment_id.is_empty():
			continue
		var target := _find_target(devices.get_active_defense_targets(), deployment_id)
		var candidates: Array[Dictionary] = combat._get_enemy_attack_position_candidates(enemy_id, enemy, target)
		device_counts[deployment_id] = candidates.size()
		_verify_ranged_capacity(combat, enemy, "defense_device:%s" % deployment_id, candidates)
		_check(candidates.size() >= 30, "T0233 defense device did not gain enough ranged positions: %s = %d" % [deployment_id, candidates.size()])
		if str(target.get("building_id", "")) == "main_hall":
			_verify_main_hall_region_distribution(candidates)
		var melee := enemy.duplicate(true)
		melee["weapon_type"] = "sword_shield"
		melee["unit_type"] = "melee_infantry"
		melee["attack_range"] = 1.5
		var melee_candidates: Array[Dictionary] = combat._get_enemy_attack_position_candidates(enemy_id, melee, target)
		_check(melee_candidates.size() <= 8, "T0233 expanded melee defense-device capacity: %s = %d" % [deployment_id, melee_candidates.size()])
		for candidate in melee_candidates:
			_check(int(candidate.get("range_row_count", 0)) == 1, "T0233 melee defense-device candidate became multirank: %s" % candidate)

	var gate_melee := enemy.duplicate(true)
	gate_melee["weapon_type"] = "sword_shield"
	gate_melee["unit_type"] = "melee_infantry"
	gate_melee["attack_range"] = 1.5
	var gate_melee_candidates: Array[Dictionary] = combat._get_enemy_attack_position_candidates(
		enemy_id,
		gate_melee,
		combat._make_building_target("front_gate")
	)
	_check(gate_melee_candidates.size() == 5, "T0233 changed the front-gate five-position melee contract: %d" % gate_melee_candidates.size())
	combat.clear_spawned_enemies()
	await process_frame
	var fifth_wave: Dictionary = combat.spawn_wave(5, true, "t0233_ranged_capacity_stress")
	_check(int(fifth_wave.get("spawned_count", 0)) == 48, "T0233 fifth-wave stress did not spawn 48 enemies: %s" % fifth_wave)
	for _frame in range(4):
		await process_frame
		await physics_frame
	_verify_fifth_wave_ranged_gate_guidance(combat)
	print("T0233_COUNTS buildings=%s devices=%s" % [building_counts, device_counts])
	combat.clear_spawned_enemies()
	_finish()


func _verify_ranged_capacity(combat: Node, enemy: Dictionary, label: String, candidates: Array[Dictionary]) -> void:
	_check(not candidates.is_empty(), "T0233 %s has no ranged candidates" % label)
	var rows := {}
	var unique_positions := {}
	var attack_range := float(enemy.get("attack_range", 0.0))
	for candidate in candidates:
		var row_index := int(candidate.get("range_row_index", -1))
		var row := rows.get(row_index, []) as Array
		row.append(candidate)
		rows[row_index] = row
		_check(int(candidate.get("range_row_count", 0)) == EXPECTED_RATIOS.size(), "T0233 %s candidate omitted six-row metadata: %s" % [label, candidate])
		var ratio := float(candidate.get("range_row_ratio", -1.0))
		_check(row_index >= 0 and row_index < EXPECTED_RATIOS.size(), "T0233 %s row index is invalid: %s" % [label, candidate])
		if row_index >= 0 and row_index < EXPECTED_RATIOS.size():
			_check(is_equal_approx(ratio, EXPECTED_RATIOS[row_index]), "T0233 %s ratio drifted in row %d: %.3f" % [label, row_index, ratio])
		var position: Vector3 = candidate.get("position", Vector3.ZERO)
		var contact: Vector3 = candidate.get("contact_position", position)
		var distance := Vector2(position.x, position.z).distance_to(Vector2(contact.x, contact.z))
		_check(distance <= attack_range + 0.001, "T0233 %s generated a position outside actual range: %.3f > %.3f" % [label, distance, attack_range])
		unique_positions["%.3f:%.3f" % [position.x, position.z]] = true
	_check(rows.size() == EXPECTED_RATIOS.size(), "T0233 %s expected six distinct depth rows, got %s" % [label, rows.keys()])
	_check(unique_positions.size() == candidates.size(), "T0233 %s duplicated physical ranged positions: %d/%d" % [label, unique_positions.size(), candidates.size()])
	var first_row_count := (rows.get(0, []) as Array).size()
	_check(first_row_count > 0, "T0233 %s outer row is empty" % label)
	for row_index in range(EXPECTED_RATIOS.size()):
		_check((rows.get(row_index, []) as Array).size() == first_row_count, "T0233 %s surface coverage differs between rows" % label)


func _verify_main_hall_region_distribution(candidates: Array[Dictionary]) -> void:
	var regions := {}
	for candidate in candidates:
		var region_id := str(candidate.get("host_proxy_region_id", ""))
		var rows := regions.get(region_id, {}) as Dictionary
		var row_index := int(candidate.get("range_row_index", -1))
		rows[row_index] = int(rows.get(row_index, 0)) + 1
		regions[region_id] = rows
	_check(regions.size() == 2, "T0233 main-hall corner device did not keep both wall regions: %s" % regions)
	for region_id in regions:
		var rows := regions[region_id] as Dictionary
		_check(rows.size() == EXPECTED_RATIOS.size(), "T0233 main-hall region %s lacks six depth rows: %s" % [region_id, rows])
		for row_index in range(EXPECTED_RATIOS.size()):
			_check(int(rows.get(row_index, 0)) >= 4, "T0233 main-hall region %s row %d has too few lateral positions: %s" % [region_id, row_index, rows])


func _verify_fifth_wave_ranged_gate_guidance(combat: Node) -> void:
	var gate_target: Dictionary = combat._make_building_target("front_gate")
	var ranged_count := 0
	var guided_count := 0
	var assignment_diagnostics: Array[Dictionary] = []
	for raw_enemy_id in combat.get_active_enemy_ids():
		var enemy_id := str(raw_enemy_id)
		var enemy: Dictionary = combat.get_enemy(enemy_id)
		if str(enemy.get("weapon_type", "")) not in ["bow", "crossbow"]:
			continue
		ranged_count += 1
		var assigned: Dictionary = combat._ensure_enemy_attack_position(enemy_id, enemy, gate_target, true)
		if assignment_diagnostics.size() < 3:
			assignment_diagnostics.append({
				"enemy_id": enemy_id,
				"uses_leases": combat._uses_enemy_attack_position_leases(enemy_id),
				"status": str(assigned.get("attack_position_status", "")),
				"wait_reason": str(assigned.get("attack_position_wait_reason", "")),
				"candidate_count": combat._get_enemy_attack_position_candidates(enemy_id, enemy, gate_target).size()
			})
		if str(assigned.get("attack_position_status", "")) in ["guiding", "in_range"]:
			guided_count += 1
	_check(ranged_count == 16, "T0233 expected 16 ranged enemies in wave five, got %d" % ranged_count)
	_check(guided_count == ranged_count, "T0233 expanded gate capacity left fifth-wave ranged enemies without guidance: %d/%d guided; diagnostics=%s" % [guided_count, ranged_count, assignment_diagnostics])
	_check((combat._enemy_attack_wait_queues as Dictionary).is_empty(), "T0233/T0243 fifth-wave guidance recreated a fixed-capacity waiter queue")


func _find_ranged_enemy_id(combat: Node) -> String:
	for raw_enemy_id in combat.get_active_enemy_ids():
		var enemy_id := str(raw_enemy_id)
		if str(combat.get_enemy(enemy_id).get("weapon_type", "")) in ["bow", "crossbow"]:
			return enemy_id
	return ""


func _find_target(targets: Array[Dictionary], target_id: String) -> Dictionary:
	for target in targets:
		if str(target.get("id", "")) == target_id:
			return target
	return {}


func _set_building_level(building_system: Node, building_id: String, level: int) -> void:
	var building_map := building_system.get("_buildings") as Dictionary
	var building := building_map.get(building_id, {}) as Dictionary
	building["level"] = level
	building_map[building_id] = building
	building_system.set("_buildings", building_map)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0233_RANGED_FIXED_TARGET_POSITION_CAPACITY_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
