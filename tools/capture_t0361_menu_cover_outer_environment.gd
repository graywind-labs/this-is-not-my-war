extends SceneTree


const MAIN_MENU_SCENE := preload("res://scenes/frontend/MainMenu.tscn")
const OUTPUT_DIR := "res://artifacts/visual_qa"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	if not await _capture(Vector2i(1920, 1080), 0.0, "t0361_menu_cover_outer_environment_1920x1080_phase_a.png"):
		return
	if not await _capture(Vector2i(1920, 1080), 3.0, "t0361_menu_cover_outer_environment_1920x1080_phase_b.png"):
		return
	if not await _capture(Vector2i(1600, 1200), 3.0, "t0361_menu_cover_outer_environment_1600x1200.png"):
		return
	if not await _capture(Vector2i(2560, 1080), 3.0, "t0361_menu_cover_outer_environment_2560x1080.png"):
		return
	var audio_manager := root.get_node_or_null("AudioManager")
	if audio_manager != null and audio_manager.has_method("stop_music"):
		audio_manager.call("stop_music", 0.0)
	for _frame in range(20):
		await process_frame
	print("T0361_MENU_COVER_OUTER_ENVIRONMENT_CAPTURE_PASS")
	quit(0)


func _capture(viewport_size: Vector2i, motion_time: float, file_name: String) -> bool:
	root.size = viewport_size
	var menu := MAIN_MENU_SCENE.instantiate() as Control
	root.add_child(menu)
	for _frame in range(90):
		await process_frame
	var cover := menu.find_child("AnimatedMenuCover", true, false) as Node3D
	if cover == null:
		_fail("Formal menu is missing the animated cover")
		return false
	cover.set_process(false)
	cover.call("debug_set_motion_time", motion_time)
	for _frame in range(30):
		await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT_DIR + "/" + file_name))
	if error != OK:
		_fail("Failed to save %s: %s" % [file_name, error])
		return false
	menu.queue_free()
	for _frame in range(20):
		await process_frame
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
