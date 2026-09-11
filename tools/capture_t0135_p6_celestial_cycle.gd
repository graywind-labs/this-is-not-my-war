extends SceneTree

const OUTPUT_DIR := "res://artifacts/visual_qa"


func _init() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _frame in range(16):
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
	var environment_view := formal_root.get_node("FormalEnvironmentArtView") as Node3D
	var rig := root.get_node("Main/CameraRig") as Node3D
	var camera := root.get_node("Main/CameraRig/Camera3D") as Camera3D
	_set_camera(formal_root, rig, camera)
	var captures := [
		{"time": [5, 30, 0], "name": "t0135_p6_0530_sunrise.png"},
		{"time": [6, 30, 0], "name": "t0135_p6_0630_morning.png"},
		{"time": [12, 30, 0], "name": "t0135_p6_1230_noon.png"},
		{"time": [18, 30, 0], "name": "t0135_p6_1830_evening.png"},
		{"time": [19, 30, 0], "name": "t0135_p6_1930_sunset.png"},
		{"time": [0, 30, 0], "name": "t0135_p6_0030_moon_transit.png"},
	]
	for capture in captures:
		var time_parts := capture.time as Array
		time_system.call("set_current_time", 2, int(time_parts[0]), int(time_parts[1]), int(time_parts[2]))
		for _frame in range(12):
			await process_frame
		var cycle := (environment_view.call("get_debug_snapshot") as Dictionary).get("celestial_cycle", {}) as Dictionary
		var image := root.get_texture().get_image()
		image.save_png(ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, str(capture.name)]))
		print("Captured %s: sun=%.3f moon=%.3f shadow=%s" % [
			str(capture.name),
			float((cycle.get("sun", {}) as Dictionary).get("energy", 0.0)),
			float((cycle.get("moon", {}) as Dictionary).get("energy", 0.0)),
			str(cycle.get("shadow_owner", "none")),
		])
	print("T0135-P6 celestial-cycle captures written.")
	quit(0)


func _set_camera(formal_root: Node3D, rig: Node3D, camera: Camera3D) -> void:
	rig.global_position = formal_root.global_position + Vector3(0.0, 0.0, 9.0)
	var distance := 92.0
	var pitch := 55.0
	var yaw := 0.0
	var pitch_radians := deg_to_rad(pitch)
	var yaw_radians := deg_to_rad(yaw)
	var direction := Vector3(sin(yaw_radians) * cos(pitch_radians), sin(pitch_radians), cos(yaw_radians) * cos(pitch_radians)).normalized()
	camera.position = direction * distance
	camera.rotation_degrees = Vector3(-pitch, yaw, 0.0)
	camera.fov = 48.0
	camera.current = true
