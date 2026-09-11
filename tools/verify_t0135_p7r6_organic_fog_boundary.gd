extends SceneTree

const EXPECTED_CLUSTER_COUNT := 12
const EXPECTED_REGIONS := ["east_mountain_foot", "front_forest", "rear_forest", "river_valley"]


func _init() -> void:
	await process_frame
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _frame in range(12):
		await process_frame
		await physics_frame

	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var controller := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/FormalEnvironmentArtView/CelestialCycleController")
	if time_system == null or controller == null:
		_fail("Organic fog integration nodes are missing")
		return
	time_system.call("set_paused", true)
	time_system.call("set_current_time", 3, 0, 30, 0)
	await process_frame

	var snapshot := controller.call("get_debug_snapshot") as Dictionary
	var fog := snapshot.get("peripheral_fog", {}) as Dictionary
	var volumes := fog.get("volumes", []) as Array
	if volumes.size() != EXPECTED_CLUSTER_COUNT:
		_fail("Peripheral fog must use twelve overlapping clusters, got %d" % volumes.size())
		return

	var regions: Array[String] = []
	var rotated_count := 0
	var unique_sizes: Dictionary = {}
	for raw_volume in volumes:
		var volume := raw_volume as Dictionary
		if int(volume.get("shape", -1)) != RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID:
			_fail("Box-like fog volume remains: %s" % str(volume))
			return
		var region := str(volume.get("region", ""))
		if not regions.has(region):
			regions.append(region)
		var rotation := volume.get("rotation_degrees", Vector3.ZERO) as Vector3
		if absf(rotation.y) >= 5.0:
			rotated_count += 1
		unique_sizes[str(volume.get("size", Vector3.ZERO))] = true
		if not bool(volume.get("presentation_only", false)):
			_fail("Fog cluster is not presentation-only: %s" % str(volume))
			return
	regions.sort()
	if regions != EXPECTED_REGIONS:
		_fail("Organic fog no longer covers all four landscape regions: %s" % str(regions))
		return
	if rotated_count < 8 or unique_sizes.size() < 10:
		_fail("Fog clusters are still too repetitive: rotations=%d sizes=%d" % [rotated_count, unique_sizes.size()])
		return

	time_system.call("set_current_time", 3, 12, 30, 0)
	await process_frame
	var day_fog := (controller.call("get_debug_snapshot") as Dictionary).get("peripheral_fog", {}) as Dictionary
	for raw_volume in day_fog.get("volumes", []):
		if float((raw_volume as Dictionary).get("density", 1.0)) > 0.00001:
			_fail("Organic fog cluster remains active during the day")
			return

	for node in _all_descendants(controller):
		if node.has_meta("fog_zone_id") and (node is CollisionObject3D or node is NavigationRegion3D):
			_fail("Organic fog cluster changed gameplay geometry: %s" % node.get_path())
			return

	print("T0135-P7R6 organic fog boundary verification passed: %s" % str({
		"clusters": volumes.size(),
		"regions": regions,
		"rotated_clusters": rotated_count,
		"unique_sizes": unique_sizes.size(),
	}))
	quit(0)


func _all_descendants(parent: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in parent.get_children():
		result.append(child)
		result.append_array(_all_descendants(child))
	return result


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
