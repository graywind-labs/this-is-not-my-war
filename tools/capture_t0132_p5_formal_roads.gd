extends SceneTree

const OUTPUT_DIR := "res://artifacts/visual_qa"


func _init() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	var main := main_scene.instantiate()
	root.add_child(main)
	for _frame in range(18):
		await process_frame
	var ui := root.get_node_or_null("Main/UI") as CanvasLayer
	if ui != null:
		ui.visible = false
	for label in main.find_children("*", "Label3D", true, false):
		(label as Label3D).visible = false
	var rig := root.get_node("Main/CameraRig") as Node3D
	var camera := root.get_node("Main/CameraRig/Camera3D") as Camera3D
	var direction := camera.position.normalized()
	rig.global_position = Vector3(1000.0, 0.0, 8.0)
	camera.position = direction * 112.0
	camera.fov = 42.0
	for _frame in range(16):
		await process_frame
	_capture("t0132_p5_formal_roads_station_overview.png")
	rig.global_position = Vector3(1000.0, 0.0, 16.0)
	camera.position = direction * 42.0
	camera.fov = 40.0
	for _frame in range(12):
		await process_frame
	_capture("t0132_p5_formal_roads_plaza_close.png")
	print("T0132-P5 formal road captures written.")
	quit(0)


func _capture(file_name: String) -> void:
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name]))
