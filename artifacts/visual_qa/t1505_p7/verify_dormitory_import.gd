extends SceneTree

func _init() -> void:
	call_deferred("_verify")

func _verify() -> void:
	var pages: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/tutorial_config.json")).intro_pages
	var overlay = load("res://scripts/ui/TutorialOverlay.gd").new()
	root.add_child(overlay)
	overlay.begin()
	overlay.show_page(pages[2], true)
	assert(overlay._comic_texture.texture != null, "Dormitory texture was not imported")
	assert(not overlay._comic_fallback.visible, "Third page used fallback")
	assert(overlay._comic_texture.texture.get_size() == Vector2(1920, 1080))
	print("DORMITORY_IMPORTED_OVERLAY_PASS 1920x1080 fallback=false")
	quit(0)
