extends SceneTree
const OUT := "res://artifacts/visual_qa/t0374/"
const HALL := "WorldRoot/FormalStationLayout/BuildingRoots/MainHall/MainHallArt"
var failures: Array[String] = []
var levels: Array[Dictionary] = []
func _init() -> void:
	call_deferred("run")
func frames(count: int) -> void:
	for i in count: await process_frame
func check(ok: bool, why: String) -> void:
	if not ok: failures.append(why)
func capture(label: String) -> void:
	await frames(10)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUT+label+".png")==OK, "Capture "+label)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size = Vector2i(1280,720)
	var main = load("res://scenes/main/Main.tscn").instantiate()
	main.get_node("Systems/GameStartupSystem").startup_mode = 0
	root.add_child(main)
	current_scene = main
	await frames(60)
	main.get_node("UI").hide()
	main.get_node("Systems/TimeSystem").set_current_time(1,12,0,0)
	var art: Node3D = main.get_node(HALL)
	var finish: Node3D = art.get_node("BaseVisuals/Exterior/MainHallShellFinish")
	check(finish.get_meta("window_count")==49,"49 window closures")
	var closure_meshes := 0
	for mesh in finish.find_children("*","MeshInstance3D",true,false):
		if str(mesh.name) != "PersistentShellShadowCaster": closure_meshes+=1
	check(closure_meshes==376,"Closure geometry count: %d"%closure_meshes)
	check(finish.find_children("*","CollisionObject3D",true,false).is_empty(),"No new collision")
	check(finish.find_children("*","NavigationRegion3D",true,false).is_empty(),"No new navigation")
	for node in finish.get_children():
		if node.has_node("RecessedWindow"):
			var pane: MeshInstance3D = node.get_node("RecessedWindow")
			var bounds: AABB = pane.transform*pane.get_aabb()
			check(bounds.position.x<=-0.6 and bounds.end.x>=0.6 and bounds.position.y<=1.05 and bounds.end.y>=2.31,"Window aperture coverage")
	# Compare every original mesh against the opt-out baseline, with additions excluded.
	var baseline = art.get_script().new()
	baseline.shell_finish_enabled = false
	baseline.position = Vector3(1000,0,1000)
	root.add_child(baseline)
	baseline.hide()
	var original_mesh_count := 0
	for old_mesh in baseline.find_children("*","MeshInstance3D",true,false):
		if old_mesh.get_meta("persistent_shell_shadow_proxy",false) or old_mesh.get_meta("portrait_opaque_shell_proxy",false):
			continue
		var path: NodePath = baseline.get_path_to(old_mesh)
		# Generated duplicate node names carry global instance counters; compare the
		# unchanged original hierarchy by sibling indices instead of those counters.
		var indices: Array[int] = []
		var cursor: Node = old_mesh
		while cursor != baseline:
			indices.push_front(cursor.get_index())
			cursor = cursor.get_parent()
		cursor = art
		for index in indices:
			cursor = cursor.get_child(index) if cursor != null and index < cursor.get_child_count() else null
		var mesh := cursor as MeshInstance3D
		check(mesh!=null,"Original mesh retained: "+str(path))
		if mesh != null:
			check(mesh.transform.is_equal_approx(old_mesh.transform),"Original transform changed")
			check(mesh.get_aabb().is_equal_approx(old_mesh.get_aabb()),"Original geometry changed")
		original_mesh_count+=1
	baseline.queue_free()
	var rig: Node3D = main.get_node("CameraRig")
	rig.set_process(false)
	var camera: Camera3D = rig.get_node("Camera3D")
	rig.global_position = art.global_position
	camera.fov = 46
	for entry in [["front",Vector3(0,9,32),Vector3(0,3,0)],["left",Vector3(-23,12,24),Vector3(0,3,0)],["right",Vector3(23,12,24),Vector3(0,3,0)],["rear",Vector3(-16,13,-28),Vector3(0,3,0)],["gable",Vector3(-7,9,14),Vector3(0,4.6,1)]]:
		camera.position = entry[1]
		camera.look_at(art.to_global(entry[2]))
		finish.hide()
		await capture("A_"+entry[0])
		finish.show()
		await capture("B_"+entry[0])
	for level in range(1,7):
		art.debug_force_visual_level(level)
		await frames(3)
		var gate_count := 0
		for node in finish.get_children():
			if node.get_meta("roof_section","")=="front_gatehouse" and node.is_visible_in_tree(): gate_count+=1
		check(gate_count==(2 if level<6 else 0),"Gate gables level %d"%level)
		for zoom in [18.0,42.0,70.0]:
			art.apply_roof_camera_distance(zoom,0)
			check(not art.is_interior_revealed_for_selection(),"Non-enterable hall must remain closed")
			check(is_equal_approx(art.get_art_slice_snapshot().roof_opacity,1.0),"Roof stays opaque")
		levels.append(art.get_art_slice_snapshot())
		camera.position=Vector3(-23,15,26)
		camera.look_at(art.to_global(Vector3(0,3,0)))
		await capture("level_%d_front"%level)
		camera.position=Vector3(22,15,-26)
		camera.look_at(art.to_global(Vector3(0,3,0)))
		await capture("level_%d_rear"%level)
	art.debug_force_damage_ratio(0.25)
	camera.position=Vector3(-23,15,26)
	camera.look_at(art.to_global(Vector3(0,3,0)))
	await capture("damaged")
	art._apply_destruction_state(true)
	check(not finish.is_visible_in_tree(),"Closures must disappear in ruins")
	await capture("destroyed")
	art._apply_destruction_state(false)
	check(finish.is_visible_in_tree(),"Closures return with intact building")
	FileAccess.open(OUT+"verification.json",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"levels":levels,"retained_meshes":original_mesh_count},"  "))
	main.queue_free()
	root.get_node("AudioManager").stop_music(0)
	await frames(30)
	print("T0374_GPU_PASS" if failures.is_empty() else JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
