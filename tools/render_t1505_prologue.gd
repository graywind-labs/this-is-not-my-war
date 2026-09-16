extends SceneTree
## Run with a real rendering driver; exports the four illustrations and UI proofs.
const STUDIO := preload("res://scenes/art/TutorialPrologueStudio.tscn")
const OVERLAY := preload("res://scripts/ui/TutorialOverlay.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var only_dormitory := "--dormitory-only" in OS.get_cmdline_user_args()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)
	var studio := STUDIO.instantiate()
	viewport.add_child(studio)
	for frame in range(45):
		await process_frame
	studio.freeze_actors()
	var output := ProjectSettings.globalize_path(studio.config.output_directory)
	var proofs := ProjectSettings.globalize_path("res://artifacts/visual_qa/t1505_p7")
	DirAccess.make_dir_recursive_absolute(output)
	DirAccess.make_dir_recursive_absolute(proofs)
	var pages: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/tutorial_config.json")).intro_pages
	var images: Array[Image] = []
	var overlay := OVERLAY.new()
	viewport.add_child(overlay)
	for index in range(studio.config.shots.size()):
		if (only_dormitory and index != 2) or ("--keep-dormitory" in OS.get_cmdline_user_args() and index == 2):
			images.append(Image.load_from_file(output.path_join(studio.config.shots[index].file)))
			continue
		overlay.hide()
		studio.set_shot(index)
		for frame in range(8):
			await process_frame
		await RenderingServer.frame_post_draw
		var shot_image := viewport.get_texture().get_image()
		if shot_image.is_empty():
			push_error("Empty render; use a real rendering driver")
			quit(1)
			return
		var path: String = output.path_join(studio.config.shots[index].file)
		if shot_image.save_png(path) != OK:
			quit(1)
			return
		images.append(shot_image)
		# Inject the just-rendered texture into the existing overlay, before import.
		overlay.begin()
		overlay.show_page(pages[int(studio.config.shots[index].get("page_index", index))], true)
		overlay._comic_texture.texture = ImageTexture.create_from_image(shot_image)
		overlay._comic_texture.show()
		overlay._comic_fallback.hide()
		for frame in range(3):
			await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(proofs.path_join("%02d_with_subtitles.png" % (index + 1)))
		print("PROLOGUE_RENDERED ", path)
	# Contact sheet is a UI layout of the rendered assets, not a retouched illustration.
	overlay.hide()
	var sheet := GridContainer.new()
	sheet.columns = 2
	sheet.add_theme_constant_override("h_separation", 0)
	sheet.add_theme_constant_override("v_separation", 0)
	viewport.add_child(sheet)
	for picture in images.slice(0, 4):
		var rect := TextureRect.new()
		rect.texture = ImageTexture.create_from_image(picture)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.custom_minimum_size = Vector2(960, 540)
		sheet.add_child(rect)
	for frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(proofs.path_join("contact_sheet.png"))
	sheet.hide()
	if only_dormitory:
		studio.set_shot(2)
		studio.camera.position = Vector3(104.3, 2.3, -6.4)
		studio.camera.look_at(Vector3(100, 0.65, -1.2))
		for frame in range(3):
			await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(proofs.path_join("dormitory_side_clearance.png"))
		for dimensions in [Vector2i(1600, 1200), Vector2i(2560, 1080)]:
			viewport.size = dimensions
			overlay.begin()
			overlay.show_page(pages[2], true)
			overlay._comic_texture.texture = ImageTexture.create_from_image(images[2])
			overlay._comic_texture.show()
			overlay._comic_fallback.hide()
			for frame in range(3):
				await process_frame
			await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png(proofs.path_join("03_%dx%d.png" % [dimensions.x, dimensions.y]))
		print("T1505_P7R1_RENDER_PASS beds=8 sleepers=7 empty=dormitory_bed_01")
		quit(0)
		return
	# Side view is a proof only: check the borrowed character pose and doorway clearance.
	studio.set_shot(4)
	studio.camera.position = Vector3(-0.7, 1.35, -2.0)
	studio.camera.look_at(Vector3(1.96, 1.0, -2.93))
	for frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(proofs.path_join("ada_idle_side_clearance.png"))
	for dimensions in [Vector2i(1600, 1200), Vector2i(2560, 1080)]:
		viewport.size = dimensions
		for index in [1, 3, 4]:
			overlay.begin()
			overlay.show_page(pages[int(studio.config.shots[index].get("page_index", index))], true)
			overlay._comic_texture.texture = ImageTexture.create_from_image(images[index])
			overlay._comic_texture.show()
			overlay._comic_fallback.hide()
			for frame in range(3):
				await process_frame
			await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png(proofs.path_join("%02d_%dx%d.png" % [index + 1, dimensions.x, dimensions.y]))
	print("T1505_P7_RENDER_PASS")
	quit(0)
