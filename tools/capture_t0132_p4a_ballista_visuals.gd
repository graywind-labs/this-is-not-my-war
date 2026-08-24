extends SceneTree

const OUTPUT_DIR := "res://artifacts/visual_qa"


func _init() -> void:
	root.size = Vector2i(960, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var stage := Node3D.new()
	stage.name = "BallistaVisualQA"
	root.add_child(stage)

	var environment := WorldEnvironment.new()
	var environment_resource := Environment.new()
	environment_resource.background_mode = Environment.BG_COLOR
	environment_resource.background_color = Color(0.19, 0.25, 0.20, 1.0)
	environment_resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_resource.ambient_light_color = Color(0.72, 0.78, 0.74, 1.0)
	environment_resource.ambient_light_energy = 0.62
	environment.environment = environment_resource
	stage.add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -34.0, 0.0)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	stage.add_child(sun)

	var platform := MeshInstance3D.new()
	platform.name = "FormalPlatformEnvelope"
	var platform_mesh := BoxMesh.new()
	platform_mesh.size = Vector3(3.6, 0.28, 3.4)
	platform.mesh = platform_mesh
	platform.position.y = -0.16
	var platform_material := StandardMaterial3D.new()
	platform_material.albedo_color = Color(0.27, 0.20, 0.15, 1.0)
	platform_material.roughness = 0.92
	platform.set_surface_override_material(0, platform_material)
	stage.add_child(platform)

	var ballista_scene := load("res://scenes/defense_devices/FormalBallistaArtView.tscn") as PackedScene
	var ballista := ballista_scene.instantiate() as Node3D
	stage.add_child(ballista)
	ballista.configure_device({"effect": {"attack_interval": 4.25}, "presentation": {"projectile_speed": 52.0, "reload_fraction": 0.62}})

	var camera := Camera3D.new()
	camera.name = "PreviewCamera"
	camera.fov = 34.0
	camera.position = Vector3(4.8, 4.0, 6.2)
	camera.look_at_from_position(camera.position, Vector3(0.0, 0.65, 0.05), Vector3.UP)
	stage.add_child(camera)
	camera.current = true

	for _frame in range(18):
		await process_frame
	_capture("t0132_p4a_ballista_idle.png")
	ballista.debug_play_attack(Vector3(0.8, 0.0, 17.0), 4.25)
	for _frame in range(5):
		await process_frame
	_capture("t0132_p4a_ballista_firing.png")
	for _frame in range(28):
		await process_frame
	_capture("t0132_p4a_ballista_reloading.png")
	stage.queue_free()
	await process_frame
	await _capture_formal_platform_installation()
	print("T0132-P4a ballista visual captures written.")
	quit(0)


func _capture(file_name: String) -> void:
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name]))


func _capture_formal_platform_installation() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	var main := main_scene.instantiate()
	root.add_child(main)
	for _frame in range(10):
		await process_frame
	var resource_system := root.get_node("Main/Systems/ResourceSystem")
	var device_system := root.get_node("Main/Systems/DefenseDeviceSystem")
	resource_system.add_resource("item_wall_ballista", 1)
	var result: Dictionary = device_system.deploy_device("wall_ballista", "wall_slot_01")
	if not bool(result.get("ok", false)):
		push_error("Could not deploy wall ballista for visual capture: %s" % str(result))
		return
	for _frame in range(12):
		await process_frame
	var presenter := root.get_node("Main/WorldRoot/Station/DefenseDevices")
	var view := presenter.get_view_for_deployment(str(result.get("deployment_id", ""))) as Node3D
	var rig := root.get_node("Main/CameraRig") as Node3D
	var camera := root.get_node("Main/CameraRig/Camera3D") as Camera3D
	var ui := root.get_node_or_null("Main/UI") as CanvasLayer
	if ui != null:
		ui.visible = false
	var center := view.global_position
	rig.global_position = Vector3(center.x, 0.0, center.z)
	var direction := camera.position.normalized()
	camera.position = direction * 13.5
	camera.fov = 40.0
	for _frame in range(18):
		await process_frame
	_capture("t0132_p4a_ballista_wall_platform.png")
