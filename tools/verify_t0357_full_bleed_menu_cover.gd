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
	for _frame in range(5):
		await process_frame
	var backdrop := menu.find_child("MenuHeroBackdrop", true, false) as Control
	if backdrop == null or not backdrop.has_method("set_cover_texture"):
		_fail("Main menu is missing the full-bleed cover controller")
		return
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.BLACK, Color.WHITE])
	var source := GradientTexture2D.new()
	source.width = 1920
	source.height = 1080
	source.gradient = gradient
	backdrop.call("set_cover_texture", source, Vector2(0.68, 0.50))

	for viewport_size in VIEWPORT_SIZES:
		root.size = viewport_size
		for _frame in range(4):
			await process_frame
		if not _validate_size(menu, backdrop, viewport_size):
			return
	backdrop.call("clear_cover_texture")
	var audio_manager := root.get_node_or_null("AudioManager")
	if audio_manager != null and audio_manager.has_method("stop_music"):
		audio_manager.call("stop_music", 0.0)
	menu.queue_free()
	source = null
	gradient = null
	for _frame in range(20):
		await process_frame
	print("T0357_FULL_BLEED_MENU_COVER_PASS sizes=%s mode=cover focus=0.68,0.50" % [VIEWPORT_SIZES])
	quit(0)


func _validate_size(menu: Control, backdrop: Control, viewport_size: Vector2i) -> bool:
	var expected := Rect2(Vector2.ZERO, Vector2(viewport_size))
	var hero_frame := menu.find_child("HeroFrame", true, false) as Control
	var title := menu.find_child("GameTitle", true, false) as Control
	var menu_panel := menu.find_child("MenuPanel", true, false) as Control
	var version := menu.find_child("VersionLabel", true, false) as Control
	if hero_frame == null or title == null or menu_panel == null or version == null:
		_fail("Full-bleed menu nodes are incomplete at %s" % viewport_size)
		return false
	if menu.find_child("LeftShade", true, false) != null or menu.find_child("TopShade", true, false) != null:
		_fail("Cover composition must not be covered by gradient shade nodes at %s" % viewport_size)
		return false
	if not hero_frame.get_global_rect().is_equal_approx(expected) or not backdrop.get_global_rect().is_equal_approx(expected):
		_fail("Hero layer does not fill %s: frame=%s backdrop=%s" % [viewport_size, hero_frame.get_global_rect(), backdrop.get_global_rect()])
		return false
	for control in [title, menu_panel, version]:
		var rect: Rect2 = (control as Control).get_global_rect()
		if rect.position.x < -0.5 or rect.position.y < -0.5 or rect.end.x > float(viewport_size.x) + 0.5 or rect.end.y > float(viewport_size.y) + 0.5:
			_fail("Overlay UI leaves viewport %s: %s=%s" % [viewport_size, control.name, rect])
			return false
	var snapshot: Dictionary = backdrop.call("debug_get_cover_snapshot")
	var source_rect: Rect2 = snapshot.get("source_rect", Rect2())
	var source_size: Vector2 = snapshot.get("source_size", Vector2.ZERO)
	if str(snapshot.get("mode", "")) != "texture_cover" or source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		_fail("Cover snapshot is invalid at %s: %s" % [viewport_size, snapshot])
		return false
	if source_rect.position.x < -0.01 or source_rect.position.y < -0.01 or source_rect.end.x > source_size.x + 0.01 or source_rect.end.y > source_size.y + 0.01:
		_fail("Cover crop leaves source bounds at %s: %s" % [viewport_size, snapshot])
		return false
	if absf(source_rect.size.x / source_rect.size.y - float(viewport_size.x) / float(viewport_size.y)) > 0.001:
		_fail("Cover crop aspect mismatch at %s: %s" % [viewport_size, snapshot])
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
