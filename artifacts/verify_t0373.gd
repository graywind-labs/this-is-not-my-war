extends SceneTree
const OUT := "res://artifacts/visual_qa/t0373/"
var failures: Array[String] = []
var views: Array[Dictionary] = []
func _init() -> void:
	call_deferred("run")
func frames(count: int) -> void:
	for i in count:
		await process_frame
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var trial = load("res://scenes/art/HUDArtTrial.tscn").instantiate()
	root.add_child(trial)
	current_scene = trial
	await frames(70)
	if not trial.ready_for_review:
		failures.append("Trial not ready")
		quit(1)
		return
	var start: Dictionary = trial.get_node("Systems/GameStartupSystem").get_startup_snapshot()
	if start.get("status") != "static_debug_ready": failures.append("Startup not static")
	var initial_camera: Transform3D = trial.get_node("CameraRig/Camera3D").global_transform
	for window_size in [Vector2i(922,518), Vector2i(1280,720), Vector2i(1600,1200), Vector2i(2560,1080)]:
		root.size = window_size
		await frames(8)
		for candidate in [false,true]:
			trial.set_variant(candidate)
			await frames(6)
			var variant := "B" if candidate else "A"
			if trial.get_node("CameraRig/Camera3D").global_transform != initial_camera: failures.append("Camera changed")
			for entry in trial.candidate._resource_values.values():
				if entry.label.text != entry.source.text: failures.append("Resource mismatch")
			if trial.candidate._wave.text != trial.original.wave_countdown_label.text: failures.append("Countdown mismatch")
			var total_area := 0.0
			for panel in trial.candidate._panels:
				var r: Rect2 = panel.get_global_rect()
				total_area += r.get_area()
				if not Rect2(Vector2.ZERO, Vector2(window_size)).encloses(r): failures.append("Panel clipped: "+str(window_size))
			for i in trial.candidate._panels.size():
				for j in range(i+1, trial.candidate._panels.size()):
					if trial.candidate._panels[i].get_global_rect().intersects(trial.candidate._panels[j].get_global_rect()): failures.append("Panels overlap")
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUT+"%s_%dx%d.png"%[variant,window_size.x,window_size.y])
			views.append({"variant":variant,"size":str(window_size),"candidate_area":total_area,"original_area":trial.original.get_node("HUDFrame").get_global_rect().get_area(),"snapshot":trial.debug_get_snapshot()})
	for window_size in [Vector2i(922,518), Vector2i(1280,720)]:
		root.size = window_size
		for mode in [1,2,3]:
			trial.set_context(mode)
			await frames(16)
			trial.toolbar.hide()
			var npc_rect: Rect2 = trial.get_node("UI/NPCPanel").get_global_rect()
			var building_rect: Rect2 = trial.get_node("UI/BuildingPanel").get_global_rect()
			for candidate in [false,true]:
				trial.set_variant(candidate)
				await frames(8)
				var rect: Rect2 = trial.candidate._panels[0].get_global_rect()
				if candidate and mode == 1 and rect.intersects(npc_rect): failures.append("HUD overlaps NPC / portrait")
				if candidate and mode == 2 and rect.intersects(building_rect): failures.append("HUD overlaps building")
				if trial.get_node("UI/NPCPanel").get_global_rect() != npc_rect: failures.append("NPC moved during A/B")
				if trial.get_node("UI/BuildingPanel").get_global_rect() != building_rect: failures.append("Building moved during A/B")
				if candidate and mode == 3:
					var dialogue: Control = trial.get_node("UI/DialogPanel")
					if not Rect2(Vector2.ZERO,Vector2(window_size)).encloses(dialogue.get_global_rect()): failures.append("Candidate dialogue clipped")
					if trial.candidate.z_index >= dialogue.z_index: failures.append("HUD above dialogue")
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(OUT+"%s_context%d_%dx%d.png"%["B" if candidate else "A",mode,window_size.x,window_size.y])
				views.append({"context":mode,"candidate":candidate,"size":str(window_size),"hud_rect":str(rect),"npc_rect":str(npc_rect),"building_rect":str(building_rect)})
	trial.set_context(0)
	root.size = Vector2i(1280,720)
	trial.set_variant(true)
	trial.toolbar.hide()
	await frames(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"B_clean.png")
	FileAccess.open(OUT+"verification.json",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"views":views},"  "))
	trial.queue_free()
	root.get_node("AudioManager").stop_music(0)
	await frames(30)
	print("T0373_GPU_PASS" if failures.is_empty() else JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
