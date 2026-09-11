extends SceneTree


const LAYOUT_PATH := "res://data/station_layout.json"
const FORMAL_BOARD_PATH := "Main/WorldRoot/FormalStationLayout/PublicProps/NoticeBoard"


func _init() -> void:
	var layout := _load_json(LAYOUT_PATH)
	var notice_location: Dictionary = {}
	for raw_location in layout.get("public_locations", []):
		var location := raw_location as Dictionary
		if str(location.get("id", "")) == "notice_board":
			notice_location = location
			break
	if notice_location.is_empty():
		_fail("Formal notice-board public location is missing")
		return
	if str(notice_location.get("placement", "")) != "main_hall_front_left":
		_fail("Notice board is no longer anchored beside the main-hall entrance")
		return

	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	for _frame in range(10):
		await process_frame
	await physics_frame

	var board := root.get_node_or_null(FORMAL_BOARD_PATH) as Node3D
	var hall := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/BuildingRoots/MainHall") as Node3D
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var notice_panel := root.get_node_or_null("Main/UI/NoticeBoardPanel") as Control
	var camera := root.get_node_or_null("Main/CameraRig/Camera3D") as Camera3D
	if board == null or hall == null or building_system == null or notice_panel == null or camera == null:
		_fail("Formal notice-board integration nodes are incomplete")
		return
	if not board.visible or not bool(board.get_meta("formal_public_prop", false)):
		_fail("Formal notice board is not a visible formal-layout prop")
		return
	var configured := notice_location.get("position", []) as Array
	var expected_local := Vector3(float(configured[0]), 0.08, float(configured[1]))
	if board.position.distance_to(expected_local) > 0.001:
		_fail("Formal notice board drifted from its public-location anchor")
		return
	var relative := board.global_position - hall.global_position
	if relative.x >= -2.0 or relative.z <= 8.0 or relative.z >= 12.0:
		_fail("Notice board is not beside the left side of the main-hall front door: %s" % relative)
		return
	if building_system.get_building_ids().has("notice_board"):
		_fail("Notice board must remain outside BuildingSystem")
		return
	if not board.find_children("*", "StaticBody3D", true, false).is_empty():
		_fail("Notice board introduced a physical navigation blocker")
		return
	var click_area := board.get_node_or_null("NoticeBoardClickArea") as Area3D
	if click_area == null or click_area.get_node_or_null("CollisionShape3D") == null:
		_fail("Formal notice board has no fitted click hotspot")
		return
	var art: Dictionary = board.call("get_debug_art_snapshot")
	if (
		str(art.get("art_revision", "")) != "t0132_p6"
		or str(art.get("visual_identity", "")) != "sheltered_main_hall_notice_board"
		or int(art.get("mesh_count", 0)) < 35
		or int(art.get("textured_mesh_count", 0)) < 16
		or int(art.get("paper_sheet_count", 0)) != 3
		or int(art.get("roof_panel_count", 0)) != 2
		or int(art.get("support_post_count", 0)) != 2
		or bool(art.get("has_physics_collision", true))
		or bool(art.get("building_authority", true))
	):
		_fail("Formal notice-board art contract failed: %s" % art)
		return

	var click_position := camera.unproject_position(board.global_position + Vector3(0.0, 1.65, 0.12))
	if not bool(board.call("_is_notice_board_at_screen_position", click_position)):
		_fail("Main camera ray did not resolve the formal notice-board hotspot")
		return
	board.call("debug_activate")
	await process_frame
	if not notice_panel.visible:
		_fail("Formal notice board did not open NoticeBoardPanel")
		return
	print("T0132-P6 formal notice-board verification passed: %s" % str({
		"position": board.position,
		"relative_to_main_hall": relative,
		"meshes": art.get("mesh_count"),
		"textured": art.get("textured_mesh_count"),
		"papers": art.get("paper_sheet_count")
	}))
	quit(0)


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
