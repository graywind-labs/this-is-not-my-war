extends SceneTree
const OUTPUT := "res://artifacts/visual_qa/t0369/front_views"
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	main.get_node("Systems/GameStartupSystem").startup_mode = 0
	root.add_child(main)
	current_scene = main
	for i in 15:
		await process_frame
	var formal: Node3D = main.get_node("WorldRoot/FormalStationLayout")
	var art = formal.get_node("FormalEnvironmentArtView/ApprovedStylizedGround")
	var baseline = art.get_script().new()
	var config: Dictionary = art._config.duplicate(true)
	config.wildflowers.enabled = false
	config.outer_grass.enabled = false
	baseline.configure(config, art._layout, {})
	root.add_child(baseline)
	baseline.hide()
	await process_frame
	var original: MultiMesh = baseline.get_node("SolidLowPolyGrass").multimesh
	var grass: MultiMesh = art.get_node("SolidLowPolyGrass").multimesh
	assert(original.instance_count == 922 and grass.instance_count == 914)
	var placements: Array[Transform3D] = []
	for name in ["WhiteWildflowers", "YellowWildflowers"]:
		var flowers: MultiMesh = art.get_node(name).multimesh
		assert(flowers.instance_count == 4)
		assert(flowers.mesh.get_aabb().size.is_equal_approx(original.mesh.get_aabb().size))
		assert(flowers.mesh.get_aabb().position.is_equal_approx(original.mesh.get_aabb().position))
		for i in flowers.instance_count:
			var t := flowers.get_instance_transform(i)
			var p := Vector2(t.origin.x,t.origin.z)
			assert(Geometry2D.is_point_in_polygon(p,art._station_polygon))
			assert(not art._in_lot(p) and art._road_distance(p)>=1.0)
			placements.append(t)
	var retained := 0
	var replaced := 0
	for i in original.instance_count:
		var t := original.get_instance_transform(i)
		if placements.has(t):
			replaced += 1
		else:
			assert(grass.get_instance_transform(retained) == t)
			assert(grass.get_instance_color(retained) == original.get_instance_color(i))
			retained += 1
	assert(replaced == 8 and art._outer_tuft_count == 23812)
	for i in placements.size():
		for j in range(i+1, placements.size()):
			assert(placements[i].origin.distance_to(placements[j].origin)>=9.0)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var file := FileAccess.open(OUTPUT+"/snapshot.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"white":4,"yellow":4,"original_sites":922,"remaining_grass":914,"outer_grass":23812,"same_bounds":true,"all_transforms_and_grass_colors_preserved":true,"positions":placements.map(func(t): return str(t.origin))},"  "))
	main.get_node("UI").hide()
	main.get_node("Systems/TimeSystem").set_paused(true)
	for label in main.find_children("*","Label3D",true,false):
		label.hide()
	root.size = Vector2i(1280,720)
	var rig: Node3D = main.get_node("CameraRig")
	var camera: Camera3D = rig.get_node("Camera3D")
	rig.set_process(false)
	var white: Vector3 = placements[3].origin
	var yellow: Vector3 = placements[6].origin
	for entry in [["white_close",white,Vector3(0.9,1.0,1.2)],["yellow_close",yellow,Vector3(0.9,1.0,1.2)],["white_context",white,Vector3(9,13,15)],["yellow_context",yellow,Vector3(9,13,15)],["station",Vector3(0,0,5),Vector3(0,105,85)]]:
		rig.global_position = formal.global_position + entry[1]
		camera.position = entry[2]
		camera.look_at(rig.global_position)
		for night in [false,true]:
			main.get_node("Systems/TimeSystem").set_current_time(3,0 if night else 12,30,0)
			for i in 8:
				await process_frame
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png(OUTPUT+"/"+entry[0]+("_night.png" if night else "_day.png")) == OK)
	print("T0369_PASS 8 replacements; original transforms, sizes, grass colors and outside count preserved")
	quit()
