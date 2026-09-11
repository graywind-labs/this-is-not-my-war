extends SceneTree


const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const EXPECTED_LEVELS := {
	"main_hall_slot_01": 5,
	"main_hall_slot_02": 6,
	"main_hall_slot_03": 1,
	"main_hall_slot_04": 3,
}
const EXPECTED_SEGMENTS := {
	"main_hall_slot_01": "back_wall",
	"main_hall_slot_02": "back_wall",
	"main_hall_slot_03": "front_left",
	"main_hall_slot_04": "front_right",
}

var _failures: PackedStringArray = []


func _init() -> void:
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

	var device_system := root.get_node_or_null("Main/Systems/DefenseDeviceSystem")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var formal_root := root.get_node_or_null("Main/WorldRoot/FormalStationLayout")
	var main_hall_root := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/BuildingRoots/MainHall") as Node3D
	_check(not [device_system, combat_system, building_system, resource_system, formal_root, main_hall_root].has(null), "T0228 required production nodes are missing")
	if not _failures.is_empty():
		_finish()
		return
	if time_system != null:
		time_system.set_paused(true)

	var observed_levels := {}
	for raw_slot in device_system.get_slots_for_building("main_hall", true):
		var slot: Dictionary = raw_slot
		observed_levels[str(slot.get("id", ""))] = int(slot.get("required_building_level", 0))
	_check(observed_levels == EXPECTED_LEVELS, "T0228 main-hall front/rear unlock mapping drifted: %s" % observed_levels)
	var expected_unlocked_by_level := {
		1: ["main_hall_slot_03"],
		2: ["main_hall_slot_03"],
		3: ["main_hall_slot_03", "main_hall_slot_04"],
		4: ["main_hall_slot_03", "main_hall_slot_04"],
		5: ["main_hall_slot_01", "main_hall_slot_03", "main_hall_slot_04"],
		6: ["main_hall_slot_01", "main_hall_slot_02", "main_hall_slot_03", "main_hall_slot_04"],
	}
	for level in range(1, 7):
		_set_building_level(building_system, "main_hall", level)
		var unlocked: Array[String] = []
		for raw_slot in device_system.get_slots_for_building("main_hall", true):
			var slot: Dictionary = raw_slot
			if bool(slot.get("unlocked", false)):
				unlocked.append(str(slot.get("id", "")))
		unlocked.sort()
		_check(unlocked == expected_unlocked_by_level[level], "T0228 unlocked slots drifted at main-hall Lv.%d: %s" % [level, unlocked])

	_set_building_level(building_system, "main_hall", 6)
	resource_system.add_resource("item_wall_ballista", 4)
	var deployments := {}
	for slot_id in EXPECTED_LEVELS.keys():
		var result: Dictionary = device_system.deploy_device("wall_ballista", slot_id)
		_check(bool(result.get("ok", false)), "T0228 could not deploy ballista in %s: %s" % [slot_id, result])
		deployments[slot_id] = str(result.get("deployment_id", ""))
	await process_frame

	var hall_hp_before := int(building_system.get_building("main_hall").get("hp", 0))
	var enemy := {"id": "t0228_enemy", "name": "主厅墙面受击测试敌人", "attack_power": 18.0, "penetration": 2.0}
	for slot_id in EXPECTED_LEVELS.keys():
		var deployment_id := str(deployments.get(slot_id, ""))
		var target := _find_target(device_system.get_active_defense_targets(), deployment_id)
		_check(not target.is_empty(), "T0228 active target missing for %s" % slot_id)
		if target.is_empty():
			continue
		var segment_id := str(EXPECTED_SEGMENTS[slot_id])
		_check(str(target.get("host_proxy_building_segment_id", "")) == segment_id, "T0228 %s mapped to wrong wall segment: %s" % [slot_id, target])
		var target_position := _to_vector3(target.get("position", {}))
		var deployment_position := _to_vector3(device_system.get_deployment(deployment_id).get("position", {}))
		var outward := _to_vector3(target.get("host_proxy_outward_direction", {}))
		outward.y = 0.0
		outward = outward.normalized()
		var radial := target_position - main_hall_root.global_position
		radial.y = 0.0
		_check(deployment_position.y > target_position.y + 3.0, "T0228 %s enemy target still uses the rooftop device origin" % slot_id)
		_check(outward.length_squared() > 0.9 and radial.dot(outward) > 8.5, "T0228 %s proxy outward direction points through the main hall: target=%s outward=%s" % [slot_id, target_position, outward])

		var candidates: Array[Dictionary] = combat_system._get_enemy_attack_position_candidates(
			"t0228_enemy",
			{"id": "t0228_enemy", "position": target_position + outward * 8.0, "weapon_type": "sword_shield"},
			target
		)
		_check(not candidates.is_empty(), "T0228 %s produced no enemy attack positions" % slot_id)
		var regions_by_id := {}
		for region in combat_system._get_defense_device_host_proxy_regions(target):
			regions_by_id[str(region.get("id", ""))] = region
		for candidate in candidates:
			var region: Dictionary = regions_by_id.get(str(candidate.get("host_proxy_region_id", "")), {})
			_check(not region.is_empty(), "T0228 %s attack position lost its wall region: %s" % [slot_id, candidate])
			if region.is_empty():
				continue
			var region_position := _to_vector3(region.get("position", {}))
			var region_outward := _to_vector3(region.get("outward_direction", {})).normalized()
			var attack_position: Vector3 = candidate.get("position", region_position)
			var contact_position: Vector3 = candidate.get("contact_position", region_position)
			_check((attack_position - contact_position).dot(region_outward) >= -0.01, "T0228 %s attack position was generated inside the main hall: %s" % [slot_id, candidate])
			_check(absf((contact_position - region_position).dot(region_outward) - float(region.get("contact_radius", 0.0))) <= 0.05, "T0228 %s contact point left its wall plane: %s" % [slot_id, candidate])

		var wall_collider := _find_collision(formal_root, "building_segment_id", segment_id, "main_hall")
		_check(wall_collider != null, "T0228 physical main-hall wall collider missing: %s" % segment_id)
		if wall_collider == null:
			continue
		var wall_contact: Dictionary = combat_system._classify_melee_collider(
			"enemy",
			target,
			wall_collider,
			_to_vector3(target.get("aim_position", {}))
		)
		_check(str(wall_contact.get("status", "")) == "hit" and str(wall_contact.get("actual_target_id", "")) == deployment_id, "T0228 %s corresponding wall did not resolve to its deployed device: %s" % [slot_id, wall_contact])
		var device_hp_before := int(device_system.get_deployment(deployment_id).get("hp", 0))
		var damage_result: Dictionary = combat_system._apply_enemy_melee_contact_damage(enemy, target, wall_contact)
		_check(not damage_result.is_empty() and int(device_system.get_deployment(deployment_id).get("hp", device_hp_before)) < device_hp_before, "T0228 %s wall contact did not damage the ballista" % slot_id)
		_check(int(building_system.get_building("main_hall").get("hp", -1)) == hall_hp_before, "T0228 %s wall-proxy hit also damaged the main hall" % slot_id)

	_finish()


func _find_target(targets: Array[Dictionary], deployment_id: String) -> Dictionary:
	for target in targets:
		if str(target.get("id", "")) == deployment_id:
			return target
	return {}


func _find_collision(root_node: Node, meta_key: String, meta_value: String, building_id: String = "") -> StaticBody3D:
	for raw_node in root_node.find_children("*", "StaticBody3D", true, false):
		var body := raw_node as StaticBody3D
		if str(body.get_meta(meta_key, "")) != meta_value:
			continue
		if not building_id.is_empty() and _read_inherited_meta(body, "building_id") != building_id:
			continue
		return body
	return null


func _read_inherited_meta(node: Node, meta_key: String) -> String:
	var current := node
	while current != null:
		if current.has_meta(meta_key):
			return str(current.get_meta(meta_key, ""))
		current = current.get_parent()
	return ""


func _set_building_level(building_system: Node, building_id: String, level: int) -> void:
	var buildings: Dictionary = building_system.get("_buildings")
	var building: Dictionary = buildings.get(building_id, {})
	building["level"] = level
	buildings[building_id] = building
	building_system.set("_buildings", buildings)


func _to_vector3(raw: Variant) -> Vector3:
	if raw is Vector3:
		return raw
	if not raw is Dictionary:
		return Vector3.ZERO
	return Vector3(float(raw.get("x", 0.0)), float(raw.get("y", 0.0)), float(raw.get("z", 0.0)))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0228_MAIN_HALL_DEFENSE_WALL_CONTACT PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("T0228_MAIN_HALL_DEFENSE_WALL_CONTACT FAIL count=%d" % _failures.size())
	quit(1)
