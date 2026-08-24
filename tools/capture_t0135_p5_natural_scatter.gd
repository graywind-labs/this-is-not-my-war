extends SceneTree

const OUTPUT_DIR := "res://artifacts/visual_qa"


func _init() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _frame in range(14):
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
	await _capture(formal_root, rig, camera, Vector3(0.0, 0.0, 9.0), 92.0, 55.0, 0.0, 48.0, "t0135_p5_station_ground_detail.png")
	await _capture(formal_root, rig, camera, Vector3(-95.0, -0.2, 25.0), 55.0, 48.0, -72.0, 48.0, "t0135_p5_riverbank_transition.png")
	await _capture(formal_root, rig, camera, Vector3(130.0, 1.0, 10.0), 70.0, 42.0, 56.0, 48.0, "t0135_p5_mountain_foot_transition.png")
	await _capture(formal_root, rig, camera, Vector3(12.0, 0.5, 104.0), 66.0, 45.0, 175.0, 46.0, "t0135_p5_enemy_road_forest_edge.png")
	await _capture(formal_root, rig, camera, Vector3(-155.0, 0.5, -5.0), 62.0, 43.0, -52.0, 47.0, "t0135_p5_forest_understory.png")
	print("T0135-P5 natural-scatter captures written.")
	quit(0)


func _capture(formal_root: Node3D, rig: Node3D, camera: Camera3D, target: Vector3, distance: float, pitch: float, yaw: float, fov: float, filename: String) -> void:
	rig.global_position = formal_root.global_position + target
	var pitch_radians := deg_to_rad(pitch)
	var yaw_radians := deg_to_rad(yaw)
	var direction := Vector3(sin(yaw_radians) * cos(pitch_radians), sin(pitch_radians), cos(yaw_radians) * cos(pitch_radians)).normalized()
	camera.position = direction * distance
	camera.rotation_degrees = Vector3(-pitch, yaw, 0.0)
	camera.fov = fov
	camera.current = true
	for _frame in range(16):
		await process_frame
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, filename]))
