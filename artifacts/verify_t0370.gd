extends SceneTree

const OUTPUT := "res://artifacts/visual_qa/t0370/"
var failures: Array[String] = []
var baseline: Dictionary = {}

func _init() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1920,1080)
	var menu := load("res://scenes/art/MenuCoverArtTrial.tscn").instantiate() as Control
	root.add_child(menu)
	await frames(90)
	for size in [Vector2i(1920,1080), Vector2i(1600,1200), Vector2i(2560,1080)]:
		root.size = size
		for candidate in [false,true]:
			menu.set_candidate(candidate)
			await frames(80)
			var cover: Node3D = menu._cover_scene
			cover.set_process(false)
			cover.debug_set_motion_time(0.0)
			await frames(6)
			var contract := get_contract(cover)
			if baseline.is_empty(): baseline = contract
			if contract != baseline:
				for key in contract:
					if contract[key] != baseline.get(key): failures.append("Staging changed %s %s: %s | %s != %s" % [size,candidate,key,contract[key],baseline.get(key)])
			if root.get_node_or_null("Main") != null: failures.append("Main instantiated")
			if cover.get_node("Set/TreeSilhouettes").get_child_count() != 27: failures.append("Tree count")
			var environment: Environment = cover.get_node("WorldEnvironment").environment
			if not candidate and not is_equal_approx(environment.fog_density,0.006): failures.append("Original environment mutated")
			var side := "B" if candidate else "A"
			await capture("%s_%sx%s.png" % [side,size.x,size.y])
			if size == Vector2i(1920,1080):
				for path in ["TitleBlock","MenuPanel","VersionLabel","ComparisonControls"]: menu.get_node(path).hide()
				await capture("%s_scene.png" % side)
				cover.debug_set_motion_time(3.0)
				await frames(30)
				await capture("%s_phase3.png" % side)
				for path in ["TitleBlock","MenuPanel","VersionLabel","ComparisonControls"]: menu.get_node(path).show()
				cover.debug_set_motion_time(12.0)
				if get_contract(cover) != baseline: failures.append("Loop transform changed")
	var report := {"failures":failures,"staging":baseline,"capture_count":10,"main_scene":ProjectSettings.get_setting("application/run/main_scene")}
	FileAccess.open(OUTPUT+"verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	menu.queue_free()
	root.get_node("AudioManager").stop_music(0.0)
	await frames(30)
	print("T0370_GPU_REVIEW_PASS" if failures.is_empty() else JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)

func get_contract(cover: Node3D) -> Dictionary:
	var result := {"camera":str(cover.get_node("Camera3D").transform),"fov":cover.get_node("Camera3D").fov,
		"collision_count":cover.find_children("*","CollisionObject3D",true,false).size(),
		"navigation_count":cover.find_children("*","NavigationRegion3D",true,false).size()}
	for path in ["Set/Characters","Set/ProfessionWorkstations","Set/StoryProps"]:
		for node in cover.get_node(path).get_children():
			if node is Node3D: result[path+"/"+str(node.get_index())] = str(node.transform)
	for path in ["Set/MainHallHero","Set/FortificationFrame","Set/StableHorse"]: result[path] = str(cover.get_node(path).transform)
	for node in cover.get_node("Set/TreeSilhouettes").get_children(): result["tree_"+str(node.name)] = str(node.position)
	return result

func capture(name: String) -> void:
	await frames(8)
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(OUTPUT+name)
	if error != OK: failures.append("Capture failed: "+name)

func frames(count: int) -> void:
	for frame in count: await process_frame
