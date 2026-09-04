extends SceneTree


const MAIN_MENU_SCENE := preload("res://scenes/frontend/MainMenu.tscn")
const VIEWPORT_SIZES := [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(1600, 1200),
	Vector2i(1920, 1200),
	Vector2i(2560, 1080),
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = VIEWPORT_SIZES[0]
	var menu := MAIN_MENU_SCENE.instantiate() as Control
	root.add_child(menu)
	for _frame in range(80):
		await process_frame
	var hero_frame := menu.find_child("HeroFrame", true, false) as Control
	var backdrop := menu.find_child("MenuHeroBackdrop", true, false) as Control
	var cover_viewport := menu.find_child("MenuCoverViewport", true, false) as SubViewport
	var cover := menu.find_child("AnimatedMenuCover", true, false) as Node3D
	var fog := menu.find_child("MenuEdgeFog", true, false) as Control
	var title := menu.find_child("TitleBlock", true, false) as Control
	if hero_frame == null or backdrop == null or cover_viewport == null or cover == null or fog == null or title == null:
		_fail("Animated menu cover nodes are incomplete")
		return
	if cover_viewport.size != Vector2i(1920, 1080) or cover_viewport.render_target_update_mode != SubViewport.UPDATE_ALWAYS:
		_fail("Animated cover viewport contract changed: size=%s update=%s" % [cover_viewport.size, cover_viewport.render_target_update_mode])
		return
	if fog.get_index() <= hero_frame.get_index() or fog.get_index() >= title.get_index():
		_fail("Edge fog must render above the cover and below overlay UI")
		return
	var cover_snapshot: Dictionary = cover.call("get_preview_snapshot")
	if not bool(cover_snapshot.get("formal_menu_connected", false)) or not bool(cover_snapshot.get("motion_ready", false)):
		_fail("Runtime cover did not initialize: %s" % cover_snapshot)
		return
	if not bool(cover_snapshot.get("camera_static", false)) or absf(float(cover_snapshot.get("motion_loop_seconds", 0.0)) - 12.0) > 0.001:
		_fail("Cover loop or fixed camera contract changed: %s" % cover_snapshot)
		return
	var fog_snapshot: Dictionary = fog.call("debug_get_snapshot")
	var weights := fog_snapshot.get("edge_weights", {}) as Dictionary
	var center := float(weights.get("center", 1.0))
	for region in ["left_lower", "bottom_center", "right_middle", "top_right"]:
		if float(weights.get(region, 0.0)) <= center + 0.35:
			_fail("Fog edge is not stronger than center: %s" % fog_snapshot)
			return
	if float(weights.get("left_ui_right", 0.0)) < 0.45:
		_fail("Left fog no longer reaches the menu panel right edge: %s" % fog_snapshot)
		return
	if float(weights.get("left_wall_end", 0.0)) < 0.90:
		_fail("Left wall end is not dense enough to fade in and out: %s" % fog_snapshot)
		return
	if float(weights.get("left_inner_limit", 1.0)) > 0.08:
		_fail("Left fog expanded toward the composition center: %s" % fog_snapshot)
		return
	if float(weights.get("title_zone", 1.0)) > 0.05 or bool(fog_snapshot.get("uses_global_darkening", true)):
		_fail("Fog intrudes into title zone or restores global darkening: %s" % fog_snapshot)
		return

	var camera := cover.find_child("Camera3D", true, false) as Camera3D
	var horse := cover.find_child("StableHorse", true, false) as Node3D
	cover.call("debug_set_motion_time", 0.0)
	var camera_at_zero := camera.transform
	var horse_at_zero := horse.transform
	cover.call("debug_set_motion_time", 3.0)
	var horse_at_quarter := horse.transform
	cover.call("debug_set_motion_time", 12.0)
	if camera.transform != camera_at_zero:
		_fail("Menu cover camera moved during the loop")
		return
	if horse_at_quarter.is_equal_approx(horse_at_zero):
		_fail("Horse micro motion did not change across the loop")
		return
	if not horse.transform.is_equal_approx(horse_at_zero):
		_fail("Horse micro motion does not close at 12 seconds")
		return

	for viewport_size in VIEWPORT_SIZES:
		root.size = viewport_size
		for _frame in range(4):
			await process_frame
		var expected := Rect2(Vector2.ZERO, Vector2(viewport_size))
		if not hero_frame.get_global_rect().is_equal_approx(expected) or not backdrop.get_global_rect().is_equal_approx(expected) or not fog.get_global_rect().is_equal_approx(expected):
			_fail("Animated cover or fog does not fill viewport %s" % viewport_size)
			return

	var audio_manager := root.get_node_or_null("AudioManager")
	if audio_manager != null and audio_manager.has_method("stop_music"):
		audio_manager.call("stop_music", 0.0)
	menu.queue_free()
	for _frame in range(20):
		await process_frame
	print("T0358_ANIMATED_MENU_COVER_PASS sizes=%s loop=12s fog=edge_weighted camera=fixed" % [VIEWPORT_SIZES])
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
