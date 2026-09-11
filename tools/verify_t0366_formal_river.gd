extends SceneTree
## Approved river appearance in actual Main, with simulation startup disabled.
const OUTPUT := "res://artifacts/visual_qa/t0366_r1_integration"
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
	var art := formal.get_node("FormalEnvironmentArtView/ApprovedStylizedRiver")
	var snapshot: Dictionary = art.verify_geometry_contract()
	assert(snapshot.enabled and snapshot.original_water_vertices == 120)
	assert(snapshot.bank_and_rock_meshes_unchanged == 52)
	assert(snapshot.trees == 7393 and snapshot.waterline_rocks == 21 and snapshot.foam_footprints == 21)
	assert(snapshot.shoreline_rows > 1000 and is_equal_approx(float(snapshot.flow_speed), 2.8))
	var nav := formal.get_node("SpatialContract/StationNavigation") as NavigationRegion3D
	var min_navigation_x := INF
	for v in nav.navigation_mesh.get_vertices():
		min_navigation_x = minf(min_navigation_x, formal.to_local(nav.to_global(v)).x)
	var max_rock_x := -INF
	for rock: MeshInstance3D in art._shore_rocks.get_children():
		for v in rock.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			max_rock_x = maxf(max_rock_x, formal.to_local(rock.to_global(v)).x)
	assert(max_rock_x < min_navigation_x, "The shoreline decorations overlap navigable ground")
	var max_shoal_x := -INF
	for shoal: MeshInstance3D in art._shoals.get_children():
		for v in shoal.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			max_shoal_x = maxf(max_shoal_x, formal.to_local(shoal.to_global(v)).x)
	assert(max_shoal_x < min_navigation_x, "The new shallows overlap navigable ground")
	var environment: Node3D = art.get_parent()
	assert(art._water_material.get_shader_parameter("environment_origin").is_equal_approx(environment.global_position))
	assert(art._bank_material.get_shader_parameter("environment_origin").is_equal_approx(environment.global_position))
	var initial_flow: float = art._flow_time
	for frame in 5:
		await process_frame
	assert(art._flow_time > initial_flow, "Production water animation must advance")
	snapshot["min_navigation_x"] = min_navigation_x
	snapshot["max_waterline_rock_x"] = max_rock_x
	snapshot["max_shoal_x"] = max_shoal_x
	snapshot["flow_advances"] = true
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var file := FileAccess.open(OUTPUT + "/snapshot.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(snapshot, "  "))
	print("T0366_INTEGRATION_PASS ", JSON.stringify(snapshot))
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
		["west_wall", Vector3(-60, 0, 30), Vector3(28, 30, 40)],
		["river_close", Vector3(-96, -1, 93), Vector3(14, 16, 22)],
		["river_overview", Vector3(-97, -0.5, 85), Vector3(40, 64, 70)],
		["river_side", Vector3(-94, -0.6, 143), Vector3(22, 10, -29)],
		["full_map", Vector3(0, 20, 25), Vector3(0, 420, 350)],
	]:
		rig.global_position = formal.global_position + entry[1]
		camera.position = entry[2]
		camera.look_at(rig.global_position)
		for night in [false, true]:
			time_system.set_current_time(3, 0 if night else 12, 30, 0)
			for frame in 12:
				await process_frame
			await RenderingServer.frame_post_draw
			var result := root.get_texture().get_image().save_png("%s/%s_%s.png" % [OUTPUT, entry[0], "night" if night else "day"])
			assert(result == OK)
		if "--measure-river" in OS.get_cmdline_user_args() and entry[0] in ["station", "river_overview", "full_map"]:
			time_system.set_current_time(3, 12, 30, 0)
			for enabled in [false, true]:
				art.set_enabled(enabled)
				await _measure(str(entry[0]), enabled)
	print("T0366_INTEGRATION_CAPTURES ", OUTPUT)
	if not _metrics.is_empty():
		var file := FileAccess.open(OUTPUT + "/performance.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(_metrics, "  "))
		print("T0366_RENDER_METRICS ", JSON.stringify(_metrics))

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
