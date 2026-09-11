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
	for _frame in range(5):
		await process_frame
		await physics_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	var gate_root := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/WallsAndGates/FrontGate") as Node3D
	_check(combat_system != null and controller != null and gate_root != null, "T0204 formal gate systems missing")
	if not _failures.is_empty():
		_finish()
		return

	_verify_tower_collisions(controller, gate_root)
	_verify_tower_navigation(controller, gate_root)
	_verify_attack_position_alignment(combat_system, controller, gate_root)
	combat_system.clear_spawned_enemies()
	_finish()


func _verify_tower_collisions(controller: Node, gate_root: Node3D) -> void:
	var expected_size := Vector3(2.35, 5.05, 3.55)
	var expected_center_x := 3.0 + expected_size.x * 0.5
	for spec in [
		{"name": "LeftPostCollision", "side": -1.0},
		{"name": "RightPostCollision", "side": 1.0},
	]:
		var body := gate_root.get_node_or_null(str(spec.get("name", ""))) as StaticBody3D
		_check(body != null, "T0204 gate tower body missing: %s" % spec)
		if body == null:
			continue
		var shape_node := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
		var shape := shape_node.shape as BoxShape3D if shape_node != null else null
		_check(shape != null, "T0204 gate tower box missing: %s" % body.get_path())
		if shape == null:
			continue
		_check(shape.size.is_equal_approx(expected_size), "T0204 gate tower size drifted: %s / %s" % [body.get_path(), shape.size])
		_check(is_equal_approx(body.position.x, float(spec.get("side", 0.0)) * expected_center_x), "T0204 gate tower lateral centre drifted: %s / %s" % [body.get_path(), body.position])
		_check(is_equal_approx(body.position.y, expected_size.y * 0.5), "T0204 gate tower vertical centre drifted: %s / %s" % [body.get_path(), body.position])
		_check(str(body.get_meta("gate_structure_role", "")) == "side_tower_body", "T0204 tower role metadata missing: %s" % body.get_path())
		_check(str(body.get_meta("building_id", "")) == "front_gate", "T0204 tower building identity missing: %s" % body.get_path())
		_check(body.collision_layer == 1 and body.collision_mask == 2, "T0204 tower collision layers drifted: %s" % body.get_path())
		_check(body.is_in_group("formal_navigation_source"), "T0204 tower is absent from production navigation source: %s" % body.get_path())

		var ray_from := gate_root.to_global(Vector3(body.position.x, 1.0, expected_size.z * 0.5 + 2.0))
		var ray_to := gate_root.to_global(Vector3(body.position.x, 1.0, -expected_size.z * 0.5 - 2.0))
		var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to, 1)
		var hit := gate_root.get_world_3d().direct_space_state.intersect_ray(query)
		_check(hit.get("collider", null) == body, "T0204 tower front ray did not hit its solid body first: %s / %s" % [body.get_path(), hit])

	var left_body := gate_root.get_node_or_null("LeftPostCollision") as StaticBody3D
	var right_body := gate_root.get_node_or_null("RightPostCollision") as StaticBody3D
	if left_body != null and right_body != null:
		var left_shape := (left_body.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
		var right_shape := (right_body.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
		var left_inner_edge := left_body.position.x + left_shape.size.x * 0.5
		var right_inner_edge := right_body.position.x - right_shape.size.x * 0.5
		_check(is_equal_approx(left_inner_edge, -3.0) and is_equal_approx(right_inner_edge, 3.0), "T0204 tower collision changed the 6 m gate opening: %s / %s" % [left_inner_edge, right_inner_edge])

	var physics: Dictionary = controller.debug_get_physics_navigation_snapshot()
	_check(int(physics.get("gate_post_count", 0)) == 4, "T0204 front/back gate collision body count drifted: %s" % physics)


func _verify_tower_navigation(controller: Node, gate_root: Node3D) -> void:
	var navigation_map: RID = controller.get_production_navigation_map_rid()
	_check(navigation_map.is_valid(), "T0204 production navigation map missing")
	if not navigation_map.is_valid():
		return
	NavigationServer3D.map_force_update(navigation_map)
	for side in [-1.0, 1.0]:
		var local_x: float = side * 4.175
		var start := NavigationServer3D.map_get_closest_point(navigation_map, gate_root.to_global(Vector3(local_x, 0.2, 4.2)))
		var finish := NavigationServer3D.map_get_closest_point(navigation_map, gate_root.to_global(Vector3(local_x, 0.2, -4.2)))
		var path := NavigationServer3D.map_get_path(navigation_map, start, finish, true)
		_check(path.size() >= 3, "T0204 navigation did not detour around gate tower: side=%s path=%s" % [side, path])
		for point in path:
			var local := gate_root.to_local(point)
			_check(not (absf(local.x - local_x) < 1.175 and absf(local.z) < 1.775), "T0204 production path entered gate tower footprint: side=%s local=%s path=%s" % [side, local, path])


func _verify_attack_position_alignment(combat_system: Node, controller: Node, gate_root: Node3D) -> void:
	var geometry: Dictionary = controller.get_building_combat_geometry("front_gate")
	_check(str(geometry.get("schema", "")) == "gate_combat_geometry_v1", "T0204 gate combat geometry missing: %s" % geometry)
	var expected_forward := gate_root.global_basis * Vector3.BACK
	expected_forward.y = 0.0
	expected_forward = expected_forward.normalized()
	_check((geometry.get("forward_direction", Vector3.ZERO) as Vector3).dot(expected_forward) > 0.999, "T0204 gate combat normal does not match visible gate rotation: %s" % geometry)

	var started: Dictionary = combat_system.debug_run_formal_dynamic_wave_slice(1, true)
	_check(bool(started.get("ok", false)), "T0204 first wave failed to spawn: %s" % started)
	combat_system.debug_step_enemy_ai(0.1)
	var position_snapshot: Dictionary = combat_system.debug_get_enemy_attack_position_snapshot()
	var leases_by_index: Dictionary = {}
	for raw_lease in combat_system._enemy_attack_position_leases.values():
		var lease := raw_lease as Dictionary
		if str(lease.get("target_key", "")) != "building:front_gate":
			continue
		var slot_id := str(lease.get("slot_id", ""))
		var marker := slot_id.rsplit("front_", true, 1)
		var index := int(str(marker[1]).get_slice("_of_", 0)) if marker.size() == 2 else -1
		leases_by_index[index] = lease
	_check(leases_by_index.size() == 5, "T0204 expected five symmetric door-panel leases: %s" % position_snapshot)
	_check(int(position_snapshot.get("waiter_count", 0)) == 3, "T0204 three overflow enemies must remain front-gate waiters: %s" % position_snapshot)
	if leases_by_index.size() != 5:
		return

	var authored_local: Array[Vector3] = []
	var contact_local: Array[Vector3] = []
	for index in range(5):
		var lease := leases_by_index.get(index, {}) as Dictionary
		authored_local.append(gate_root.to_local(lease.get("authored_position", Vector3.ZERO)))
		contact_local.append(gate_root.to_local(lease.get("contact_position", Vector3.ZERO)))
		var attack_direction := (lease.get("authored_position", Vector3.ZERO) as Vector3) - (lease.get("contact_position", Vector3.ZERO) as Vector3)
		attack_direction.y = 0.0
		_check(attack_direction.normalized().dot(expected_forward) > 0.999, "T0204 attack slot is not square to gate: index=%s direction=%s" % [index, attack_direction])

	for index in range(2):
		var opposite := 4 - index
		_check(absf(authored_local[index].x + authored_local[opposite].x) <= 0.01, "T0204 gate attack bodies are not laterally symmetric: %s / %s" % [authored_local[index], authored_local[opposite]])
		_check(absf(authored_local[index].z - authored_local[opposite].z) <= 0.01, "T0204 gate attack depths are not symmetric: %s / %s" % [authored_local[index], authored_local[opposite]])
		_check(absf(contact_local[index].x + contact_local[opposite].x) <= 0.01, "T0204 gate contact points are not symmetric: %s / %s" % [contact_local[index], contact_local[opposite]])
	_check(absf(authored_local[2].x) <= 0.01 and absf(contact_local[2].x) <= 0.01, "T0204 centre attack slot is not on the gate centreline: %s / %s" % [authored_local[2], contact_local[2]])
	_check(absf(authored_local[0].x - 2.4) <= 0.01 and absf(authored_local[4].x + 2.4) <= 0.01, "T0204 outer attack slots must remain inside the door panels: %s" % [authored_local])
	for index in range(5):
		_check(absf(contact_local[index].z) <= 0.01, "T0204 door-panel contact point left the gate plane: index=%s contact=%s" % [index, contact_local[index]])
		_check(absf(contact_local[index].x) <= 2.41, "T0204 attack contact entered a gate tower: index=%s contact=%s" % [index, contact_local[index]])


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0204_FRONT_GATE_ALIGNMENT_AND_TOWER_COLLISION_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
