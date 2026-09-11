extends SceneTree

const OUTPUT_DIR := "res://artifacts/visual_qa"


func _init() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _frame in range(12):
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
	await _set_and_capture(formal_root, rig, camera, Vector3(0.0, 0.0, 55.0), 190.0, 58.0, 0.0, 50.0, "t0135_p4_forest_station_overview.png")
	await _set_and_capture(formal_root, rig, camera, Vector3(5.0, 1.0, 245.0), 105.0, 44.0, 180.0, 48.0, "t0135_p4_front_forest_reveal.png")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	if combat_system != null and combat_system.has_method("debug_spawn_wave"):
		combat_system.call("debug_spawn_wave", 1, true)
		for _frame in range(3):
			await process_frame
	await _set_and_capture(formal_root, rig, camera, Vector3(2.0, 2.0, 315.0), 82.0, 34.0, 180.0, 47.0, "t0135_p4_enemy_spawn_screen.png")
	await _set_and_capture(formal_root, rig, camera, Vector3(-45.0, 1.0, -185.0), 112.0, 45.0, 0.0, 50.0, "t0135_p4_rear_trade_corridor.png")
	await _set_and_capture(formal_root, rig, camera, Vector3(-45.0, 1.0, -300.0), 88.0, 36.0, 0.0, 48.0, "t0135_p4_rear_edge_forest.png")
	await _set_and_capture(formal_root, rig, camera, Vector3(-165.0, 1.0, 5.0), 112.0, 52.0, -38.0, 49.0, "t0135_p4r_west_side_gradient.png")
	await _set_and_capture(formal_root, rig, camera, Vector3(190.0, 8.0, 5.0), 118.0, 47.0, 36.0, 50.0, "t0135_p4r_mountain_sparse_forest.png")
	print("T0135-P4 dense-forest captures written.")
	quit(0)


func _set_and_capture(formal_root: Node3D, rig: Node3D, camera: Camera3D, target: Vector3, distance: float, pitch: float, yaw: float, fov: float, filename: String) -> void:
	rig.global_position = formal_root.global_position + target
	var pitch_radians := deg_to_rad(pitch)
	var yaw_radians := deg_to_rad(yaw)
	var direction := Vector3(sin(yaw_radians) * cos(pitch_radians), sin(pitch_radians), cos(yaw_radians) * cos(pitch_radians)).normalized()
	camera.position = direction * distance
	camera.rotation_degrees = Vector3(-pitch, yaw, 0.0)
	camera.fov = fov
	camera.current = true
	for _frame in range(14):
		await process_frame
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, filename]))
