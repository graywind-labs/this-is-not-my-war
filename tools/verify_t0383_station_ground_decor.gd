extends SceneTree
const OUT := "res://artifacts/visual_qa/t0383/"
var failures: Array[String] = []
func _init() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func run() -> void:
	var main = load("res://scenes/main/Main.tscn").instantiate()
	main.get_node("Systems/GameStartupSystem").startup_mode = 0
	root.add_child(main)
	current_scene = main
	for i in 45: await process_frame
	main.get_node("Systems").process_mode = Node.PROCESS_MODE_DISABLED
	var decor = get_first_node_in_group("station_ground_decor")
	check(decor != null, "Formal decoration installed")
	if decor == null:
		quit(1)
		return
	check(decor.get_child_count() == 10, "Six torches and four stumps")
	check(decor.find_children("*", "CollisionObject3D", true, false).is_empty(), "No collision authority")
	var ground = decor.get_parent().get_node("ApprovedStylizedGround")
	var snapshot: Dictionary = ground.get_debug_snapshot()
	check(snapshot.wildflowers == 8, "Eight approved flowers preserved")
	check(snapshot.outer_tufts == 23812, "Outside grass unchanged")
	check(decor.grass_removed > 0 and decor.grass_removed < 40, "Only local grass removed")
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(decor.CONFIG_PATH))
	for prop: Node3D in decor.get_children():
		var p := Vector2(prop.position.x, prop.position.z)
		check(not ground._in_lot(p), "Outside building lots: " + str(prop.name))
		check(ground._road_distance(p) > 0.3, "Outside road edge: " + str(prop.name))
	var controller = get_first_node_in_group("building_functional_light_controller")
	var clock_system = main.get_node("Systems/TimeSystem")
	for time in [[17,59,false],[18,0,true],[23,0,true],[5,59,true],[6,0,false]]:
		clock_system.set_current_time(1,time[0],time[1],0)
		check(decor._lit == time[2] and decor._lit == controller.is_night_time(), "Gate schedule " + str(time))
	if "--capture" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute(OUT)
		root.size = Vector2i(1280,720)
		main.get_node("UI").hide()
		var rig = main.get_node("CameraRig")
		rig.set_process(false)
		var camera: Camera3D = rig.get_node("Camera3D")
		for view in [["overview",Vector3(0,0,4),Vector3(55,85,95)],["detail",Vector3(-12,0,14),Vector3(14,19,24)]]:
			rig.global_position = view[1]
			camera.position = view[2]
			camera.look_at(view[1])
			for hour in [12,21]:
				clock_system.set_current_time(1,hour,0,0)
				for i in 12: await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(OUT + view[0] + str(hour) + ".png")
	print("T0383_SNAPSHOT ", snapshot, " removed=", decor.grass_removed)
	print("T0383_PASS" if failures.is_empty() else "T0383_FAIL " + str(failures))
	main.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
