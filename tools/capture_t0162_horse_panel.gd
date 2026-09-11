extends SceneTree


const OUTPUT_PATH := "res://artifacts/visual_qa/t0162_horse_identity_panel.png"


func _init() -> void:
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(root.size)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/visual_qa"))
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	for _frame in range(14):
		await process_frame
		await physics_frame
	var horse_system := root.get_node_or_null("Main/Systems/HorseSystem")
	var horse_panel := root.get_node_or_null("Main/UI/HorsePanel")
	var rig := root.get_node_or_null("Main/CameraRig") as Node3D
	var camera := root.get_node_or_null("Main/CameraRig/Camera3D") as Camera3D
	if horse_system == null or horse_panel == null or rig == null or camera == null:
		push_error("T0162 capture dependencies unavailable")
		quit(1)
		return
	var chestnut: Dictionary = horse_system.get_horse_presentation_snapshot("horse_chestnut_wind")
	var gray: Dictionary = horse_system.get_horse_presentation_snapshot("horse_gray_mane")
	if chestnut.is_empty() or gray.is_empty():
		push_error("T0162 world horses unavailable for capture")
		quit(1)
		return
	var focus := (Vector3(chestnut.get("world_position", Vector3.ZERO)) + Vector3(gray.get("world_position", Vector3.ZERO))) * 0.5 + Vector3.UP * 1.0
	rig.process_mode = Node.PROCESS_MODE_DISABLED
	camera.global_position = focus + Vector3(-9.5, 8.8, 11.5)
	camera.look_at(focus, Vector3.UP)
	camera.fov = 43.0
	camera.current = true
	horse_panel.show_horse("horse_gray_mane")
	for _frame in range(28):
		await process_frame
	var snapshot: Dictionary = horse_panel.debug_get_snapshot()
	if not bool(snapshot.get("visible", false)) or str(snapshot.get("horse_id", "")) != "horse_gray_mane":
		push_error("T0162 horse panel was not ready for capture")
		quit(1)
		return
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	print("T0162 horse panel capture written")
	quit(0)
