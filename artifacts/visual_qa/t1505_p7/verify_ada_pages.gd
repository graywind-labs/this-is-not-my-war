extends SceneTree

func _init() -> void:
	call_deferred("_verify")

func _verify() -> void:
	var pages: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/tutorial_config.json")).intro_pages
	var overlay = load("res://scripts/ui/TutorialOverlay.gd").new()
	root.add_child(overlay)
	overlay.begin()
	for index in range(pages.size()):
		overlay.show_page(pages[index], true)
		assert(overlay._comic_texture.texture != null and not overlay._comic_fallback.visible)
		if index >= 3:
			assert(str(pages[index].image).ends_with("_idle.png") == (index >= 5))
	print("ADA_PAGE_TEXTURES_PASS eight imported pages; idle starts at intro_ada_answer")
	quit(0)
