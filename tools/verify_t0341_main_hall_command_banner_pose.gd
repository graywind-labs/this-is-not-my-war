extends SceneTree

const MAIN_PATH := "res://scenes/main/Main.tscn"
const HALL_PATH := "Main/WorldRoot/FormalStationLayout/BuildingRoots/MainHall/MainHallArt"

func _init() -> void:
	var packed := load(MAIN_PATH) as PackedScene
	if packed == null:
		_fail("Main.tscn unavailable")
		return
	var main := packed.instantiate()
	root.add_child(main)
	for _step in 4:
		await process_frame
		await physics_frame
	var art := root.get_node_or_null(HALL_PATH) as Node3D
	if art == null:
		_fail("Formal main hall unavailable")
		return
	var roof := art.get_node_or_null("Roof/FrontGatehouseRoof") as Node3D
	var west := art.get_node_or_null("BaseVisuals/Exterior/CommandBannerWest") as Node3D
	var east := art.get_node_or_null("BaseVisuals/Exterior/CommandBannerEast") as Node3D
	if roof == null or west == null or east == null:
		_fail("Main hall command-banner hierarchy is incomplete")
		return
	var roof_bounds := _visual_bounds_in_art(roof, art)
	var west_bounds := _visual_bounds_in_art(west, art)
	var east_bounds := _visual_bounds_in_art(east, art)
	if absf(west.position.y - 2.45) > 0.001 or absf(east.position.y - 2.45) > 0.001:
		_fail("Command banners returned to the roofline")
		return
	if absf(west.rotation_degrees.y - 180.0) > 0.01 or absf(east.rotation_degrees.y) > 0.01:
		_fail("Command banners are not mirrored from their authored side-mounted origin")
		return
	if west_bounds.end.y >= roof_bounds.position.y - 0.02 or east_bounds.end.y >= roof_bounds.position.y - 0.02:
		_fail("Command-banner mesh reaches the gatehouse roof: west=%s east=%s roof=%s" % [west_bounds, east_bounds, roof_bounds])
		return
	if absf(west_bounds.position.x + east_bounds.end.x) > 0.02 or absf(west_bounds.end.x + east_bounds.position.x) > 0.02:
		_fail("Command-banner bounds are not symmetric: west=%s east=%s" % [west_bounds, east_bounds])
		return
	for banner in [west, east]:
		if not bool(banner.get_meta("mounted_to_structure", false)) or str(banner.get_meta("mount_surface", "")) != "main_hall_front_facade_below_eave":
			_fail("Command banner lost its facade-mount contract")
			return
	for side_name in ["West", "East"]:
		var support := art.get_node_or_null("BaseVisuals/Exterior/Support_GateLantern%s" % side_name) as Node3D
		var arm := support.get_node_or_null("LanternCrossArm") as MeshInstance3D if support != null else null
		var lamp := support.get_node_or_null("GateLantern%s" % side_name) as Node3D if support != null else null
		if arm == null or lamp == null or absf(arm.position.y - 2.38) > 0.001 or absf(lamp.position.y - 2.17) > 0.001:
			_fail("Previously-correct entry lantern height was not restored: %s" % side_name)
			return
	print("T0341 main hall command banner pose verified")
	quit(0)

func _visual_bounds_in_art(node: Node3D, art: Node3D) -> AABB:
	var result := AABB()
	var has_bounds := false
	for raw_mesh in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := raw_mesh as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var relative := art.global_transform.affine_inverse() * mesh_instance.global_transform
		var bounds := relative * mesh_instance.mesh.get_aabb()
		result = bounds if not has_bounds else result.merge(bounds)
		has_bounds = true
	return result

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
