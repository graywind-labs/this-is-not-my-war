extends SceneTree


const PREVIEW_SCENE := preload("res://scenes/art/MenuCoverPreview.tscn")
const MAIN_MENU_SCENE := preload("res://scenes/frontend/MainMenu.tscn")
const OUTPUT_DIR := "res://artifacts/visual_qa"
const HERO_OUTPUT := OUTPUT_DIR + "/t0357_menu_cover_composition_focus_hero_v3.png"
const MENU_OUTPUT := OUTPUT_DIR + "/t0357_menu_cover_composition_focus_1920x1080_v3.png"
const FOUR_THREE_OUTPUT := OUTPUT_DIR + "/t0357_menu_cover_composition_focus_1600x1200_v3.png"
const ULTRAWIDE_OUTPUT := OUTPUT_DIR + "/t0357_menu_cover_composition_focus_2560x1080_v3.png"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var preview := PREVIEW_SCENE.instantiate()
	root.add_child(preview)
	for _frame in range(90):
		await process_frame
	var snapshot: Dictionary = preview.call("get_preview_snapshot")
	if int(snapshot.get("character_count", 0)) != 8:
		_fail("Menu cover preview does not contain all eight initial NPCs: %s" % snapshot)
		return
	var hero_image := root.get_texture().get_image()
	if hero_image.is_empty():
		_fail("Menu cover hero capture returned an empty image")
		return
	var hero_error := hero_image.save_png(ProjectSettings.globalize_path(HERO_OUTPUT))
	if hero_error != OK:
		_fail("Failed to save menu cover hero preview: %s" % hero_error)
		return
	preview.queue_free()
	await process_frame

	var menu := MAIN_MENU_SCENE.instantiate() as Control
	root.add_child(menu)
	for _frame in range(8):
		await process_frame
	var hero_backdrop := menu.find_child("MenuHeroBackdrop", true, false) as Control
	if hero_backdrop == null:
		_fail("Formal menu hero backdrop was not found")
		return
	if not hero_backdrop.has_method("set_cover_texture"):
		_fail("Formal menu hero backdrop does not expose full-bleed cover mode")
		return
	hero_backdrop.call("set_cover_texture", ImageTexture.create_from_image(hero_image), Vector2(0.68, 0.50))
	if not await _capture_menu_size(menu, Vector2i(1920, 1080), MENU_OUTPUT):
		return
	if not await _capture_menu_size(menu, Vector2i(1600, 1200), FOUR_THREE_OUTPUT):
		return
	if not await _capture_menu_size(menu, Vector2i(2560, 1080), ULTRAWIDE_OUTPUT):
		return
	print("T0357_MENU_COVER_PREVIEW_PASS %s" % snapshot)
	quit(0)


func _capture_menu_size(menu: Control, viewport_size: Vector2i, output_path: String) -> bool:
	root.size = viewport_size
	for _frame in range(8):
		await process_frame
	var hero_frame := menu.find_child("HeroFrame", true, false) as Control
	if hero_frame == null or not hero_frame.get_global_rect().is_equal_approx(Rect2(Vector2.ZERO, Vector2(viewport_size))):
		_fail("Full-bleed hero does not cover viewport %s: %s" % [viewport_size, hero_frame.get_global_rect() if hero_frame != null else Rect2()])
		return false
	var image := root.get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(output_path))
	if error != OK:
		_fail("Failed to save menu cover preview %s: %s" % [viewport_size, error])
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
