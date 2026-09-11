extends SceneTree

const OUTPUT := "res://artifacts/visual_qa/t0362_integration"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	main.get_node("Systems/GameStartupSystem").startup_mode = 0
	root.add_child(main)
	current_scene = main
	for frame in 18:
		await process_frame
		await physics_frame
	var formal := main.get_node("WorldRoot/FormalStationLayout") as Node3D
	var environment := formal.get_node("FormalEnvironmentArtView")
	var art := environment.get_node("ApprovedStylizedGround")
	var snapshot: Dictionary = art.get_debug_snapshot()
	assert(snapshot.tufts > 0 and snapshot.road_count == 42)
	assert(not snapshot.has_collision and not snapshot.has_navigation)
	assert(not art.has_node("ContinuousGrassAndEarth"), "Production must not instantiate the preview overlay plane")
	assert(snapshot.outer_tufts>0)
	var surface := environment.get_node("GroundSurface/StationDeepGrassVariation") as MeshInstance3D
	assert(surface.material_override is ShaderMaterial)
	assert(surface.mesh is ArrayMesh)
	assert(surface.material_override.get_shader_parameter("station_origin") == Vector2(formal.global_position.x,formal.global_position.z))
	for mesh in environment.get_node("FullMapTerrainTopology/DisconnectedPlateaus").get_children():
		assert(mesh.material_override == surface.material_override)
	assert(formal.get_node("Roads/FormalRoadNetworkArt").get_meta("surface_rendering") == "t0362_approved_ground_shader")
	var blades: MultiMesh = art.get_node("SolidLowPolyGrass").multimesh
	# Dummy headless renderer cannot read MultiMesh transforms; check actual GPU data in D3D12.
	if DisplayServer.get_name() != "headless":
		for index in blades.instance_count:
			var point := blades.get_instance_transform(index).origin
			assert(not art._in_lot(Vector2(point.x,point.z)))
			assert(art._road_distance(Vector2(point.x,point.z)) >= 0.7)
		for chunk in art.get_node("OuterGrassChunks").get_children():
			for index in chunk.multimesh.instance_count:
				var point: Vector3 = chunk.multimesh.get_instance_transform(index).origin
				assert(art._outer_point_allowed(Vector2(point.x,point.z)))
				assert(art._road_distance(Vector2(point.x,point.z))>=0.7)
	assert(main.get_node("Systems/GameStartupSystem").startup_mode == 0)
	print("T0362_INTEGRATION_PASS ",JSON.stringify(snapshot))
	if DisplayServer.get_name() != "headless":
		await _capture(main,formal)
	quit(0)

func _capture(main: Node, formal: Node3D) -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.size = Vector2i(1280,720)
	main.get_node("UI").visible = false
	for label in main.find_children("*","Label3D",true,false):
		label.visible = false
	var time_system := main.get_node("Systems/TimeSystem")
	time_system.set_paused(true)
	var rig := main.get_node("CameraRig") as Node3D
	var camera := rig.get_node("Camera3D") as Camera3D
	rig.set_process(false)
	for entry in [
		["plaza",Vector3(1,0,14),Vector3(9,16,20)],
		["station",Vector3(0,0,5),Vector3(0,105,85)],
		["blacksmith",Vector3(15,0,36),Vector3(9,16,20)],
		["outer_gate",Vector3(5,0,63),Vector3(15,29,35)],
		["outer_plain",Vector3(35,0,103),Vector3(9,16,20)],
		["full_map",Vector3(0,0,25),Vector3(0,380,310)],
	]:
		rig.global_position = formal.global_position + entry[1]
		camera.position = entry[2]
		camera.look_at(rig.global_position)
		camera.fov = 48.0
		for night in [false,true]:
			time_system.set_current_time(3,0 if night else 12,30,0)
			for frame in 12:
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("%s/%s_%s.png" % [OUTPUT,entry[0],"night" if night else "day"])
	print("T0362_INTEGRATION_CAPTURES ",OUTPUT)
	if "--measure-ground" in OS.get_cmdline_user_args():
		rig.global_position = formal.global_position + Vector3(0,0,5)
		camera.position = Vector3(0,105,85)
		camera.look_at(rig.global_position)
		time_system.set_current_time(3,12,30,0)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		for frame in 60:
			await process_frame
		var samples: Array[float] = []
		var previous := Time.get_ticks_usec()
		for frame in 120:
			await process_frame
			var now := Time.get_ticks_usec()
			samples.append(float(now-previous)/1000.0)
			previous = now
		var average := 0.0
		for sample in samples:
			average += sample / samples.size()
		samples.sort()
		var metrics := {"scenario":"static_Main_station_overview","resolution":"1280x720","samples":120,"vsync":false,"mean_frame_ms":average,"p95_frame_ms":samples[113],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
		var file := FileAccess.open(OUTPUT+"/performance.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(metrics,"  "))
		print("T0362_RENDER_METRICS ",JSON.stringify(metrics))
