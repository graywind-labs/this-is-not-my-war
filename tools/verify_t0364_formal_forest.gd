extends SceneTree
## Real Main with simulation startup disabled: compare full original transforms and render art.
const OUTPUT := "res://artifacts/visual_qa/t0364_integration"
const ORIGINAL_FOREST := preload("res://scripts/presentation/environment/FormalForestArtView.gd")
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
	var forest := formal.get_node("FormalEnvironmentArtView/FullMapDenseForest")
	var snapshot: Dictionary = forest.get_debug_snapshot()
	assert(snapshot.approved_forest.enabled)
	assert(snapshot.total_tree_count==7393)
	assert(not snapshot.has_collision and not snapshot.has_navigation_region and not snapshot.has_interaction_area)
	var environment: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/environment_art.json"))
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/station_layout.json"))
	environment["approved_forest"] = {"enabled":false}
	var baseline := ORIGINAL_FOREST.new()
	baseline.name = "OriginalForestVerification"
	baseline.visible = false
	baseline.configure(environment,layout)
	formal.add_child(baseline)
	var original_snapshot: Dictionary = baseline.get_debug_snapshot()
	for key in ["tree_counts","station_density_counts","spawn_clear_tree_count","spawn_screen_tree_count","minimum_corridor_clearance","minimum_station_clearance","mountain_tree_count","riverbank_tree_count","bush_counts"]:
		assert(snapshot[key]==original_snapshot[key],"Original forest contract changed: "+key)
	var compared := 0
	if DisplayServer.get_name()!="headless":
		var original_transforms: Dictionary = {}
		var names := ["SlenderPine","LayeredPine","BroadFir"]
		for node in baseline.find_children("*TreePart00","MultiMeshInstance3D",true,false):
			var variant := 0
			for index in names.size():
				if str(node.name).begins_with(names[index]):
					variant = index
			var source_transform: Transform3D = baseline._conifer_variants[variant][0].transform
			for index in node.multimesh.instance_count:
				var placement: Transform3D = baseline.global_transform.affine_inverse()*node.global_transform*node.multimesh.get_instance_transform(index)*source_transform.affine_inverse()
				original_transforms[_position_key(placement.origin)] = placement
		for node in forest.find_children("*","MultiMeshInstance3D",true,false):
			if not node.has_meta("approved_tree_variant"):
				continue
			for index in node.multimesh.instance_count:
				var placement: Transform3D = forest.global_transform.affine_inverse()*node.global_transform*node.multimesh.get_instance_transform(index)
				var key := _position_key(placement.origin)
				assert(original_transforms.has(key),"A new tree position replaced an original location")
				var original: Transform3D = original_transforms[key]
				# T0365 preserves XZ and Basis; mountain trees now sit on the approved cliffs.
				var mountain := formal.get_node_or_null("FormalEnvironmentArtView/ApprovedStylizedMountain")
				if mountain != null and original.origin.x >= 120.0:
					var height: float = mountain._height_at(Vector2(original.origin.x, original.origin.z))
					if is_finite(height):
						original.origin.y = height
				assert(placement.origin.distance_to(original.origin)<0.001)
				for axis in 3:
					assert(placement.basis[axis].distance_to(original.basis[axis])<0.0001,"Original scale or rotation changed")
				compared += 1
		assert(compared==7393)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var summary := {"total_trees":snapshot.total_tree_count,"variants":snapshot.approved_forest.variant_counts,"original_transforms_compared":compared,"original_density_contracts_preserved":true,"new_collision":false,"new_navigation":false}
	var file := FileAccess.open(OUTPUT+"snapshot.json" if OUTPUT.ends_with("/") else OUTPUT+"/snapshot.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(summary,"  "))
	print("T0364_INTEGRATION_PASS ",JSON.stringify(summary))
	if DisplayServer.get_name()!="headless":
		await _capture(main,formal,forest,baseline)
	quit(0)

func _position_key(point: Vector3) -> Vector3i:
	return Vector3i(roundi(point.x*100),0,roundi(point.z*100))

func _capture(main: Node, formal: Node3D, forest: Node3D, baseline: Node3D) -> void:
	root.size = Vector2i(1280,720)
	main.get_node("UI").visible = false
	for label in main.find_children("*","Label3D",true,false):
		label.visible = false
	var time_system := main.get_node("Systems/TimeSystem")
	time_system.set_paused(true)
	var rig := main.get_node("CameraRig") as Node3D
	var camera := rig.get_node("Camera3D") as Camera3D
	rig.set_process(false)
	camera.fov = 48.0
	for entry in [
		["station",Vector3(0,0,5),Vector3(0,105,85)],
		["gate",Vector3(5,0,63),Vector3(15,29,35)],
		["front_forest",Vector3(8,1,260),Vector3(24,31,-44)],
		["rear_forest",Vector3(-40,0,-180),Vector3(24,31,44)],
		["riverbank",Vector3(-73,0,140),Vector3(18,30,35)],
		["mountain",Vector3(143,5,50),Vector3(24,40,40)],
		["full_map",Vector3(0,0,25),Vector3(0,380,310)],
	]:
		rig.global_position = formal.global_position+entry[1]
		camera.position = entry[2]
		camera.look_at(rig.global_position)
		for night in [false,true]:
			time_system.set_current_time(3,0 if night else 12,30,0)
			for frame in 12:
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("%s/%s_%s.png" % [OUTPUT,entry[0],"night" if night else "day"])
		if "--measure-forest" in OS.get_cmdline_user_args() and entry[0] in ["station","front_forest","full_map"]:
			time_system.set_current_time(3,12,30,0)
			for approved in [false,true]:
				forest.visible = approved
				baseline.visible = not approved
				await _measure(str(entry[0]),approved)
	print("T0364_INTEGRATION_CAPTURES ",OUTPUT)
	if not _metrics.is_empty():
		var file := FileAccess.open(OUTPUT+"/performance.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(_metrics,"  "))
		print("T0364_RENDER_METRICS ",JSON.stringify(_metrics))

func _measure(view: String, approved: bool) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	for frame in 45:
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
		average += sample/samples.size()
	samples.sort()
	_metrics.append({"view":view,"approved":approved,"resolution":"1280x720","samples":120,"mean_frame_ms":average,"p95_frame_ms":samples[113],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
