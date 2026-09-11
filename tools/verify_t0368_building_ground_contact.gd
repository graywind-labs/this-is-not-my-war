extends SceneTree
## Building/ground contact appearance in actual Main, with simulation startup disabled.
const OUTPUT := "res://artifacts/visual_qa/t0368/earth_revision"
var _metrics: Array = []

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
	var art := formal.get_node("FormalEnvironmentArtView/BuildingGroundContact")
	var snapshot: Dictionary = art.verify_contract()
	assert(snapshot.enabled and snapshot.new_meshes == 0)
	var ground: MeshInstance3D = formal.get_node("FormalEnvironmentArtView/GroundSurface/StationDeepGrassVariation")
	assert(ground.material_override == art._material)
	var plateau: Node = formal.get_node("FormalEnvironmentArtView/FullMapTerrainTopology/DisconnectedPlateaus")
	for mesh in plateau.get_children():
		assert(mesh.material_override == art._material, "Wall exterior and station interior must share the mask")
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var file := FileAccess.open(OUTPUT + "/snapshot.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(snapshot, "  "))
	print("T0368_INTEGRATION_PASS ", JSON.stringify(snapshot))
	if DisplayServer.get_name() != "headless":
		await _capture(main, formal, art)
	quit(0)

func _capture(main: Node, formal: Node3D, art: Node3D) -> void:
	root.size = Vector2i(1280, 720)
	main.get_node("UI").hide()
	for label in main.find_children("*", "Label3D", true, false):
		label.hide()
	var time_system := main.get_node("Systems/TimeSystem")
	time_system.set_paused(true)
	var rig := main.get_node("CameraRig") as Node3D
	var camera := rig.get_node("Camera3D") as Camera3D
	rig.set_process(false)
	camera.fov = 48.0
	camera.far = 1200.0
	for entry in [
		["station", Vector3(0, 0, 5), Vector3(0, 105, 85)],
		["main_hall", Vector3(0, 0.2, -1), Vector3(18, 21, 28)],
		["blacksmith", Vector3(15, 0.1, 36), Vector3(-18, 17, -20)],
		["wall_inside", Vector3(-55, 0, 8), Vector3(15, 10, 18)],
		["wall_outside", Vector3(-55, 0, 8), Vector3(-16, 10, 18)],
		["front_gate", Vector3(5, 0, 54), Vector3(12, 17, 23)],
		["garden", Vector3(-42, 0, 10), Vector3(18, 18, 22)],
	]:
		rig.global_position = formal.global_position + entry[1]
		camera.position = entry[2]
		camera.look_at(rig.global_position)
		for night in [false, true]:
			time_system.set_current_time(3, 0 if night else 12, 30, 0)
			for enabled in [false, true]:
				art.set_enabled(enabled)
				for frame in 8:
					await process_frame
				await RenderingServer.frame_post_draw
				var result := root.get_texture().get_image().save_png("%s/%s_%s_%s.png" % [OUTPUT, entry[0], "night" if night else "day", "B" if enabled else "A"])
				assert(result == OK)
		if "--measure-contact" in OS.get_cmdline_user_args() and entry[0] in ["station"]:
			time_system.set_current_time(3, 12, 30, 0)
			for enabled in [false, true]:
				art.set_enabled(enabled)
				await _measure(str(entry[0]), enabled)
	print("T0368_INTEGRATION_CAPTURES ", OUTPUT)
	if not _metrics.is_empty():
		var file := FileAccess.open(OUTPUT + "/performance.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(_metrics, "  "))
		print("T0368_RENDER_METRICS ", JSON.stringify(_metrics))

func _measure(view: String, enabled: bool) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	for frame in 45:
		await process_frame
	var samples: Array[float] = []
	var previous := Time.get_ticks_usec()
	for frame in 120:
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append(float(now - previous) / 1000.0)
		previous = now
	var average := 0.0
	for sample in samples:
		average += sample / samples.size()
	samples.sort()
	_metrics.append({"view": view, "approved": enabled, "samples": 120, "mean_frame_ms": average, "p95_frame_ms": samples[113], "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
