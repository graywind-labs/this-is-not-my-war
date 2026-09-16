extends SceneTree
const OUTPUT := "res://artifacts/visual_qa/t0371/"
var failures: Array[String] = []
func _init() -> void:
	call_deferred("run")
func frames(count: int) -> void:
	for i in count: await process_frame
func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
func capture(name: String) -> void:
	await frames(12)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUTPUT+name)==OK,"Screenshot failed "+name)
func run() -> void:
	root.size=Vector2i(1920,1080)
	var menu := load("res://scenes/frontend/MainMenu.tscn").instantiate() as Control
	root.add_child(menu)
	await frames(90)
	var cover: Node3D=menu._cover_scene
	var hall:=cover.get_node("Set/MainHallHero") as Node3D
	var finish:=hall.get_node("CoverShellFinish") as Node3D
	check(finish.get_meta("window_count")==49,"Window count")
	check(finish.find_children("*","CollisionObject3D",true,false).is_empty(),"Unexpected collisions")
	check(cover.find_children("*","NavigationRegion3D",true,false).is_empty(),"Unexpected navigation")
	var gable_count:=0
	var window_count:=0
	for node in finish.get_children():
		if node is MeshInstance3D and node.mesh is PrismMesh: gable_count+=1
		if node.has_node("RecessedWindow"):
			window_count+=1
			var pane:=node.get_node("RecessedWindow") as MeshInstance3D
			var bounds: AABB=pane.transform*pane.get_aabb()
			check(bounds.position.x<=-0.6 and bounds.end.x>=0.6 and bounds.position.y<=1.05 and bounds.end.y>=2.31,"Pane fails to cover source opening")
	check(gable_count==4 and window_count==49,"Missing shell closures")
	check(menu.find_child("ComparisonControls",true,false)==null,"Trial UI leaked")
	check(root.get_node_or_null("Main")==null,"Gameplay instantiated before Start")
	check(cover.get_preview_snapshot().formal_menu_connected,"Approved cover not connected")
	for size in [Vector2i(1920,1080),Vector2i(1600,1200),Vector2i(2560,1080)]:
		root.size=size
		await capture("menu_%dx%d.png" % [size.x,size.y])
	root.size=Vector2i(1920,1080)
	for path in ["TitleBlock","MenuPanel","VersionLabel"]: menu.get_node(path).hide()
	var camera:=cover.get_node("Camera3D") as Camera3D
	var saved_camera:=camera.transform
	var saved_fov:=camera.fov
	for entry in [
		["hall_front.png",Vector3(8.4,7.3,17),Vector3(8.4,3.0,-3.5),36.0],
		["hall_left.png",Vector3(-12,9,9),Vector3(8.4,3.2,-5),40.0],
		["hall_right.png",Vector3(29,9,8),Vector3(8.4,3.2,-5),40.0],
		["gable_close.png",Vector3(3,8,5),Vector3(8.4,4.8,-7),33.0]]:
		camera.position=entry[1]
		camera.look_at(entry[2])
		camera.fov=entry[3]
		await capture(entry[0])
	camera.transform=saved_camera
	camera.fov=saved_fov
	for path in ["TitleBlock","MenuPanel","VersionLabel"]: menu.get_node(path).show()
	menu.debug_open_settings()
	await frames(2)
	check(menu.debug_get_snapshot().settings_visible,"Settings failed")
	menu.get_node("SettingsPanel").close_panel(false)
	menu.debug_open_load_browser()
	await frames(2)
	check(menu.debug_get_snapshot().save_browser_visible,"Load browser failed")
	menu.get_node("SaveBrowserPanel").close_panel()
	menu.debug_open_exit_confirmation()
	await frames(2)
	check(menu.debug_get_snapshot().exit_confirmation_visible,"Exit dialog failed")
	menu.get_node("ExitConfirmationDialog").hide()
	var old:=load("res://scenes/art/MenuCoverPreview.tscn").instantiate() as Node3D
	root.add_child(old)
	await frames(20)
	check(not old.get_node("Set/MainHallHero").has_node("CoverShellFinish"),"Old cover mutated")
	check(is_equal_approx(old.get_node("WorldEnvironment").environment.fog_density,0.006),"Old environment mutated")
	old.queue_free()
	FileAccess.open(OUTPUT+"verification.json",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"gable_count":gable_count,"windows":window_count,"menu":menu.debug_get_snapshot(),"cover":cover.get_preview_snapshot()},"  "))
	menu.queue_free()
	root.get_node("AudioManager").stop_music(0.0)
	await frames(30)
	print("T0371_GPU_PASS" if failures.is_empty() else JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
