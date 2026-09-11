extends SceneTree


const VISIBLE_PATH := "res://artifacts/visual_qa/t0164_building_names_camera_moving.png"
const IDLE_PATH := "res://artifacts/visual_qa/t0164_building_names_camera_idle.png"


func _init() -> void:
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(root.size)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/visual_qa"))
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	for _index in range(18):
		await process_frame
		await physics_frame

	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	var rig := root.get_node_or_null("Main/CameraRig") as Node3D
	if controller == null or rig == null:
		push_error("T0164 capture dependencies unavailable")
		quit(1)
		return
	controller.set_process(false)
	rig.global_position.x += 0.5
	controller._process(0.01)
	for _index in range(12):
		controller._process(0.02)
		await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(VISIBLE_PATH))

	for _index in range(28):
		controller._process(0.1)
		await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(IDLE_PATH))
	print("T0164 moving/idle building-name captures written")
	quit(0)
