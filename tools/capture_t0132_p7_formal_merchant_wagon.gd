extends SceneTree


const OUTPUT_DIR := "res://artifacts/visual_qa"


func _init() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var world := Node3D.new()
	world.name = "MerchantWagonVisualQA"
	root.add_child(world)

	var environment := WorldEnvironment.new()
	var environment_resource := Environment.new()
	environment_resource.background_mode = Environment.BG_COLOR
	environment_resource.background_color = Color("53665d")
	environment_resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_resource.ambient_light_color = Color("d5dfd2")
	environment_resource.ambient_light_energy = 0.68
	environment.environment = environment_resource
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	world.add_child(sun)

	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(28.0, 28.0)
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("445b45")
	ground_material.roughness = 1.0
	ground_mesh.material = ground_material
	var ground := MeshInstance3D.new()
	ground.mesh = ground_mesh
	world.add_child(ground)

	var wagon := (load("res://scenes/world/MerchantWagon.tscn") as PackedScene).instantiate() as Node3D
	world.add_child(wagon)
	var camera := Camera3D.new()
	camera.current = true
	camera.fov = 35.0
	world.add_child(camera)
	for _frame in 24:
		await process_frame

	await _capture(camera, Vector3(-8.8, 6.1, -11.0), Vector3(0.0, 1.15, -1.15), "t0132_p7r_merchant_wagon_front.png")
	await _capture(camera, Vector3(9.5, 5.5, -2.0), Vector3(0.0, 1.18, -0.85), "t0132_p7r_merchant_wagon_side.png")
	await _capture(camera, Vector3(8.2, 6.0, 10.0), Vector3(0.0, 1.30, 0.10), "t0132_p7r_merchant_wagon_rear.png")
	await _capture(camera, Vector3(-4.0, 3.2, -5.7), Vector3(0.0, 1.45, -1.45), "t0132_p7r_merchant_driver_close.png")
	print("T0132-P7R covered merchant wagon captures written.")
	quit(0)


func _capture(camera: Camera3D, camera_position: Vector3, target: Vector3, file_name: String) -> void:
	camera.position = camera_position
	camera.look_at(target)
	for _frame in 10:
		await process_frame
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name]))
