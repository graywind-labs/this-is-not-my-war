extends SceneTree
const OUT := "res://artifacts/visual_qa/t0379_integration/"
const TARGET := Vector3(0,0,70)
var main: Node
var piety: Node
var clock_system: Node
var visual: Node3D
var failures: Array[String] = []
var capture_enabled := false

func _init() -> void:
	call_deferred("run")

func check(ok: bool, reason: String) -> void:
	if not ok: failures.append(reason)

func frames(count: int) -> void:
	for i in count: await process_frame

func capture(label: String) -> void:
	if not capture_enabled: return
	clock_system.set_paused(true)
	if is_instance_valid(visual): visual._process(0.0)
	await frames(4)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUT+label+".png")==OK,"Capture "+label)
	clock_system.set_paused(false)
	if is_instance_valid(visual): visual._process(0.0)

func advance(seconds: float) -> void:
	var remaining := seconds
	while remaining>0.000001:
		var dt := minf(1.0/60.0,remaining)
		piety.debug_advance_effects(dt)
		visual._process(dt)
		remaining-=dt
		if capture_enabled: await process_frame

func run() -> void:
	capture_enabled = "--capture-formal-meteor" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size = Vector2i(1280,720)
	main = load("res://scenes/main/Main.tscn").instantiate()
	main.get_node("Systems/GameStartupSystem").startup_mode = 0
	root.add_child(main)
	current_scene = main
	await frames(45)
	# Stop background simulation, retaining every real system API and signal.
	main.get_node("Systems").process_mode = Node.PROCESS_MODE_DISABLED
	piety = main.get_node("Systems/PietySystem")
	clock_system = main.get_node("Systems/TimeSystem")
	clock_system.set_current_time(1,12,0,0)
	clock_system.set_paused(false)
	var combat = main.get_node("Systems/CombatSystem")
	check(combat.debug_spawn_wave(1,true).ok,"Start real battle")
	var rig = main.get_node("CameraRig")
	rig.set_process(false)
	rig.global_position = TARGET
	var camera: Camera3D = rig.get_node("Camera3D")
	camera.position = Vector3(24,34,45)
	camera.look_at(TARGET+Vector3.UP*8)
	main.get_node("UI").hide()
	piety.debug_fill_piety()
	var ready_dialog = main.get_node("UI/MilestoneAlertPresenter/PietyReadyDialog")
	ready_dialog.hide()
	ready_dialog.confirmed.emit()
	var cast: Dictionary = piety.request_meteor_cast(TARGET)
	check(cast.get("ok",false),"Formal cast accepted")
	check(is_zero_approx(piety.get_current_piety()),"Authority consumes charge")
	visual = piety._meteor_visuals[cast.cast_id]
	visual.set_process(false)
	check(visual.get_script()==load("res://scripts/presentation/combat/FormalMeteorArt.gd"),"Formal art installed")
	check(visual._art_settings.tail_size_scale==2.0,"Approved shared effects")
	await advance(1.4)
	await capture("01_formal_descent")
	clock_system.set_paused(true)
	var position_before := visual.global_position
	visual._process(0.5)
	check(visual.global_position.is_equal_approx(position_before),"Paused fall position")
	for particle in visual._particle_emitters:
		check(is_zero_approx(particle.speed_scale),"Paused flight particle")
	clock_system.set_paused(false)
	visual._process(0.0)
	check(is_equal_approx(visual._get_effect_rate(),1.0),"Real-second fall effects")
	await advance(1.3999)
	var before_impact: Vector3 = visual._body_root.global_position
	await advance(0.001)
	check(before_impact.distance_to(visual._body_root.global_position)<0.01,"Continuous contact position")
	check(visual.has_body() and visual.has_crater(),"Body and crater on impact")
	for burn in piety._burn_visuals.values():
		check(not burn.get_node("BurningGround").visible,"Legacy red burn overlay hidden")
	await advance(0.06)
	await capture("02_formal_contact")
	await advance(0.49)
	await capture("03_formal_shockwave")
	clock_system.set_paused(true)
	var impact_age: float = visual._impact_age
	visual._process(0.5)
	check(is_equal_approx(visual._impact_age,impact_age),"Pause impact animation and cooling")
	for particle in visual._particle_emitters:
		if is_instance_valid(particle): check(is_zero_approx(particle.speed_scale),"Pause all impact particles")
	clock_system.set_paused(false)
	await advance(2.0)
	camera.position = Vector3(0,24,26)
	camera.look_at(TARGET+Vector3.UP*3)
	await capture("04_formal_rock")
	clock_system.set_current_time(1,0,0,0)
	await capture("05_formal_night")
	clock_system.set_current_time(1,12,0,0)
	await advance(9.0)
	check(visual.has_body(),"No trial eight-second removal in active battle")
	combat.clear_spawned_enemies()
	await frames(3)
	check(not visual.has_body() and visual.has_crater(),"Combat end clears body only")
	await capture("06_formal_crater")
	piety._on_logical_time_tick(43200.0,1.0)
	check(is_equal_approx(visual._crater_shader.get_shader_parameter("opacity"),0.5),"Shader follows 12-hour authority fade")
	for material in visual._crater_materials:
		check(is_equal_approx(material.albedo_color.a,0.5),"All rim fragments fade")
	await capture("07_half_day_crater")
	piety._on_logical_time_tick(43200.0,1.0)
	await frames(4)
	check(not is_instance_valid(visual),"24-hour authority frees completed visual")
	await capture("08_full_day_cleaned")
	FileAccess.open(OUT+"formal_verification.json",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"piety":piety.get_piety_snapshot()},"  "))
	main.queue_free()
	await frames(5)
	print("T0379_FORMAL_PASS" if failures.is_empty() else "T0379_FORMAL_FAIL "+JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
