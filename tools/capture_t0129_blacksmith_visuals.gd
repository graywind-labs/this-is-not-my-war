extends SceneTree


const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const ART_PATH := "Main/WorldRoot/FormalStationLayout/BuildingRoots/Blacksmith/BlacksmithArt"
const OUTPUT_DIR := "res://artifacts/visual_qa"


func _init() -> void:
	var scene := load(MAIN_SCENE_PATH) as PackedScene
	if scene == null:
		push_error("Main scene unavailable")
		quit(1)
		return
	var main := scene.instantiate()
	root.add_child(main)
	for _frame in range(8):
		await process_frame
	var art := root.get_node_or_null(ART_PATH) as Node3D
	var rig := root.get_node_or_null("Main/CameraRig") as Node3D
	var camera := root.get_node_or_null("Main/CameraRig/Camera3D") as Camera3D
	var ui := root.get_node_or_null("Main/UI") as CanvasLayer
	var fade_controller := root.get_node_or_null("Main/Presentation/RoofVisibilityController") as Node
	if art == null or rig == null or camera == null:
		push_error("T0129 capture dependencies unavailable")
		quit(1)
		return
	if ui != null:
		ui.visible = false
	if fade_controller != null:
		fade_controller.process_mode = Node.PROCESS_MODE_DISABLED
	var center := art.global_position
	rig.global_position = Vector3(center.x, 0.0, center.z)
	var direction := camera.position.normalized()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for level in [1, 2, 3]:
		art.call("debug_force_visual_level", level)
		camera.position = direction * 30.0
		art.call("apply_roof_camera_distance", 70.0, 1.0)
		await _settle_and_capture("t0129_blacksmith_level%d_far.png" % level)
		camera.position = direction * 22.0
		art.call("apply_roof_camera_distance", 54.0, 0.0)
		await _settle_and_capture("t0129_blacksmith_level%d_interior.png" % level)
	await _settle_and_capture("t0129_blacksmith_interior.png")
	print("T0129 visual captures written to %s" % OUTPUT_DIR)
	quit(0)


func _settle_and_capture(file_name: String) -> void:
	for _frame in range(12):
		await process_frame
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name]))
