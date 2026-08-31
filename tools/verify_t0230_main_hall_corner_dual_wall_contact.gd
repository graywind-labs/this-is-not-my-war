extends SceneTree


const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const EXPECTED_SEGMENTS := {
	"main_hall_slot_01": ["back_wall", "left_wall"],
	"main_hall_slot_02": ["back_wall", "right_wall"],
	"main_hall_slot_03": ["front_left", "left_wall"],
	"main_hall_slot_04": ["front_right", "right_wall"],
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
	_check(not [device_system, combat_system, building_system, resource_system, formal_root, main_hall_root].has(null), "T0230 required production nodes are missing")
	if not _failures.is_empty():
		_finish()
		return
	if time_system != null:
		time_system.set_paused(true)

	_set_building_level(building_system, "main_hall", 6)
	resource_system.add_resource("item_wall_ballista", 4)
	var deployments := {}
	for slot_id in EXPECTED_SEGMENTS.keys():
		var deploy_result: Dictionary = device_system.deploy_device("wall_ballista", slot_id)
		_check(bool(deploy_result.get("ok", false)), "T0230 could not deploy ballista in %s: %s" % [slot_id, deploy_result])
		deployments[slot_id] = str(deploy_result.get("deployment_id", ""))
	await process_frame

	var main_hall_hp_before := int(building_system.get_building("main_hall").get("hp", 0))
	var enemy := {"id": "t0230_enemy", "name": "双墙受击测试敌人", "attack_power": 18.0, "penetration": 2.0}
	for slot_id in EXPECTED_SEGMENTS.keys():
		var deployment_id := str(deployments.get(slot_id, ""))
		var target := _find_target(device_system.get_active_defense_targets(), deployment_id)
		_check(not target.is_empty(), "T0230 active target missing for %s" % slot_id)
		if target.is_empty():
			continue
		_check(str(target.get("host_proxy_schema", "")) == "main_hall_corner_host_proxy_regions_v1", "T0230 %s proxy schema missing: %s" % [slot_id, target])
		var regions: Array[Dictionary] = combat_system._get_defense_device_host_proxy_regions(target)
		_check(regions.size() == 2, "T0230 %s did not expose exactly two wall regions: %s" % [slot_id, regions])
		var observed_segments: Array[String] = []
		var regions_by_segment := {}
		for region in regions:
			var segment_id := str(region.get("building_segment_id", ""))
			observed_segments.append(segment_id)
			regions_by_segment[segment_id] = region
		observed_segments.sort()
		var expected_segments: Array[String] = []
		for raw_segment_id in EXPECTED_SEGMENTS[slot_id]:
			expected_segments.append(str(raw_segment_id))
		expected_segments.sort()
		_check(observed_segments == expected_segments, "T0230 %s dual-wall mapping drifted: %s" % [slot_id, observed_segments])

		var candidates: Array[Dictionary] = combat_system._get_enemy_attack_position_candidates(
			"t0230_enemy",
			{"id": "t0230_enemy", "position": main_hall_root.global_position + Vector3(0.0, 0.0, 18.0), "weapon_type": "sword_shield"},
			target
		)
		_check(candidates.size() >= 6, "T0230 %s did not expand attack capacity across both walls: %s" % [slot_id, candidates])
		var candidate_counts := {}
		for candidate in candidates:
			var segment_id := str(candidate.get("host_proxy_building_segment_id", ""))
			candidate_counts[segment_id] = int(candidate_counts.get(segment_id, 0)) + 1
			var region: Dictionary = regions_by_segment.get(segment_id, {})
			_check(not region.is_empty(), "T0230 %s candidate references an unrelated region: %s" % [slot_id, candidate])
			if region.is_empty():
				continue
			var outward := _to_vector3(region.get("outward_direction", {}))
			outward.y = 0.0
			outward = outward.normalized()
			var proxy_position := _to_vector3(region.get("position", {}))
			var contact_position: Vector3 = candidate.get("contact_position", proxy_position)
			var attack_position: Vector3 = candidate.get("position", contact_position)
			var expected_surface_offset := float(region.get("contact_radius", 0.0))
			_check(absf((contact_position - proxy_position).dot(outward) - expected_surface_offset) <= 0.05, "T0230 %s candidate left the %s wall plane: %s" % [slot_id, segment_id, candidate])
			_check((attack_position - contact_position).dot(outward) >= -0.01, "T0230 %s candidate was generated through the %s wall: %s" % [slot_id, segment_id, candidate])
		for segment_id in expected_segments:
			_check(int(candidate_counts.get(segment_id, 0)) >= 3, "T0230 %s has too few distributed positions on %s: %s" % [slot_id, segment_id, candidate_counts])

		for segment_id in expected_segments:
			var region: Dictionary = regions_by_segment.get(segment_id, {})
			var wall_collider := _find_collision(formal_root, "building_segment_id", segment_id, "main_hall")
			_check(wall_collider != null, "T0230 physical main-hall wall collider missing: %s" % segment_id)
			if wall_collider == null or region.is_empty():
				continue
			var wall_contact: Dictionary = combat_system._classify_melee_collider(
				"enemy",
				target,
				wall_collider,
				_to_vector3(region.get("aim_position", {}))
			)
			_check(str(wall_contact.get("status", "")) == "hit" and str(wall_contact.get("actual_target_id", "")) == deployment_id, "T0230 %s %s wall did not resolve to the deployed device: %s" % [slot_id, segment_id, wall_contact])
			var device_hp_before := int(device_system.get_deployment(deployment_id).get("hp", 0))
			var damage_result: Dictionary = combat_system._apply_enemy_melee_contact_damage(enemy, target, wall_contact)
			_check(not damage_result.is_empty() and int(device_system.get_deployment(deployment_id).get("hp", device_hp_before)) < device_hp_before, "T0230 %s %s wall contact did not damage the ballista" % [slot_id, segment_id])

		var first_region: Dictionary = regions[0]
		var first_segment_id := str(first_region.get("building_segment_id", ""))
		var first_collider := _find_collision(formal_root, "building_segment_id", first_segment_id, "main_hall")
		if first_collider != null:
			var outward := _to_vector3(first_region.get("outward_direction", {})).normalized()
			var tangent := Vector3(-outward.z, 0.0, outward.x)
			var far_contact: Dictionary = combat_system._classify_melee_collider(
				"enemy",
				target,
				first_collider,
				_to_vector3(first_region.get("aim_position", {})) + tangent * (float(first_region.get("hit_radius", 2.0)) + 1.0)
			)
			_check(str(far_contact.get("status", "")) != "hit", "T0230 %s accepted a collision beyond its bounded corner region: %s" % [slot_id, far_contact])
		_check(int(building_system.get_building("main_hall").get("hp", -1)) == main_hall_hp_before, "T0230 %s dual-wall hits also damaged the main hall" % slot_id)

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
		print("T0230_MAIN_HALL_CORNER_DUAL_WALL_CONTACT PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("T0230_MAIN_HALL_CORNER_DUAL_WALL_CONTACT FAIL count=%d" % _failures.size())
	quit(1)
