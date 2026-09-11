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
	var npc_system := root.get_node("Main/Systems/NPCSystem")
	time_system.call("set_paused", true)
	time_system.call("set_current_time", 3, 0, 30, 0)
	var assignments := {
		"veteran_deputy_01": ["dormitory", "idle"],
		"stableman_01": ["stable", "idle"],
		"cook_01": ["dining_hall", "idle"],
		"gardener_01": ["garden", "idle"],
		"blacksmith_01": ["blacksmith", "idle"],
		"engineer_01": ["workshop", "idle"],
		"priest_01": ["chapel", "idle"],
		"doctor_01": ["clinic", "idle"],
	}
	for npc_id in assignments:
		var assignment := assignments[npc_id] as Array
		npc_system.call("update_npc_state", npc_id, {
			"current_location": str(assignment[0]),
			"current_location_name": str(assignment[0]),
			"current_action": str(assignment[1]),
		})
	var ui := root.get_node_or_null("Main/UI") as CanvasLayer
	if ui != null:
		ui.visible = false
	for label in main.find_children("*", "Label3D", true, false):
		(label as Label3D).visible = false
	var formal_root := root.get_node("Main/WorldRoot/FormalStationLayout") as Node3D
	var rig := root.get_node("Main/CameraRig") as Node3D
	var camera := root.get_node("Main/CameraRig/Camera3D") as Camera3D
	await _capture(formal_root, rig, camera, Vector3(0.0, 0.0, 9.0), 92.0, 55.0, 0.0, 48.0, "t0135_p8a_station_night_lamps.png")
	await _capture(formal_root, rig, camera, Vector3(15.0, 0.0, 36.0), 46.0, 58.0, 0.0, 38.0, "t0135_p8a_blacksmith_occupied_night.png")
	await _capture(formal_root, rig, camera, Vector3(-34.0, 0.0, -9.0), 46.0, 58.0, 0.0, 38.0, "t0135_p8a_dormitory_awake_night.png")
	npc_system.call("update_npc_state", "veteran_deputy_01", {"current_action": "sleep_in_dormitory"})
	await _capture(formal_root, rig, camera, Vector3(-34.0, 0.0, -9.0), 46.0, 58.0, 0.0, 38.0, "t0135_p8a_dormitory_asleep_night.png")
	await _capture(formal_root, rig, camera, Vector3(5.0, 0.0, 51.0), 35.0, 52.0, 180.0, 42.0, "t0135_p8a_front_gate_night.png")
	await _capture(formal_root, rig, camera, Vector3(-27.0, 0.0, -42.0), 32.0, 52.0, 0.0, 42.0, "t0135_p8a_back_gate_night.png")
	await _capture(formal_root, rig, camera, Vector3(-42.0, 0.0, 10.0), 35.0, 55.0, 90.0, 40.0, "t0135_p8ar_garden_work_lights.png")
	npc_system.call("update_npc_state", "veteran_deputy_01", {"current_location": "training_ground", "current_location_name": "training_ground", "current_action": "idle"})
	await _capture(formal_root, rig, camera, Vector3(-15.0, 0.0, 36.0), 38.0, 55.0, 180.0, 40.0, "t0135_p8ar_training_work_lights.png")
	await _capture(formal_root, rig, camera, Vector3(31.0, 0.0, -23.0), 38.0, 55.0, -45.0, 40.0, "t0135_p8ar_stable_work_lights.png")
	npc_system.call("update_npc_state", "priest_01", {"current_location": "tavern", "current_location_name": "tavern", "current_action": "idle"})
	await _capture(formal_root, rig, camera, Vector3(-34.0, 0.0, 28.0), 34.0, 53.0, 45.0, 40.0, "t0135_p8ar_tavern_wall_lights.png")
	await _capture(formal_root, rig, camera, Vector3(0.0, 0.0, -1.0), 35.0, 53.0, 0.0, 40.0, "t0135_p8ar_main_hall_entry_lights.png")
	print("T0135-P8A building functional light captures written.")
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
