extends SceneTree


const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const PROJECTILE_MASK := 3

var _failures: PackedStringArray = []


func _init() -> void:
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

	var combat := root.get_node_or_null("Main/Systems/CombatSystem")
	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	var formal_root := root.get_node_or_null("Main/WorldRoot/FormalStationLayout")
	var device_system := root.get_node_or_null("Main/Systems/DefenseDeviceSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var presenter := root.get_node_or_null("Main/WorldRoot/Station/DefenseDevices")
	_check(combat != null and controller != null and formal_root != null, "T0260 formal combat dependencies missing")
	_check(device_system != null and resource_system != null and building_system != null and presenter != null, "T0260 device dependencies missing")
	if not _failures.is_empty():
		_finish()
		return
	controller.debug_set_preview_enabled(true)
	await physics_frame
	controller.force_sync_production_navigation()

	var gate_result := await _verify_building_is_body_but_projectile_transparent(combat, formal_root, "front_gate")
	var hall_result := await _verify_building_is_body_but_projectile_transparent(combat, formal_root, "main_hall")

	resource_system.add_resource("item_wall_arrow_tower", 1)
	var deployment: Dictionary = device_system.deploy_device("wall_arrow_tower", "main_hall_slot_03")
	_check(bool(deployment.get("ok", false)), "T0260 could not deploy the main-hall arrow tower: %s" % deployment)
	await process_frame
	await physics_frame
	var deployment_id := str(deployment.get("deployment_id", ""))
	var view := presenter.get_view_for_deployment(deployment_id) as Node3D
	var hit_area := view.get_node_or_null("InteractionArea") as Area3D if view != null else null
	_check(view != null and hit_area != null, "T0260 active tower projectile hit area missing")
	if hit_area != null:
		_check((hit_area.collision_layer & 2) != 0, "T0260 tower area is not on the projectile collision layer")
		_check(hit_area.find_children("*", "StaticBody3D", true, false).is_empty(), "T0260 tower projectile hit area unexpectedly added a blocking body")
		var device_identity: Dictionary = combat._extract_projectile_collision_identity(hit_area)
		_check(str(device_identity.get("deployment_id", "")) == deployment_id, "T0260 tower hit area lost deployment identity")
		_check(combat._is_projectile_same_side_actor({"source_side": "friendly"}, device_identity), "T0260 friendly arrow would be blocked by a friendly tower")
		var inherited_device_identity := device_identity.duplicate(true)
		inherited_device_identity["building_id"] = "main_hall"
		_check(not combat._is_projectile_transparent_building({"source_side": "enemy", "target_at_release": {"type": "defense_device", "id": deployment_id}}, inherited_device_identity), "T0260 direct tower identity was swallowed by main-hall transparency")

		var target := _find_target(device_system.get_active_defense_targets(), deployment_id)
		var hp_before := int(device_system.get_deployment(deployment_id).get("hp", 0))
		var hall_hp_before := int(building_system.get_building("main_hall").get("hp", 0))
		var projectile := {
			"id": "t0260_enemy_direct_tower_projectile",
			"attack_id": "ranged:enemy:t0260_enemy:000001:000001",
			"attack_sequence": 1,
			"source_side": "enemy",
			"source_id": "t0260_enemy",
			"source_name": "T0260 敌方射手",
			"source_snapshot": {"id": "t0260_enemy", "name": "T0260 敌方射手", "attack_power": 18.0, "penetration": 2.0},
			"weapon_type": "bow",
			"position": hit_area.global_position,
			"target_at_release": target,
			"attack_context": {"raw_attack_power": 18.0, "penetration": 2.0}
		}
		var direct_hit: Dictionary = combat._resolve_combat_projectile_collision(projectile, {
			"collider": hit_area,
			"position": hit_area.global_position,
			"normal": Vector3.FORWARD
		})
		_check(bool(direct_hit.get("damage_applied", false)), "T0260 enemy arrow did not damage the direct tower hit area: %s" % direct_hit)
		_check(str(direct_hit.get("actual_target_id", "")) == deployment_id, "T0260 direct tower hit resolved to the wrong target")
		_check(int(device_system.get_deployment(deployment_id).get("hp", hp_before)) < hp_before, "T0260 direct tower hit did not reduce tower HP")
		_check(int(building_system.get_building("main_hall").get("hp", -1)) == hall_hp_before, "T0260 direct tower hit also damaged the main hall")

	print("T0260_PROJECTILE_TRANSPARENCY_METRICS=%s" % JSON.stringify({
		"front_gate": gate_result,
		"main_hall": hall_result,
		"tower_deployment_id": deployment_id,
		"tower_area_layer": hit_area.collision_layer if hit_area != null else -1,
		"tower_hp_after_direct_hit": int(device_system.get_deployment(deployment_id).get("hp", -1))
	}))
	_finish()


func _verify_building_is_body_but_projectile_transparent(combat: Node, formal_root: Node, building_id: String) -> Dictionary:
	var shape := _find_box_collision_shape(formal_root, building_id)
	_check(shape != null, "T0260 %s collision shape missing" % building_id)
	if shape == null:
		return {}
	var body := shape.get_parent() as StaticBody3D
	_check((body.collision_layer & 1) != 0, "T0260 %s no longer occupies the world-static layer" % building_id)
	_check((body.collision_mask & 2) != 0, "T0260 %s no longer collides with actor bodies" % building_id)

	var box := shape.shape as BoxShape3D
	var axis_index := 0
	if box.size.y < box.size[axis_index]:
		axis_index = 1
	if box.size.z < box.size[axis_index]:
		axis_index = 2
	var local_direction := Vector3.RIGHT if axis_index == 0 else (Vector3.UP if axis_index == 1 else Vector3.FORWARD)
	var direction := (shape.global_transform.basis * local_direction).normalized()
	var half_extent := float(box.size[axis_index]) * 0.5
	var center := shape.global_position
	var from_position := center - direction * (half_extent + 0.35)
	var target_position := center + direction * (half_extent + 0.48)
	var to_position := target_position + direction * 0.45
	var target_area := Area3D.new()
	target_area.name = "T0260Target%s" % building_id.to_pascal_case()
	target_area.collision_layer = 2
	target_area.collision_mask = 0
	target_area.monitoring = false
	target_area.set_meta("enemy_id", "t0260_target_%s" % building_id)
	var target_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.22
	target_shape.shape = sphere
	target_area.add_child(target_shape)
	formal_root.add_child(target_area)
	target_area.global_position = target_position
	await physics_frame

	var raw_query := PhysicsRayQueryParameters3D.create(from_position, to_position, PROJECTILE_MASK)
	raw_query.collide_with_areas = true
	raw_query.collide_with_bodies = true
	var raw_hit: Dictionary = get_root().world_3d.direct_space_state.intersect_ray(raw_query)
	var raw_identity: Dictionary = combat._extract_projectile_collision_identity(raw_hit.get("collider"))
	_check(str(raw_identity.get("building_id", "")) == building_id, "T0260 raw ray no longer hits physical %s first: %s" % [building_id, raw_identity])

	var trace: Dictionary = combat._trace_combat_projectile_segment(
		{
			"source_side": "friendly",
			"excluded_rids": [],
			"target_at_release": {"type": "enemy", "id": "t0260_target_%s" % building_id}
		},
		from_position,
		to_position,
		PROJECTILE_MASK
	)
	var collision: Dictionary = trace.get("collision", {})
	var traced_identity: Dictionary = combat._extract_projectile_collision_identity(collision.get("collider"))
	_check(str(traced_identity.get("enemy_id", "")) == "t0260_target_%s" % building_id, "T0260 projectile did not pass through %s to the rear target: trace=%s identity=%s" % [building_id, trace, traced_identity])
	_check((trace.get("transparent_building_skipped_ids", PackedStringArray()) as PackedStringArray).has(building_id), "T0260 trace did not report skipping %s" % building_id)
	target_area.queue_free()
	return {
		"raw_hit_building": str(raw_identity.get("building_id", "")),
		"projectile_hit_enemy": str(traced_identity.get("enemy_id", "")),
		"skip_count": int(trace.get("transparent_building_skip_count", 0)),
		"body_layer": body.collision_layer,
		"body_mask": body.collision_mask
	}


func _find_box_collision_shape(formal_root: Node, building_id: String) -> CollisionShape3D:
	for raw_shape in formal_root.find_children("*", "CollisionShape3D", true, false):
		var shape := raw_shape as CollisionShape3D
		if shape == null or not shape.shape is BoxShape3D:
			continue
		if _read_inherited_meta(shape, "building_id") == building_id:
			return shape
	return null


func _read_inherited_meta(node: Node, meta_key: String) -> String:
	var current := node
	while current != null:
		if current.has_meta(meta_key):
			return str(current.get_meta(meta_key, ""))
		current = current.get_parent()
	return ""


func _find_target(targets: Array[Dictionary], deployment_id: String) -> Dictionary:
	for target in targets:
		if str(target.get("id", "")) == deployment_id:
			return target
	return {}


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0260 projectile-transparent gate/main-hall verification passed.")
		quit(0)
		return
	quit(1)
