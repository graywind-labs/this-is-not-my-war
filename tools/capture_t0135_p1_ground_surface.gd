extends SceneTree

const OUTPUT_DIR := "res://artifacts/visual_qa"


func _init() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _frame in range(8):
		await process_frame
		await physics_frame
	var ui := root.get_node_or_null("Main/UI") as CanvasLayer
	if ui != null:
		ui.visible = false
	for label in main.find_children("*", "Label3D", true, false):
		(label as Label3D).visible = false
	var formal_root := root.get_node("Main/WorldRoot/FormalStationLayout") as Node3D
	var rig := root.get_node("Main/CameraRig") as Node3D
	var camera := root.get_node("Main/CameraRig/Camera3D") as Camera3D
	var direction := Vector3(0.0, sin(deg_to_rad(55.0)), cos(deg_to_rad(55.0))).normalized()
	rig.global_position = formal_root.global_position + Vector3(0.0, 0.0, 11.0)
	camera.position = direction * 73.0
	camera.rotation_degrees = Vector3(-55.0, 0.0, 0.0)
	camera.fov = 48.0
	await _capture(camera, "t0135_p1r2_station_density_overview.png")
	rig.global_position = formal_root.global_position + Vector3(0.0, 0.0, 10.0)
	camera.position = direction * 37.0
	camera.fov = 43.0
	await _capture(camera, "t0135_p1r2_station_density_close.png")
	rig.global_position = formal_root.global_position + Vector3(0.0, 0.0, 11.0)
	var low_direction := Vector3(0.0, sin(deg_to_rad(38.0)), cos(deg_to_rad(38.0))).normalized()
	camera.position = low_direction * 29.0
	camera.rotation_degrees = Vector3(-38.0, 0.0, 0.0)
	camera.fov = 46.0
	await _capture(camera, "t0135_p1r2_station_density_low_angle.png")
	rig.global_position = formal_root.global_position + Vector3(25.0, 0.0, 27.0)
	camera.position = direction * 31.0
	camera.rotation_degrees = Vector3(-55.0, 0.0, 0.0)
	camera.fov = 44.0
	await _capture(camera, "t0135_p1r2_east_workyard_close.png")
	rig.global_position = formal_root.global_position + Vector3(-32.0, 0.0, 14.0)
	await _capture(camera, "t0135_p1r2_west_workyard_close.png")
	rig.global_position = formal_root.global_position + Vector3(0.0, 0.0, -25.0)
	await _capture(camera, "t0135_p1r2_rear_service_close.png")
	print("T0135-P1R2 station-density captures written.")
	quit(0)


func _capture(camera: Camera3D, filename: String) -> void:
	camera.current = true
	for _frame in range(12):
		await process_frame
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, filename]))
