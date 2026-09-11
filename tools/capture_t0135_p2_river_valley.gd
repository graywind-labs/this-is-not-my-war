extends SceneTree

const OUTPUT_DIR := "res://artifacts/visual_qa"


func _init() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _frame in range(10):
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
	await _set_and_capture(formal_root, rig, camera, Vector3(-58.0, 0.0, 28.0), 152.0, 58.0, 50.0, "t0135_p2_river_station_overview.png")
	await _set_and_capture(formal_root, rig, camera, Vector3(-97.0, 0.0, 18.0), 58.0, 52.0, 45.0, "t0135_p2_river_mid_close.png")
	await _set_and_capture(formal_root, rig, camera, Vector3(-97.0, 0.0, 18.0), 43.0, 35.0, 47.0, "t0135_p2_river_mid_low_angle.png")
	await _set_and_capture(formal_root, rig, camera, Vector3(-97.0, 0.0, 235.0), 72.0, 54.0, 47.0, "t0135_p2_river_north_reach.png")
	await _set_and_capture(formal_root, rig, camera, Vector3(-98.0, 0.0, -225.0), 72.0, 54.0, 47.0, "t0135_p2_river_south_reach.png")
	print("T0135-P2 river-valley captures written.")
	quit(0)


func _set_and_capture(formal_root: Node3D, rig: Node3D, camera: Camera3D, target: Vector3, distance: float, pitch: float, fov: float, filename: String) -> void:
	rig.global_position = formal_root.global_position + target
	var direction := Vector3(0.0, sin(deg_to_rad(pitch)), cos(deg_to_rad(pitch))).normalized()
	camera.position = direction * distance
	camera.rotation_degrees = Vector3(-pitch, 0.0, 0.0)
	camera.fov = fov
	camera.current = true
	for _frame in range(14):
		await process_frame
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, filename]))
