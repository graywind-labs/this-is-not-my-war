extends SceneTree


const OUTPUT := "res://artifacts/visual_qa/t0135_p8ar6_dormitory_latrine.png"
const CONTEXT_OUTPUT := "res://artifacts/visual_qa/t0135_p8ar6_dormitory_latrine_context.png"


func _init() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/visual_qa"))
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _frame in range(12):
		await process_frame
		await physics_frame
	var latrine := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/PublicProps/DormitoryLatrine") as Node3D
	var latrine_two := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/PublicProps/DormitoryLatrine02") as Node3D
	var camera := root.get_node_or_null("Main/CameraRig/Camera3D") as Camera3D
	if latrine == null or latrine_two == null or camera == null:
		push_error("P8AR6 capture dependencies unavailable")
		quit(1)
		return
	var ui := root.get_node_or_null("Main/UI") as CanvasLayer
	if ui != null:
		ui.visible = false
	for label in main.find_children("*", "Label3D", true, false):
		(label as Label3D).visible = false
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	if time_system != null and time_system.has_method("debug_set_time"):
		time_system.call("debug_set_time", 12, 0)
	camera.current = true
	camera.fov = 35.0
	camera.global_position = latrine.to_global(Vector3(8.6, 9.0, 9.5))
	camera.look_at(latrine.to_global(Vector3(1.8, 1.65, 0.0)), latrine.global_basis.y.normalized())
	for _frame in range(56):
		await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT))
	camera.fov = 43.0
	camera.global_position = latrine.to_global(Vector3(15.0, 21.0, 22.0))
	camera.look_at(latrine.to_global(Vector3(1.8, 1.0, 5.2)), latrine.global_basis.y.normalized())
	for _frame in range(36):
		await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(CONTEXT_OUTPUT))
	print("T0135-P8AR6 dormitory latrine capture written")
	quit(0)
