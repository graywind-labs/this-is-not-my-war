extends SceneTree

const EXPECTED_BUILDINGS := [
	"blacksmith", "workshop", "chapel", "clinic", "dining_hall", "dormitory", "tavern",
]


func _init() -> void:
	await process_frame
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _frame in range(12):
		await process_frame
		await physics_frame

	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var environment_view := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/FormalEnvironmentArtView") as Node3D
	var controller := environment_view.get_node_or_null("CelestialCycleController") as Node3D if environment_view != null else null
	var roof_controller := root.get_node_or_null("Main/Presentation/RoofVisibilityController")
	if time_system == null or controller == null or roof_controller == null:
		_fail("P7R4 integration nodes are missing")
		return
	time_system.call("set_paused", true)
	time_system.call("set_current_time", 3, 12, 0, 0)
	roof_controller.call("debug_apply_distance", 50.0)

	var lights_by_building: Dictionary = {}
	for node in _all_descendants(main):
		if not bool(node.get_meta("interior_fill", false)) or not node is SpotLight3D:
			continue
		var building_id := str(node.get_meta("building_id", ""))
		lights_by_building[building_id] = node

	if lights_by_building.size() != EXPECTED_BUILDINGS.size():
		_fail("Contained interior lighting must use exactly one light per building: %s" % str(lights_by_building.keys()))
		return
	var fill := (controller.call("get_debug_snapshot") as Dictionary).get("interior_fill", {}) as Dictionary
	if int(fill.get("active_light_count", 0)) != EXPECTED_BUILDINGS.size():
		_fail("All seven contained lights must be active while interiors are revealed: %s" % str(fill))
		return

	var roof_clearances: Dictionary = {}
	for building_id in EXPECTED_BUILDINGS:
		var light := lights_by_building.get(building_id) as SpotLight3D
		var view := light.get_parent().get_parent() as Node3D if light != null and light.get_parent() != null else null
		if view == null or light == null or str(view.get("building_id")) != building_id or not view.is_visible_in_tree():
			_fail("Missing view/light pair for %s" % building_id)
			return
		var visibility_snapshot := view.call("get_roof_visibility_snapshot") as Dictionary
		if int(visibility_snapshot.get("roof_shadow_proxy_count", 0)) <= 0 or int(visibility_snapshot.get("exterior_shadow_proxy_count", 0)) <= 0:
			_fail("Building %s lacks opaque roof/exterior shadow blockers" % building_id)
			return
		if not bool(visibility_snapshot.get("roof_shadow_enabled", false)) or not bool(visibility_snapshot.get("exterior_shadow_enabled", false)):
			_fail("Building %s shell shadow blockers are not active" % building_id)
			return
		var roof_min_y := _roof_minimum_local_y(view)
		var light_local := view.to_local(light.global_position)
		roof_clearances[building_id] = roof_min_y - light_local.y
		if not is_finite(roof_min_y) or light_local.y >= roof_min_y - 0.05:
			_fail("Building %s light is not safely below its roof: light_y=%.3f roof_min=%.3f" % [building_id, light_local.y, roof_min_y])
			return
		if building_id == "blacksmith":
			if absf(light_local.x) > 0.1 or absf(light_local.z + 4.0) > 0.1 or light.spot_range > 8.01:
				_fail("Blacksmith hybrid fill escaped its rear masonry forge bay: %s" % light_local)
				return
		elif absf(light_local.x) > 0.1 or absf(light_local.z) > 0.1:
			_fail("Building %s contained light escaped the interior center: %s" % [building_id, light_local])
			return
		if not light.shadow_enabled or light.light_volumetric_fog_energy > 0.0001:
			_fail("Building %s light must be shell-shadowed and fog-neutral" % building_id)
			return

	var blacksmith_light := lights_by_building.get("blacksmith") as SpotLight3D
	var blacksmith_energy := float((fill.get("energy_by_building", {}) as Dictionary).get("blacksmith", 0.0))
	var blacksmith_color: Color = (fill.get("color_by_building", {}) as Dictionary).get("blacksmith", Color.BLACK)
	if not blacksmith_light.visible or not blacksmith_light.is_visible_in_tree() or blacksmith_light.light_energy < 1.7 or blacksmith_energy < 1.7:
		_fail("Blacksmith contained daylight is not visibly active: light=%.3f snapshot=%.3f" % [blacksmith_light.light_energy, blacksmith_energy])
		return
	if not str(blacksmith_light.get_path()).contains("/FormalStationLayout/BuildingRoots/Blacksmith/BlacksmithArt/"):
		_fail("Blacksmith light bound to a hidden compatibility view: %s" % blacksmith_light.get_path())
		return
	if maxf(blacksmith_color.r, maxf(blacksmith_color.g, blacksmith_color.b)) < 0.75 or blacksmith_light.light_color != blacksmith_color:
		_fail("Blacksmith did not receive the shared daylight tint: %s" % blacksmith_color)
		return
	var blacksmith_visible_when_revealed := blacksmith_light.is_visible_in_tree()

	roof_controller.call("debug_apply_distance", 80.0)
	var closed_fill := (controller.call("get_debug_snapshot") as Dictionary).get("interior_fill", {}) as Dictionary
	if int(closed_fill.get("active_light_count", -1)) != 0:
		_fail("Contained interior lights leaked while roofs were opaque")
		return

	print("T0135-P7R4 contained interior lighting verification passed: %s" % str({
		"lights": lights_by_building.size(),
		"blacksmith_light_path": blacksmith_light.get_path(),
		"blacksmith_light_global_position": blacksmith_light.global_position,
		"blacksmith_light_direction": blacksmith_light.global_basis * Vector3.FORWARD,
		"blacksmith_light_visible_when_revealed": blacksmith_visible_when_revealed,
		"blacksmith_light_cull_mask": blacksmith_light.light_cull_mask,
		"blacksmith_energy": blacksmith_energy,
		"blacksmith_color": blacksmith_color,
		"roof_clearances": roof_clearances,
	}))
	quit(0)


func _roof_minimum_local_y(view: Node3D) -> float:
	var roof := view.get_node_or_null("Roof") as Node3D
	if roof == null:
		return INF
	var minimum_y := INF
	for node in _all_descendants(roof):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null or bool(mesh_instance.get_meta("persistent_shell_shadow_proxy", false)) or bool(mesh_instance.get_meta("portrait_opaque_shell_proxy", false)):
			continue
		var aabb := mesh_instance.get_aabb()
		for endpoint in range(8):
			var point_in_view := view.to_local(mesh_instance.to_global(aabb.get_endpoint(endpoint)))
			minimum_y = minf(minimum_y, point_in_view.y)
	return minimum_y


func _all_descendants(parent: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in parent.get_children(true):
		result.append(child)
		result.append_array(_all_descendants(child))
	return result


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
