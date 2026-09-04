extends SceneTree


const MAIN_PATH := "res://scenes/main/Main.tscn"
const HALL_PATH := "Main/WorldRoot/FormalStationLayout/BuildingRoots/MainHall/MainHallArt"

var _failed := false


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
	for side_name in ["West", "East"]:
		var support := art.get_node_or_null("BaseVisuals/Exterior/Support_GateLantern%s" % side_name) as Node3D
		if support == null:
			_fail("Missing entry lantern support: %s" % side_name)
			return
		var lantern := support.get_node_or_null("GateLantern%s" % side_name) as Node3D
		if lantern == null or not bool(lantern.get_meta("mounted_to_structure", false)):
			_fail("Entry lantern lost its mounted-light contract: %s" % side_name)
			return
		if absf(support.position.x) < 3.0 or support.position.z < 7.0:
			_fail("Entry lantern support left its symmetric doorway position: %s" % support.position)
			return
		if support.position.z >= 9.0:
			_fail("Entry lantern post foot left the main-hall envelope: %s" % support.position)
			return
		var arm := support.get_node_or_null("LanternCrossArm") as MeshInstance3D
		if arm == null or arm.position.z <= 0.0 or not is_equal_approx(arm.position.y, 2.38):
			_fail("Entry lantern arm no longer points toward the +Z road: %s" % side_name)
			return
		if not is_equal_approx(lantern.position.y, 2.17):
			_fail("Entry lantern did not recover its original height: %s / %s" % [side_name, lantern.position])
			return
		if _has_collision_or_navigation(support):
			_fail("Entry lantern support gained gameplay collision or navigation: %s" % side_name)
			return
	print("T0338 historical lantern contract verified after T0341 correction")
	quit(0)


func _has_collision_or_navigation(node: Node) -> bool:
	for descendant in node.find_children("*", "", true, false):
		if descendant is CollisionObject3D or descendant is CollisionShape3D or descendant is NavigationRegion3D or descendant is NavigationObstacle3D:
			return true
	return false


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
