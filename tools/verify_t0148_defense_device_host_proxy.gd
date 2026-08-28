extends SceneTree


const MAIN_SCENE := preload("res://scenes/main/Main.tscn")

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	for _frame in range(3):
		await process_frame
		await physics_frame

	var device_system := root.get_node_or_null("Main/Systems/DefenseDeviceSystem")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var formal_root := root.get_node_or_null("Main/WorldRoot/FormalStationLayout")
	_check(device_system != null and combat_system != null, "T0148 combat/device systems missing")
	_check(building_system != null and resource_system != null and formal_root != null, "T0148 building/resource/formal world missing")
	if not _failures.is_empty():
		_finish()
		return
	if time_system != null:
		time_system.set_paused(true)

	_set_building_level(building_system, "wall", 4)
	_set_building_level(building_system, "main_hall", 1)
	resource_system.add_resource("item_wall_ballista", 3)
	var wall_left_inner: Dictionary = device_system.deploy_device("wall_ballista", "wall_slot_01")
	var wall_left_outer: Dictionary = device_system.deploy_device("wall_ballista", "wall_slot_03")
	var hall_back_left: Dictionary = device_system.deploy_device("wall_ballista", "main_hall_slot_01")
	_check(bool(wall_left_inner.get("ok", false)), "T0148 wall slot 01 deployment failed")
	_check(bool(wall_left_outer.get("ok", false)), "T0148 wall slot 03 deployment failed")
	_check(bool(hall_back_left.get("ok", false)), "T0148 main hall slot 01 deployment failed")
	await process_frame

	var inner_id := str(wall_left_inner.get("deployment_id", ""))
	var outer_id := str(wall_left_outer.get("deployment_id", ""))
	var hall_id := str(hall_back_left.get("deployment_id", ""))
	var inner_target := _find_target(device_system.get_active_defense_targets(), inner_id)
	var outer_target := _find_target(device_system.get_active_defense_targets(), outer_id)
	var hall_target := _find_target(device_system.get_active_defense_targets(), hall_id)
	_check(str(inner_target.get("host_proxy_kind", "")) == "wall_segment", "T0148 wall device has no formal wall proxy")
	_check(str(inner_target.get("host_proxy_wall_segment_id", "")) == "north_west_a", "T0148 wall slot mapped to wrong wall segment")
	_check(str(hall_target.get("host_proxy_kind", "")) == "building_wall_segment", "T0148 main hall device has no supporting-wall proxy")
	_check(str(hall_target.get("host_proxy_building_segment_id", "")) == "back_wall", "T0148 main hall slot mapped to wrong supporting wall")
	_check(str(hall_target.get("host_proxy_fixture_id", "")) == "main_hall_slot_01_platform", "T0148 main hall platform identity missing")
	_check(_to_vector3(inner_target.get("position", {})).y < _to_vector3(device_system.get_deployment(inner_id).get("position", {})).y, "T0148 enemy target still points at the elevated device instead of its host segment")

	var north_west_wall := _find_collision(formal_root, "wall_segment_id", "north_west_a")
	var north_east_wall := _find_collision(formal_root, "wall_segment_id", "north_east")
	var hall_back_wall := _find_collision(formal_root, "building_segment_id", "back_wall", "main_hall")
	var hall_platform := _find_collision(formal_root, "fixture_id", "main_hall_slot_01_platform", "main_hall")
	_check(north_west_wall != null and north_east_wall != null, "T0148 formal front-wall collision segments missing")
	_check(hall_back_wall != null and hall_platform != null, "T0148 formal main-hall wall/platform collisions missing")
	if not _failures.is_empty():
		_finish()
		return

	var inner_aim := _to_vector3(inner_target.get("aim_position", {}))
	var outer_aim := _to_vector3(outer_target.get("aim_position", {}))
	var hall_aim := _to_vector3(hall_target.get("aim_position", {}))
	var hall_fixture_aim := _to_vector3((hall_target.get("host_proxy", {}) as Dictionary).get("fixture_aim_position", {}))
	var inner_contact: Dictionary = combat_system._classify_melee_collider("enemy", inner_target, north_west_wall, inner_aim)
	_check(str(inner_contact.get("status", "")) == "hit", "T0148 correct wall proxy did not classify as a device hit")
	_check(str(inner_contact.get("actual_target_id", "")) == inner_id, "T0148 correct wall proxy resolved to the wrong deployment")
	var wrong_region: Dictionary = combat_system._classify_melee_collider("enemy", inner_target, north_west_wall, outer_aim)
	_check(str(wrong_region.get("status", "")) == "blocked", "T0148 another slot region on the same long wall damaged the intended device")
	var wrong_segment: Dictionary = combat_system._classify_melee_collider("enemy", inner_target, north_east_wall, inner_aim)
	_check(str(wrong_segment.get("status", "")) == "blocked", "T0148 a different wall segment damaged the intended device")
	var hall_wall_contact: Dictionary = combat_system._classify_melee_collider("enemy", hall_target, hall_back_wall, hall_aim)
	var hall_platform_contact: Dictionary = combat_system._classify_melee_collider("enemy", hall_target, hall_platform, hall_fixture_aim)
	_check(str(hall_wall_contact.get("status", "")) == "hit", "T0148 main-hall supporting wall did not proxy device damage")
	_check(str(hall_platform_contact.get("status", "")) == "hit", "T0148 main-hall platform did not proxy device damage")

	var enemy := {"id": "t0148_enemy", "name": "代理测试敌人", "attack_power": 18.0, "penetration": 2.0}
	var wall_hp_before := int(building_system.get_building("wall").get("hp", 0))
	var inner_hp_before := int(device_system.get_deployment(inner_id).get("hp", 0))
	var melee_damage: Dictionary = combat_system._apply_enemy_melee_contact_damage(enemy, inner_target, inner_contact)
	_check(not melee_damage.is_empty(), "T0148 wall-proxy melee contact produced no device damage result")
	_check(int(device_system.get_deployment(inner_id).get("hp", inner_hp_before)) < inner_hp_before, "T0148 wall-proxy melee contact did not reduce device HP")
	_check(int(building_system.get_building("wall").get("hp", -1)) == wall_hp_before, "T0148 wall-proxy melee contact also reduced wall HP")

	var outer_hp_before := int(device_system.get_deployment(outer_id).get("hp", 0))
	var projectile := {
		"id": "t0148_proxy_projectile",
		"attack_id": "ranged:enemy:t0148_enemy:000001:000001",
		"attack_sequence": 1,
		"source_side": "enemy",
		"source_id": "t0148_enemy",
		"source_name": "代理测试敌人",
		"source_snapshot": enemy,
		"weapon_type": "bow",
		"position": outer_aim,
		"target_at_release": outer_target,
		"attack_context": {"raw_attack_power": 18.0, "penetration": 2.0}
	}
	var projectile_hit: Dictionary = combat_system._resolve_combat_projectile_collision(
		projectile,
		{"collider": north_west_wall, "position": outer_aim, "normal": Vector3.FORWARD}
	)
	_check(bool(projectile_hit.get("damage_applied", false)), "T0148 physical projectile hit on the correct wall proxy applied no device damage")
	_check(str(projectile_hit.get("actual_target_id", "")) == outer_id, "T0148 physical proxy hit resolved to the wrong device")
	_check(int(device_system.get_deployment(outer_id).get("hp", outer_hp_before)) < outer_hp_before, "T0148 physical proxy hit did not reduce device HP")
	_check(int(building_system.get_building("wall").get("hp", -1)) == wall_hp_before, "T0148 physical proxy hit also reduced wall HP")

	var blocked_hp_before := int(device_system.get_deployment(outer_id).get("hp", 0))
	projectile["id"] = "t0148_wrong_region_projectile"
	projectile["attack_id"] = "ranged:enemy:t0148_enemy:000002:000002"
	var wrong_region_projectile: Dictionary = combat_system._resolve_combat_projectile_collision(
		projectile,
		{"collider": north_west_wall, "position": inner_aim, "normal": Vector3.FORWARD}
	)
	_check(not bool(wrong_region_projectile.get("damage_applied", false)), "T0148 projectile hitting another proxy region damaged the locked device")
	_check(int(device_system.get_deployment(outer_id).get("hp", 0)) == blocked_hp_before, "T0148 blocked proxy projectile changed device HP")

	var hall_hp_before := int(building_system.get_building("main_hall").get("hp", 0))
	var hall_device_hp_before := int(device_system.get_deployment(hall_id).get("hp", 0))
	var hall_damage: Dictionary = combat_system._apply_enemy_melee_contact_damage(enemy, hall_target, hall_wall_contact)
	_check(not hall_damage.is_empty(), "T0148 main-hall proxy contact produced no device damage")
	_check(int(device_system.get_deployment(hall_id).get("hp", hall_device_hp_before)) < hall_device_hp_before, "T0148 main-hall proxy did not reduce device HP")
	_check(int(building_system.get_building("main_hall").get("hp", -1)) == hall_hp_before, "T0148 main-hall proxy also damaged the main hall")

	var inner_hp_before_building_attack := int(device_system.get_deployment(inner_id).get("hp", 0))
	var explicit_wall_attack: Dictionary = combat_system._apply_enemy_attack_to_building(enemy, "wall", 3)
	_check(not explicit_wall_attack.is_empty(), "T0148 explicit building-target wall damage failed")
	_check(int(building_system.get_building("wall").get("hp", wall_hp_before)) == wall_hp_before - 3, "T0148 explicit wall target did not use building damage")
	_check(int(device_system.get_deployment(inner_id).get("hp", 0)) == inner_hp_before_building_attack, "T0148 explicit wall target incorrectly damaged its deployed device")

	var wall_hp_before_destroy := int(building_system.get_building("wall").get("hp", 0))
	device_system.apply_damage_to_device(inner_id, 100000, {"attacker_id": "t0148_enemy"})
	_check(device_system.get_deployment(inner_id).is_empty(), "T0148 destroyed device retained its deployment")
	_check(_find_target(device_system.get_active_defense_targets(), inner_id).is_empty(), "T0148 destroyed device retained an active host proxy")
	_check(int(building_system.get_building("wall").get("hp", -1)) == wall_hp_before_destroy, "T0148 destroying a device also destroyed/damaged its host wall")
	_check(is_instance_valid(north_west_wall), "T0148 destroying a device removed its host wall collision")

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
		print("T0148_DEFENSE_DEVICE_HOST_PROXY PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("T0148_DEFENSE_DEVICE_HOST_PROXY FAIL count=%d" % _failures.size())
	quit(1)
