extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.mode = Window.MODE_FULLSCREEN
	change_scene_to_file("res://scenes/main/Main.tscn")
	await create_timer(4.0).timeout
	var scene = current_scene
	var tutorial = scene.find_child("TutorialDirector", true, false)
	if tutorial:
		tutorial.debug_skip_tutorial()
	await create_timer(25.0).timeout
	var time = scene.find_child("TimeSystem", true, false)
	time.set_paused(true)
	time.set_current_time(1, 12, 0, 0)
	var cam = scene.get_node("CameraRig")
	cam.max_zoom_distance = 160.0
	cam.set_zoom_distance(125.0)
	cam.focus_world_position_at_screen_center(Vector3.ZERO)
	scene.get_node("UI").hide()
	await create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/t1704_ppt/screenshots/01_station.png")
	cam.set_zoom_distance(55.0)
	cam.focus_world_position_at_screen_center(Vector3(0, 0, 40))
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/t1704_ppt/screenshots/02_gate.png")
	scene.get_node("UI").show()
	var panel = scene.get_node("UI/NPCPanel")
	panel.show_npc("cook_01")
	await create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/t1704_ppt/screenshots/03_npc.png")
	panel.debug_open_memory_detail("current_plan")
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/t1704_ppt/screenshots/04_plan.png")
	panel._close_memory_detail_popup()
	panel.hide()
	scene.get_node("UI/BuildingPanel").show_building("blacksmith")
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/t1704_ppt/screenshots/05_building.png")
	print("T1704_SCREENSHOTS_FULL_SCREEN ", root.size, " mode=", root.mode)
	quit()
