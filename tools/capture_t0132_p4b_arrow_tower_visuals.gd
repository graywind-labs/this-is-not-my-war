extends SceneTree

const OUTPUT_DIR := "res://artifacts/visual_qa"


func _init() -> void:
	root.size = Vector2i(960, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var stage := Node3D.new()
	stage.name = "ArrowTowerVisualQA"
	root.add_child(stage)
	_build_environment(stage)

	var platform_scene := load("res://scenes/defense_devices/FormalMainHallDefensePlatformArtView.tscn") as PackedScene
	var platform := platform_scene.instantiate() as Node3D
	stage.add_child(platform)
	var arrow_scene := load("res://scenes/defense_devices/FormalArrowTowerArtView.tscn") as PackedScene
	var arrow_tower := arrow_scene.instantiate() as Node3D
	arrow_tower.position.y = 0.88
	stage.add_child(arrow_tower)
	arrow_tower.configure_device({"effect": {"attack_interval": 1.39}, "presentation": {"projectile_speed": 64.0, "reload_fraction": 0.58}})

	var camera := Camera3D.new()
	camera.fov = 36.0
	camera.position = Vector3(5.8, 5.1, 7.2)
	camera.look_at_from_position(camera.position, Vector3(0.0, 1.55, 0.0), Vector3.UP)
	stage.add_child(camera)
	camera.current = true
	for _frame in range(18):
		await process_frame
	_capture("t0132_p4b_arrow_tower_main_hall_platform_idle.png")
	arrow_tower.debug_play_attack(Vector3(1.2, 0.0, 18.0), 1.39)
	for _frame in range(4):
		await process_frame
	_capture("t0132_p4b_arrow_tower_firing.png")
	for _frame in range(28):
		await process_frame
	_capture("t0132_p4b_arrow_tower_reloading.png")
	stage.queue_free()
	await process_frame
	await _capture_formal_main_hall_installation()
	print("T0132-P4b arrow tower visual captures written.")
	quit(0)


func _build_environment(stage: Node3D) -> void:
	var environment := WorldEnvironment.new()
	var environment_resource := Environment.new()
	environment_resource.background_mode = Environment.BG_COLOR
	environment_resource.background_color = Color(0.19, 0.25, 0.20, 1.0)
	environment_resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_resource.ambient_light_color = Color(0.72, 0.78, 0.74, 1.0)
	environment_resource.ambient_light_energy = 0.66
	environment.environment = environment_resource
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -34.0, 0.0)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	stage.add_child(sun)


func _capture(file_name: String) -> void:
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name]))


func _capture_formal_main_hall_installation() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	var main := main_scene.instantiate()
	root.add_child(main)
	for _frame in range(10):
		await process_frame
	var resource_system := root.get_node("Main/Systems/ResourceSystem")
	var device_system := root.get_node("Main/Systems/DefenseDeviceSystem")
	resource_system.add_resource("item_wall_arrow_tower", 1)
	var result: Dictionary = device_system.deploy_device("wall_arrow_tower", "main_hall_slot_03")
	if not bool(result.get("ok", false)):
		push_error("Could not deploy arrow tower on main hall: %s" % str(result))
		return
	for _frame in range(14):
		await process_frame
	var presenter := root.get_node("Main/WorldRoot/Station/DefenseDevices")
	var view := presenter.get_view_for_deployment(str(result.get("deployment_id", ""))) as Node3D
	var rig := root.get_node("Main/CameraRig") as Node3D
	var camera := root.get_node("Main/CameraRig/Camera3D") as Camera3D
	var ui := root.get_node_or_null("Main/UI") as CanvasLayer
	if ui != null:
		ui.visible = false
	for label in main.find_children("*", "Label3D", true, false):
		(label as Label3D).visible = false
	var center := view.global_position
	rig.global_position = Vector3(center.x, 0.0, center.z)
	var direction := camera.position.normalized()
	camera.position = direction * 23.0
	camera.fov = 38.0
	for _frame in range(18):
		await process_frame
	_capture("t0132_p4b_arrow_tower_main_hall_live.png")
