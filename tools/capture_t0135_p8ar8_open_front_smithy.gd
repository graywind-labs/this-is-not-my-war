extends SceneTree


const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const ART_PATH := "Main/WorldRoot/FormalStationLayout/BuildingRoots/Blacksmith/BlacksmithArt"
const OUTPUT_PATH := "res://artifacts/visual_qa/t0135_p8ar8_blacksmith_open_front.png"


func _init() -> void:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("Main scene unavailable for P8AR8 capture")
		quit(1)
		return
	var main := packed.instantiate()
	root.add_child(main)
	for _frame in range(8):
		await process_frame
	var art := root.get_node_or_null(ART_PATH) as Node3D
	var camera := root.get_node_or_null("Main/CameraRig/Camera3D") as Camera3D
	var ui := root.get_node_or_null("Main/UI") as CanvasLayer
	var fade_controller := root.get_node_or_null("Main/Presentation/RoofVisibilityController") as Node
	if art == null or camera == null:
		push_error("P8AR8 capture dependencies unavailable")
		quit(1)
		return
	if ui != null:
		ui.visible = false
	if fade_controller != null:
		fade_controller.process_mode = Node.PROCESS_MODE_DISABLED
	art.call("debug_force_visual_level", 3)
	art.call("apply_roof_camera_distance", 70.0, 1.0)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 44.0
	camera.global_position = art.to_global(Vector3(0.0, 8.5, 22.0))
	camera.look_at(art.to_global(Vector3(0.0, 1.8, 0.0)), Vector3.UP)
	camera.make_current()
	for _frame in range(16):
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/visual_qa"))
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	print("T0135-P8AR8 open-front smithy capture written to %s" % OUTPUT_PATH)
	quit(0)
