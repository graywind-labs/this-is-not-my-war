extends SceneTree


const MAIN_MENU_SCENE := preload("res://scenes/frontend/MainMenu.tscn")
const EXPECTED_GROUND_COLOR := Color(0.12, 0.145, 0.13, 1)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var menu := MAIN_MENU_SCENE.instantiate() as Control
	root.add_child(menu)
	for _frame in range(100):
		await process_frame
	var cover := menu.find_child("AnimatedMenuCover", true, false) as Node3D
	if cover == null:
		_fail("Formal MainMenu did not instantiate the cover")
		return
	var snapshot := cover.call("get_preview_snapshot") as Dictionary
	if int(snapshot.get("outer_tree_count", 0)) != 27:
		_fail("Expected 27 exterior trees: %s" % snapshot)
		return
	if snapshot.get("outer_tree_zones", []) != ["rear", "rear_mid", "rear_far", "left", "right"]:
		_fail("Exterior tree zone contract changed")
		return
	if bool(snapshot.get("ground_candidate_textures_connected", true)):
		_fail("Rolled-back candidate ground textures were reconnected")
		return

	var trees := cover.get_node("Set/TreeSilhouettes") as Node3D
	if trees.get_child_count() != 27:
		_fail("Exterior tree instances do not match the layout")
		return
	for tree_node in trees.get_children():
		var tree := tree_node as Node3D
		if not bool(tree.get_meta("outside_station", false)):
			_fail("Tree is missing outside_station metadata: %s" % tree.name)
			return
		var p := tree.position
		if not (p.x < -13.0 or p.x > 27.0 or p.z < -20.0 or p.z > 10.0):
			_fail("Tree entered the station courtyard: %s at %s" % [tree.name, p])
			return

	var ground := cover.get_node("Ground") as MeshInstance3D
	var ground_material := ground.get_active_material(0) as StandardMaterial3D
	if ground_material == null or not ground_material.albedo_color.is_equal_approx(EXPECTED_GROUND_COLOR):
		_fail("Menu cover ground did not retain its original dark color")
		return
	if ground_material.albedo_texture != null:
		_fail("Ground unexpectedly references a texture")
		return
	if cover.has_node("StationInteriorGround"):
		_fail("Redundant interior ground overlay still exists")
		return

	cover.set_process(false)
	var sample_tree := trees.get_child(0) as Node3D
	cover.call("debug_set_motion_time", 0.0)
	var phase_a := sample_tree.transform
	cover.call("debug_set_motion_time", 3.0)
	var phase_b := sample_tree.transform
	cover.call("debug_set_motion_time", 12.0)
	var loop_end := sample_tree.transform
	if phase_a.is_equal_approx(phase_b):
		_fail("Exterior trees are not participating in the motion loop")
		return
	if not phase_a.is_equal_approx(loop_end):
		_fail("Exterior tree motion does not close at 12 seconds")
		return

	var audio_manager := root.get_node_or_null("AudioManager")
	if audio_manager != null and audio_manager.has_method("stop_music"):
		audio_manager.call("stop_music", 0.0)
	menu.queue_free()
	for _frame in range(20):
		await process_frame
	print("T0361_MENU_COVER_OUTER_ENVIRONMENT_PASS trees=27 rear_layers=3 left_density=reduced ground=original_dark loop=12s")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
