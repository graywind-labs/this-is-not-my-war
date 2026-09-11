extends SceneTree


const OUTPUT_DIR := "res://artifacts/visual_qa"


func _init() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	var main := main_scene.instantiate()
	root.add_child(main)
	for _frame in range(20):
		await process_frame
	var ui := root.get_node_or_null("Main/UI") as CanvasLayer
	if ui != null:
		ui.visible = false
	var board := root.get_node("Main/WorldRoot/FormalStationLayout/PublicProps/NoticeBoard") as Node3D
	for label in main.find_children("*", "Label3D", true, false):
		if not board.is_ancestor_of(label):
			(label as Label3D).visible = false
	var rig := root.get_node("Main/CameraRig") as Node3D
	var camera := root.get_node("Main/CameraRig/Camera3D") as Camera3D
	var direction := camera.position.normalized()
	rig.global_position = board.global_position + Vector3(1.6, 0.0, -1.2)
	camera.position = direction * 27.0
	camera.fov = 38.0
	for _frame in range(14):
		await process_frame
	_capture("t0132_p6_notice_board_main_hall_context.png")
	rig.global_position = board.global_position + Vector3(0.0, 0.0, -0.15)
	camera.position = direction * 13.5
	camera.fov = 34.0
	for _frame in range(12):
		await process_frame
	_capture("t0132_p6_notice_board_close.png")
	print("T0132-P6 formal notice-board captures written.")
	quit(0)


func _capture(file_name: String) -> void:
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name]))
