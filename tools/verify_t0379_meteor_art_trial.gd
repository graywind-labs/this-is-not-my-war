extends SceneTree
## Checks real UI input, visual lifecycle and isolation; captures optional GPU views.
const OUT := "res://artifacts/visual_qa/t0379/"
var trial: Node3D
var failures: Array[String] = []
var states: Array[Dictionary] = []
var capture_enabled := false

func _init() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)

func frames(count: int) -> void:
	for i in count: await process_frame

func click(point: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion,true)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.position = point
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame

func advance(seconds: float) -> void:
	var remaining := seconds
	while remaining>0.00001:
		var delta := minf(1.0/60.0,remaining)
		trial.advance_review(delta)
		remaining -= delta
		if capture_enabled: await process_frame
	await frames(2)

func capture(label: String) -> void:
	trial._refresh_ui()
	states.append({"view":label,"state":trial.get_review_snapshot()})
	if not capture_enabled: return
	trial.set_paused(true)
	await frames(3)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUT+label+".png")==OK,"Capture "+label)
	trial.set_paused(false)

func run() -> void:
	capture_enabled = "--capture-meteor-trial" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size = Vector2i(1280,720)
	trial = load("res://scenes/art/MeteorArtTrial.tscn").instantiate()
	root.add_child(trial)
	current_scene = trial
	await frames(35)
	trial.set_process(false)
	check(root.get_node_or_null("Main")==null,"No Main")
	check(trial._ring.mesh is CylinderMesh,"Original filled targeting disk")
	check(is_equal_approx(trial._ring.mesh.top_radius,float(trial._meteor_config.radius)),"Original targeting radius")
	check(trial._ring_material.albedo_color.is_equal_approx(Color(1.0,0.42,0.12,0.25)),"Original targeting color")
	check(is_equal_approx(trial._ring_material.emission_energy_multiplier,1.35),"Original targeting glow")
	check(trial._shake_rig.get_script()==load("res://scripts/camera/CameraRig.gd"),"Uses production camera shake implementation")
	check(trial.find_children("*","PietySystem",true,false).is_empty(),"No authority")
	for candidate in [false,true]:
		trial.set_candidate(candidate)
		trial.set_view("overview")
		var tag := "B" if candidate else "A"
		await frames(3)
		check(trial._button.is_ready_to_cast(),"Starts charged "+tag)
		await click(trial._button.get_global_rect().get_center())
		check(trial._targeting,"Real button enters selection "+tag)
		trial._target = trial._center
		trial._ring.position = trial._center+Vector3.UP*0.055
		await capture(tag+"_00_target")
		await click(Vector2(900,500),MOUSE_BUTTON_RIGHT)
		check(not trial._targeting and trial._button.is_ready_to_cast(),"Cancel preserves charge "+tag)
		check(not trial.cast_at(Vector3(10000,0,10000)),"Reject off-stage target "+tag)
		await click(trial._button.get_global_rect().get_center())
		await click(trial._camera.unproject_position(trial._center))
		check(trial._stage=="falling" and not trial._button.is_ready_to_cast(),"Real ground click casts "+tag)
		check(trial._meteor.get_script()==(trial.CANDIDATE if candidate else trial.ORIGINAL),"Correct variant "+tag)
		var descent: Dictionary = trial._shake_rig.get_camera_shake_snapshot()
		check(is_equal_approx(descent.amplitude,float(trial._meteor_config.descent_camera_shake_amplitude)),"Original descent strength "+tag)
		check(is_equal_approx(descent.frequency,float(trial._meteor_config.descent_camera_shake_frequency)),"Original descent frequency "+tag)
		check(is_equal_approx(descent.duration_seconds,float(trial._meteor_config.fall_duration_seconds)),"Full descent tremor "+tag)
		await advance(1.4)
		await capture(tag+"_01_descent")
		trial.set_paused(true)
		var elapsed: float = trial._elapsed
		var camera_transform: Transform3D = trial._camera.transform
		var shake_elapsed: float = trial._shake_rig.get_camera_shake_snapshot().elapsed_seconds
		trial.set_process(true)
		await frames(10)
		trial.set_process(false)
		check(is_equal_approx(trial._elapsed,elapsed),"Pause clock "+tag)
		check(trial._camera.transform.is_equal_approx(camera_transform),"Pause camera shake "+tag)
		check(is_equal_approx(trial._shake_rig.get_camera_shake_snapshot().elapsed_seconds,shake_elapsed),"Pause shake envelope "+tag)
		for p in trial._meteor.find_children("*","GPUParticles3D",true,false):
			check(is_zero_approx(p.speed_scale),"Pause particles "+tag)
		trial.set_paused(false)
		await advance(1.4)
		check(trial._stage=="body" and trial._meteor.has_crater(),"Impact creates crater "+tag)
		check(trial._meteor.has_body(),"Landed body "+tag)
		var impact: Dictionary = trial._shake_rig.get_camera_shake_snapshot()
		check(is_equal_approx(impact.amplitude,float(trial._meteor_config.impact_camera_shake_amplitude)),"Original impact strength "+tag)
		check(is_equal_approx(impact.frequency,float(trial._meteor_config.impact_camera_shake_frequency)),"Original impact frequency "+tag)
		check(is_equal_approx(impact.duration_seconds,float(trial._meteor_config.impact_camera_shake_duration_seconds)),"Full original impact duration "+tag)
		await advance(0.08)
		await capture(tag+"_02_contact")
		await advance(0.47)
		await capture(tag+"_03_dust")
		await advance(1.45)
		trial.set_view("close")
		await capture(tag+"_04_rock")
		trial.set_view("side")
		await capture(tag+"_05_side")
		trial.set_night(true)
		await capture(tag+"_06_night")
		trial.set_night(false)
		trial.set_view("close")
		await advance(4.0)
		check(not trial._shake_rig.get_camera_shake_snapshot().active,"Shake restores camera after full duration "+tag)
		check(trial._camera.position.is_equal_approx(trial._camera_base),"Camera has no residual offset "+tag)
		await capture(tag+"_07_cooled")
		await advance(2.2)
		check(not trial._meteor.has_body() and trial._meteor.has_crater(),"Body removed before crater "+tag)
		await capture(tag+"_08_crater")
		await advance(4.8)
		var first: float = trial._meteor.get_presentation_snapshot().crater_opacity
		await capture(tag+"_09_fade_start")
		await advance(4.0)
		var second: float = trial._meteor.get_presentation_snapshot().crater_opacity
		check(second<first and second>0,"Gradual fade "+tag)
		await capture(tag+"_10_half_faded")
		await advance(5.1)
		check(trial._stage=="ready" and trial._button.is_ready_to_cast(),"Cleanup and recharge "+tag)
		check(not is_instance_valid(trial._meteor),"Released visual "+tag)
		await capture(tag+"_11_cleaned")
	# Small window controls stay accessible; phase survives view/day changes.
	root.size = Vector2i(922,518)
	trial.set_candidate(true)
	trial.replay()
	await advance(2.81)
	trial.set_paused(true)
	await frames(6)
	check(trial._panel.get_global_rect().end.x<=root.size.x,"Small-window controls fit")
	await capture("B_small_window")
	trial._panel.hide()
	await capture("B_clean_view")
	trial.reset_review()
	check(root.get_node_or_null("Main")==null,"Still isolated")
	FileAccess.open(OUT+"verification.json",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"states":states},"  "))
	trial.queue_free()
	await frames(4)
	print("T0379_PASS" if failures.is_empty() else "T0379_FAIL "+JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
