extends SceneTree

const CLOSED_BUILDINGS := [
	"blacksmith", "workshop", "chapel", "clinic", "dining_hall", "dormitory", "tavern",
]


func _init() -> void:
	await process_frame
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _frame in range(12):
		await process_frame
		await physics_frame
	var roof_controller := root.get_node_or_null("Main/Presentation/RoofVisibilityController")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var environment_view := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/FormalEnvironmentArtView") as Node3D
	if roof_controller == null or time_system == null or environment_view == null:
		_fail("P7R integration nodes are missing")
		return
	time_system.call("set_paused", true)
	time_system.call("set_current_time", 3, 12, 30, 0)

	var art_by_building: Dictionary = {}
	for raw_view in get_nodes_in_group("building_art_view"):
		var view := raw_view as Node3D
		if view != null and CLOSED_BUILDINGS.has(str(view.get("building_id"))):
			art_by_building[str(view.get("building_id"))] = view
	if art_by_building.size() != CLOSED_BUILDINGS.size():
		_fail("Not all seven closed formal buildings are available: %s" % str(art_by_building.keys()))
		return

	var far_views := _views_by_id((roof_controller.call("debug_apply_distance", 80.0) as Dictionary).get("views", []) as Array)
	if not _validate_snapshots(far_views, false):
		return
	var near_views := _views_by_id((roof_controller.call("debug_apply_distance", 50.0) as Dictionary).get("views", []) as Array)
	if not _validate_snapshots(near_views, true):
		return

	var total_proxy_count := 0
	var visible_proxy_count := 0
	for building_id in CLOSED_BUILDINGS:
		var art := art_by_building[building_id] as Node3D
		if art.has_method("debug_force_visual_level"):
			art.call("debug_force_visual_level", 3)
		art.call("apply_roof_camera_distance", 50.0, 0.0)
		for node in _all_descendants_including_internal(art):
			if not bool(node.get_meta("persistent_shell_shadow_proxy", false)):
				continue
			total_proxy_count += 1
			if not node is MeshInstance3D:
				_fail("Persistent shadow proxy is not a MeshInstance3D: %s" % node.get_path())
				return
			var proxy := node as MeshInstance3D
			var source := proxy.get_parent() as MeshInstance3D
			if source == null or proxy.mesh != source.mesh or not proxy.transform.is_equal_approx(Transform3D.IDENTITY):
				_fail("Shadow proxy no longer shares source geometry/transform: %s" % proxy.get_path())
				return
			if proxy.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY or source.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				_fail("Visible and shadow-only render duties are not separated: %s" % proxy.get_path())
				return
			if not bool(proxy.get_meta("presentation_only", false)) or not proxy.find_children("*", "CollisionObject3D", true, false).is_empty():
				_fail("Shadow proxy crossed the presentation authority boundary: %s" % proxy.get_path())
				return
			if proxy.is_visible_in_tree():
				visible_proxy_count += 1
	if total_proxy_count <= 0 or visible_proxy_count <= 0:
		_fail("No active persistent shell shadow proxies were found")
		return

	time_system.call("set_current_time", 3, 0, 30, 0)
	var celestial := (environment_view.call("get_debug_snapshot") as Dictionary).get("celestial_cycle", {}) as Dictionary
	if str(celestial.get("shadow_owner", "")) != "moon" or int(celestial.get("active_shadow_count", 0)) != 1:
		_fail("Night validation did not transfer the same persistent shell shadows to the moon: %s" % str(celestial))
		return
	var night_near_views := _views_by_id((roof_controller.call("debug_apply_distance", 50.0) as Dictionary).get("views", []) as Array)
	if not _validate_snapshots(night_near_views, true):
		return

	var reversed_views := _views_by_id((roof_controller.call("debug_apply_distance", 80.0) as Dictionary).get("views", []) as Array)
	if not _validate_snapshots(reversed_views, false):
		return
	print("T0135-P7R persistent shell shadow verification passed: %s" % str({
		"buildings": CLOSED_BUILDINGS.size(),
		"shadow_proxies": total_proxy_count,
		"active_level_three_proxies": visible_proxy_count,
		"day_shadow_owner": "sun",
		"night_shadow_owner": "moon",
		"visible_mesh_shadow_duplication": false,
	}))
	quit(0)


func _validate_snapshots(views_by_id: Dictionary, near: bool) -> bool:
	for building_id in CLOSED_BUILDINGS:
		var snapshot := views_by_id.get(building_id, {}) as Dictionary
		if snapshot.is_empty():
			_fail("Roof snapshot missing for %s" % building_id)
			return false
		if not bool(snapshot.get("roof_shadow_enabled", false)) or not bool(snapshot.get("exterior_shadow_enabled", false)):
			_fail("Persistent roof/wall shadow disabled for %s: %s" % [building_id, str(snapshot)])
			return false
		if int(snapshot.get("roof_shadow_proxy_count", 0)) <= 0 or int(snapshot.get("exterior_shadow_proxy_count", 0)) <= 0:
			_fail("Roof/wall shadow proxy coverage is incomplete for %s: %s" % [building_id, str(snapshot)])
			return false
		if bool(snapshot.get("visible_shell_meshes_cast_shadow", true)):
			_fail("Visible transparent shell still duplicates shadows for %s" % building_id)
			return false
		var opacity := maxf(float(snapshot.get("roof_opacity", 1.0)), float(snapshot.get("exterior_opacity", 1.0)))
		if near and (opacity > 0.10 or not bool(snapshot.get("interior_revealed_for_selection", false))):
			_fail("Near shell did not stay transparent/selectable for %s: %s" % [building_id, str(snapshot)])
			return false
		if not near and opacity < 0.99:
			_fail("Far shell did not restore opacity for %s: %s" % [building_id, str(snapshot)])
			return false
	return true


func _views_by_id(raw_views: Array) -> Dictionary:
	var result: Dictionary = {}
	for raw_view in raw_views:
		var view := raw_view as Dictionary
		result[str(view.get("building_id", ""))] = view
	return result


func _all_descendants_including_internal(parent: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in parent.get_children(true):
		result.append(child)
		result.append_array(_all_descendants_including_internal(child))
	return result


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
