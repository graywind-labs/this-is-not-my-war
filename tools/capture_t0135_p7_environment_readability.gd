extends SceneTree

const OUTPUT_DIR := "res://artifacts/visual_qa"


func _init() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _frame in range(18):
		await process_frame
		await physics_frame
	var time_system := root.get_node("Main/Systems/TimeSystem")
	time_system.call("set_paused", true)
	var ui := root.get_node_or_null("Main/UI") as CanvasLayer
	if ui != null:
		ui.visible = false
	for label in main.find_children("*", "Label3D", true, false):
		(label as Label3D).visible = false
	var formal_root := root.get_node("Main/WorldRoot/FormalStationLayout") as Node3D
	var rig := root.get_node("Main/CameraRig") as Node3D
	var camera := root.get_node("Main/CameraRig/Camera3D") as Camera3D

	for capture in [
		{"time": [12, 30, 0], "name": "t0135_p7_station_day.png"},
		{"time": [19, 15, 0], "name": "t0135_p7r5_station_fog_spreading.png"},
		{"time": [19, 30, 0], "name": "t0135_p7_station_sunset.png"},
		{"time": [0, 30, 0], "name": "t0135_p7_station_night.png"},
		{"time": [6, 0, 0], "name": "t0135_p7r5_station_fog_clearing.png"},
	]:
		var parts := capture.time as Array
		time_system.call("set_current_time", 3, int(parts[0]), int(parts[1]), int(parts[2]))
		await _capture(formal_root, rig, camera, Vector3(0.0, 0.0, 9.0), 92.0, 55.0, 0.0, 48.0, str(capture.name))

	for capture in [
		{"time": [12, 30, 0], "name": "t0135_p7r5_station_perimeter_day.png"},
		{"time": [0, 30, 0], "name": "t0135_p7r5_station_perimeter_night.png"},
	]:
		var parts := capture.time as Array
		time_system.call("set_current_time", 3, int(parts[0]), int(parts[1]), int(parts[2]))
		await _capture(formal_root, rig, camera, Vector3(0.0, 0.0, 9.0), 190.0, 62.0, 0.0, 55.0, str(capture.name))

	for capture in [
		{"time": [12, 30, 0], "name": "t0135_p7r5_front_forest_day.png"},
		{"time": [0, 30, 0], "name": "t0135_p7r5_front_forest_night.png"},
	]:
		var parts := capture.time as Array
		time_system.call("set_current_time", 3, int(parts[0]), int(parts[1]), int(parts[2]))
		await _capture(formal_root, rig, camera, Vector3(0.0, 0.0, 185.0), 125.0, 58.0, 0.0, 55.0, str(capture.name))

	for capture in [
		{"time": [19, 15, 0], "name": "t0135_p7r5_front_forest_edge_spreading.png"},
		{"time": [0, 30, 0], "name": "t0135_p7r5_front_forest_edge_night.png"},
		{"time": [6, 0, 0], "name": "t0135_p7r5_front_forest_edge_clearing.png"},
	]:
		var parts := capture.time as Array
		time_system.call("set_current_time", 3, int(parts[0]), int(parts[1]), int(parts[2]))
		await _capture(formal_root, rig, camera, Vector3(0.0, 0.0, 92.0), 120.0, 58.0, 0.0, 55.0, str(capture.name))

	for capture in [
		{"time": [12, 30, 0], "name": "t0135_p7_clinic_interior_day.png"},
		{"time": [0, 30, 0], "name": "t0135_p7_clinic_interior_night.png"},
	]:
		var parts := capture.time as Array
		time_system.call("set_current_time", 3, int(parts[0]), int(parts[1]), int(parts[2]))
		await _capture(formal_root, rig, camera, Vector3(12.0, 0.0, -29.5), 50.0, 58.0, 0.0, 38.0, str(capture.name))

	for capture in [
		{"time": [12, 30, 0], "name": "t0135_p7r4_blacksmith_interior_day.png"},
		{"time": [0, 30, 0], "name": "t0135_p7r4_blacksmith_interior_night.png"},
	]:
		var parts := capture.time as Array
		time_system.call("set_current_time", 3, int(parts[0]), int(parts[1]), int(parts[2]))
		await _capture(formal_root, rig, camera, Vector3(15.0, 0.0, 36.0), 50.0, 58.0, 0.0, 38.0, str(capture.name))

	for capture in [
		{"time": [12, 30, 0], "name": "t0135_p7r6_fog_boundary_overview_day.png"},
		{"time": [0, 30, 0], "name": "t0135_p7r6_fog_boundary_overview_night.png"},
	]:
		var parts := capture.time as Array
		time_system.call("set_current_time", 3, int(parts[0]), int(parts[1]), int(parts[2]))
		await _capture_orthographic(formal_root, rig, camera, Vector3.ZERO, 150.0, 78.0, 620.0, str(capture.name))

	for capture in [
		{"time": [12, 30, 0], "name": "t0135_p7r6_fog_boundary_station_day.png"},
		{"time": [0, 30, 0], "name": "t0135_p7r6_fog_boundary_station_night.png"},
	]:
		var parts := capture.time as Array
		time_system.call("set_current_time", 3, int(parts[0]), int(parts[1]), int(parts[2]))
		await _capture_orthographic(formal_root, rig, camera, Vector3.ZERO, 150.0, 78.0, 260.0, str(capture.name))
	print("T0135-P7 environment-readability captures written.")
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
	for _frame in range(18):
		await process_frame
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, filename]))


func _capture_orthographic(formal_root: Node3D, rig: Node3D, camera: Camera3D, target: Vector3, distance: float, pitch: float, orthographic_size: float, filename: String) -> void:
	rig.global_position = formal_root.global_position + target
	var pitch_radians := deg_to_rad(pitch)
	var direction := Vector3(0.0, sin(pitch_radians), cos(pitch_radians)).normalized()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = orthographic_size
	camera.position = direction * distance
	camera.rotation_degrees = Vector3(-pitch, 0.0, 0.0)
	camera.current = true
	for _frame in range(18):
		await process_frame
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, filename]))
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
